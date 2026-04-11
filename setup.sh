#!/bin/bash
# setup.sh — Create stub .app bundles and lock them down
# Requires: sudo (for chflags and ACLs)
set -euo pipefail

# ─── Apps to block ───────────────────────────────────────────────────────────
# Key: app name (matches /Applications/<name>.app)
# Value: bundle identifier (must match the real app's CFBundleIdentifier)
declare -A APPS=(
  ["Microsoft Outlook"]="com.microsoft.Outlook"
  ["Microsoft Excel"]="com.microsoft.Excel"
  ["Microsoft OneNote"]="com.microsoft.onenote.mac"
  ["Microsoft OneDrive"]="com.microsoft.OneDrive"
  # Uncomment to block additional apps:
  # ["Microsoft Word"]="com.microsoft.Word"
  # ["Microsoft PowerPoint"]="com.microsoft.Powerpoint"
)

STUB_VERSION="99.0.0"

# ─── Main ────────────────────────────────────────────────────────────────────

for app_name in "${!APPS[@]}"; do
  bundle_id="${APPS[$app_name]}"
  app_path="/Applications/${app_name}.app"
  contents_path="${app_path}/Contents"
  plist_path="${contents_path}/Info.plist"

  echo "==> ${app_name}"

  # If a real (non-stub) app exists, remove it first
  if [ -d "$app_path" ]; then
    echo "    Removing existing app..."
    # Strip any existing protections so we can replace it
    chflags -R noschg "$app_path" 2>/dev/null || true
    chmod -RN "$app_path" 2>/dev/null || true
    rm -rf "$app_path"
  fi

  # Create stub .app bundle
  mkdir -p "$contents_path"
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
  echo "    Stub created (${bundle_id} v${STUB_VERSION})"

  # Lock with system immutable flag (survives root writes by default)
  chflags -R schg "$app_path"
  echo "    Immutable flag set (chflags schg)"

  # Add ACL deny rules
  chmod +a "everyone deny delete,write,writeattr,writeextattr,chown" "$app_path"
  chmod +a "everyone deny delete,write,writeattr,writeextattr,chown" "$contents_path"
  chmod +a "everyone deny delete,write,writeattr,writeextattr,chown" "$plist_path"
  echo "    ACL deny rules applied"

  echo "    Done"
  echo ""
done

echo "All stubs created and locked."
echo ""
echo "To verify:  ls -laeO /Applications/<AppName>.app"
echo "To undo:    sudo bash uninstall.sh"
