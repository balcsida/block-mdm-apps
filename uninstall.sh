#!/bin/bash
# uninstall.sh — Remove stub apps and all protections
# Requires: sudo
set -euo pipefail

STUB_APPS=(
  "Microsoft Outlook"
  "Microsoft Excel"
  "Microsoft OneNote"
  "Microsoft OneDrive"
  # Add any extras you added to setup.sh:
  # "Microsoft Word"
  # "Microsoft PowerPoint"
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

echo ""
echo "All stubs removed. MDM will reinstall the apps on next policy run."
