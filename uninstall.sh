#!/bin/bash
# uninstall.sh — Remove stub apps and all protections
# Requires: sudo
set -euo pipefail

STUB_APPS=(
  "Microsoft Outlook"
  "Microsoft Excel"
  "Microsoft Word"
  "Microsoft OneNote"
  "Microsoft OneDrive"
  "Microsoft 365 Copilot"
  "OneDrive"
  "Keynote"
  "Pages"
  "Numbers"
  "zoom.us"
  "Firefox"
  "VLC"
)

LOCALIZED_STUBS=(
  "OneDrive"
)

PROTECTED_PATHS=(
  "/Library/LaunchAgents/com.microsoft.OneDriveStandaloneUpdater.plist"
  "/Library/LaunchAgents/com.microsoft.SyncReporter.plist"
  "/Library/LaunchDaemons/com.microsoft.OneDriveStandaloneUpdaterDaemon.plist"
  "/Library/LaunchDaemons/com.microsoft.OneDriveUpdaterDaemon.plist"
  "/Library/LaunchDaemons/us.zoom.ZoomDaemon.plist"
  "/Library/PrivilegedHelperTools/us.zoom.ZoomDaemon"
)

for app_name in "${STUB_APPS[@]}"; do
  app_path="/Applications/${app_name}.app"

  if [ -d "$app_path" ]; then
    echo "==> Removing stub: ${app_name}"
    chflags -R noschg "$app_path" 2>/dev/null || true
    chmod -RN "$app_path" 2>/dev/null || true
    rm -rf "$app_path"
    echo "    Removed"
  else
    echo "==> ${app_name}: not found, skipping"
  fi
done

for folder_name in "${LOCALIZED_STUBS[@]}"; do
  folder_path="/Applications/${folder_name}.localized"

  if [ -d "$folder_path" ]; then
    echo "==> Removing .localized stub: ${folder_name}"
    chflags -R noschg "$folder_path" 2>/dev/null || true
    chmod -RN "$folder_path" 2>/dev/null || true
    rm -rf "$folder_path"
    echo "    Removed"
  else
    echo "==> ${folder_name}.localized: not found, skipping"
  fi
done

for path in "${PROTECTED_PATHS[@]}"; do
  if [ -e "$path" ]; then
    echo "==> Removing protected stub: ${path}"
    chflags noschg "$path" 2>/dev/null || true
    chmod -N "$path" 2>/dev/null || true
    rm -f "$path"
    echo "    Removed"
  else
    echo "==> ${path}: not found, skipping"
  fi
done

echo ""
echo "All stubs removed. MDM will reinstall the apps on next policy run."
