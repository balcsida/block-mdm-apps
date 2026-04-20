#!/bin/bash
# setup.sh — Create stub .app bundles and lock them down
# Requires: sudo (for chflags and ACLs)
# Compatible with bash 3.2 (macOS default /bin/bash).
set -euo pipefail

# ─── Apps to block ───────────────────────────────────────────────────────────
# Format: "<app name>|<bundle identifier>"
#   <app name> matches /Applications/<name>.app
#   <bundle id> must match the real app's CFBundleIdentifier
APPS=(
  # Microsoft
  "Microsoft Outlook|com.microsoft.Outlook"
  "Microsoft Excel|com.microsoft.Excel"
  "Microsoft Word|com.microsoft.Word"
  "Microsoft OneNote|com.microsoft.onenote.mac"
  "Microsoft OneDrive|com.microsoft.OneDrive"
  "Microsoft 365 Copilot|com.microsoft.m365copilot"
  "OneDrive|com.microsoft.OneDrive-mac"
  # "Microsoft PowerPoint|com.microsoft.Powerpoint"

  # Apple iWork
  "Keynote|com.apple.iWork.Keynote"
  "Pages|com.apple.iWork.Pages"
  "Numbers|com.apple.iWork.Numbers"

  # Other
  "zoom.us|us.zoom.xos"
  "Firefox|org.mozilla.firefox"
  "VLC|org.videolan.vlc"
)

# Apps that install as /Applications/<name>.localized/<name>.app
# (Microsoft OneDrive's installer uses this layout.)
LOCALIZED_APPS=(
  "OneDrive|com.microsoft.OneDrive"
)

# Launch plists / helper binaries that MDM keeps re-dropping even after the
# parent app is stubbed. Each path is replaced with an empty file and locked,
# so the installer can neither write the real plist nor register the helper.
# Use `daemon` for LaunchDaemons + /Library/PrivilegedHelperTools binaries
# (system domain), `agent` for LaunchAgents (gui/<uid> domain).
# Format: "<kind>|<absolute path>"
PROTECTED_PATHS=(
  # OneDrive — updater/sync agents and daemons (stubs in /Applications/OneDrive.app)
  "agent|/Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist"
  "agent|/Library/LaunchAgents/com.microsoft.SyncReporter.plist"
  "daemon|/Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist"
  "daemon|/Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist"

  # Zoom — privileged helper daemon
  "daemon|/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
  "daemon|/Library/PrivilegedHelperTools/us.zoom.ZoomDaemon"
)

STUB_VERSION="99.0.0"

# ─── Helpers ─────────────────────────────────────────────────────────────────

strip_protections() {
  local p="$1"
  chflags -R noschg "$p" 2>/dev/null || true
  chmod -RN "$p" 2>/dev/null || true
}

write_stub_plist() {
  local plist_path="$1" bundle_id="$2" app_name="$3"
  cat > "$plist_path" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleName</key>
  <string>${app_name}</string>
  <key>CFBundleShortVersionString</key>
  <string>${STUB_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${STUB_VERSION}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
PLIST
}

deny_acl() {
  chmod +a "everyone deny delete,write,writeattr,writeextattr,chown" "$1"
}

# ─── Main ────────────────────────────────────────────────────────────────────

shopt -s nullglob

# Standard .app stubs
for entry in "${APPS[@]}"; do
  app_name="${entry%%|*}"
  bundle_id="${entry#*|}"
  app_path="/Applications/${app_name}.app"
  contents_path="${app_path}/Contents"
  plist_path="${contents_path}/Info.plist"

  echo "==> ${app_name}"

  # Remove installer-numbered copies (e.g. "zoom.us 1.app", "zoom.us 2.app")
  for leftover in /Applications/"${app_name}"\ [0-9]*.app; do
    echo "    Removing leftover: $(basename "$leftover")"
    strip_protections "$leftover"
    rm -rf "$leftover"
  done

  if [ -d "$app_path" ]; then
    echo "    Removing existing app..."
    strip_protections "$app_path"
    rm -rf "$app_path"
  fi

  mkdir -p "$contents_path"
  write_stub_plist "$plist_path" "$bundle_id" "$app_name"
  echo "    Stub created (${bundle_id} v${STUB_VERSION})"

  deny_acl "$app_path"
  deny_acl "$contents_path"
  deny_acl "$plist_path"
  echo "    ACL deny rules applied"

  chflags -R schg "$app_path"
  echo "    Immutable flag set (chflags schg)"

  echo "    Done"
  echo ""
done

# `.localized` folder stubs (e.g. /Applications/OneDrive.localized/OneDrive.app)
for entry in "${LOCALIZED_APPS[@]}"; do
  folder_name="${entry%%|*}"
  bundle_id="${entry#*|}"
  folder_path="/Applications/${folder_name}.localized"
  app_path="${folder_path}/${folder_name}.app"
  contents_path="${app_path}/Contents"
  plist_path="${contents_path}/Info.plist"

  echo "==> ${folder_name}.localized"

  # Remove installer-numbered copies (OneDrive-1.localized, OneDrive-2.localized, ...)
  for leftover in /Applications/"${folder_name}"-[0-9]*.localized; do
    echo "    Removing leftover: $(basename "$leftover")"
    strip_protections "$leftover"
    rm -rf "$leftover"
  done

  if [ -d "$folder_path" ]; then
    echo "    Removing existing folder..."
    strip_protections "$folder_path"
    rm -rf "$folder_path"
  fi

  mkdir -p "$contents_path"
  write_stub_plist "$plist_path" "$bundle_id" "$folder_name"
  echo "    Stub created (${bundle_id} v${STUB_VERSION})"

  deny_acl "$folder_path"
  deny_acl "$app_path"
  deny_acl "$contents_path"
  deny_acl "$plist_path"
  echo "    ACL deny rules applied"

  chflags -R schg "$folder_path"
  echo "    Immutable flag set (chflags schg)"

  echo "    Done"
  echo ""
done

shopt -u nullglob

# Protected plists and privileged-helper binaries
for entry in "${PROTECTED_PATHS[@]}"; do
  kind="${entry%%|*}"
  path="${entry#*|}"
  name="$(basename "$path")"

  echo "==> ${name}"

  if [ "$kind" = "agent" ]; then
    launchctl bootout "gui/${SUDO_UID:-$(id -u)}" "$path" 2>/dev/null || true
  else
    launchctl bootout system "$path" 2>/dev/null || true
  fi

  if [ -e "$path" ]; then
    strip_protections "$path"
    rm -f "$path"
  fi

  : > "$path"
  deny_acl "$path"
  chflags schg "$path"
  echo "    Blocked (empty stub, schg + ACL)"
  echo ""
done

echo "All stubs created and locked."
echo ""
echo "To verify:  ls -laeO /Applications/<AppName>.app"
echo "To undo:    sudo bash uninstall.sh"
