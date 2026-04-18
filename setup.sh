#!/bin/bash
# setup.sh — Create stub .app bundles and lock them down
# Requires: sudo (for chflags and ACLs)
set -euo pipefail

# ─── Apps to block ───────────────────────────────────────────────────────────
# Key: app name (matches /Applications/<name>.app)
# Value: bundle identifier (must match the real app's CFBundleIdentifier)
declare -A APPS=(
  # Microsoft
  ["Microsoft Outlook"]="com.microsoft.Outlook"
  ["Microsoft Excel"]="com.microsoft.Excel"
  ["Microsoft Word"]="com.microsoft.Word"
  ["Microsoft OneNote"]="com.microsoft.onenote.mac"
  ["Microsoft OneDrive"]="com.microsoft.OneDrive"
  ["Microsoft 365 Copilot"]="com.microsoft.m365copilot"
  ["OneDrive"]="com.microsoft.OneDrive-mac"
  # ["Microsoft PowerPoint"]="com.microsoft.Powerpoint"

  # Apple iWork
  ["Keynote"]="com.apple.iWork.Keynote"
  ["Pages"]="com.apple.iWork.Pages"
  ["Numbers"]="com.apple.iWork.Numbers"

  # Other
  ["zoom.us"]="us.zoom.xos"
  ["Firefox"]="org.mozilla.firefox"
  ["VLC"]="org.videolan.vlc"
)

# Apps that install as /Applications/<name>.localized/<name>.app
# (Microsoft OneDrive's installer uses this layout.)
declare -A LOCALIZED_APPS=(
  ["OneDrive"]="com.microsoft.OneDrive"
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
for app_name in "${!APPS[@]}"; do
  bundle_id="${APPS[$app_name]}"
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
for folder_name in "${!LOCALIZED_APPS[@]}"; do
  bundle_id="${LOCALIZED_APPS[$folder_name]}"
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

echo "All stubs created and locked."
echo ""
echo "To verify:  ls -laeO /Applications/<AppName>.app"
echo "To undo:    sudo bash uninstall.sh"
