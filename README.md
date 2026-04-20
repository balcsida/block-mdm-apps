# block-mdm-apps

Prevent MDM (Jamf Pro, etc.) from force-reinstalling unwanted apps on macOS.

Creates **stub `.app` bundles** with the correct bundle identifiers and a high version number, then locks them with **immutable flags** and **ACL deny rules**. Works with any app that your MDM pushes via policy — Microsoft Office, Slack, Zoom, Adobe Creative Cloud, or anything else.

## How it works

1. **Smart Group evasion** — MDM policies typically target devices where "app not installed" or "version < X". A stub with version `99.0.0` and the real bundle ID causes your device to fall out of scope, so the install policy **never runs**.
2. **`chflags schg`** — System immutable flag prevents the `installer` binary from overwriting the stub, even as root.
3. **ACL deny rules** — Denies write/delete to everyone as a second layer.

## Quick start

```bash
git clone https://github.com/balcsida/block-mdm-apps.git
cd block-mdm-apps

# Review/edit the APPS array in setup.sh, then:
sudo bash setup.sh

# Optionally force MDM to re-inventory immediately (Jamf example):
# sudo jamf recon
```

## Customise

Edit the `APPS` array at the top of `setup.sh`. Each entry is `"<app name>|<bundle identifier>"`, where `<app name>` matches `/Applications/<name>.app`:

```bash
APPS=(
  # Microsoft apps
  "Microsoft Outlook|com.microsoft.Outlook"
  "Microsoft Excel|com.microsoft.Excel"
  "Microsoft OneNote|com.microsoft.onenote.mac"
  "Microsoft OneDrive|com.microsoft.OneDrive"
  # "Microsoft Word|com.microsoft.Word"
  # "Microsoft PowerPoint|com.microsoft.Powerpoint"

  # Other examples — uncomment or add your own:
  # "Slack|com.tinyspeck.slackmacgap"
  # "zoom.us|us.zoom.xos"
  # "Adobe Creative Cloud|com.adobe.acc.AdobeCreativeCloud"
  # "Google Chrome|com.google.Chrome"
)
```

For apps whose installer drops into a `.localized` wrapper folder (OneDrive does this), add them to the `LOCALIZED_APPS` array instead — same format.

If MDM also pushes LaunchAgents/LaunchDaemons or privileged helpers for a blocked app (they show up as "legacy daemon" / "legacy agent" rows in System Settings → Login Items & Extensions, often with an "unidentified developer" label once the parent app is stubbed), list their absolute paths in `PROTECTED_PATHS`. They will be replaced with an empty file locked with `schg` + ACL so the installer can't put the real plist back.

To find the bundle identifier for any installed app:

```bash
mdls -name kMDItemCFBundleIdentifier /Applications/SomeApp.app
```

Then re-run `sudo bash setup.sh`.

## Keep stubs intact after bypass (optional)

If your MDM policy uses a **static group** (so Smart Group evasion doesn't apply) or runs a pre-install script that strips `chflags schg`/ACLs, the `installer` binary can still land a real app on disk — either at the original path or at a numbered fallback (`zoom.us 1.app`, `OneDrive-1.localized`, …). The included LaunchDaemon re-runs `setup.sh` every 15 minutes so any such reinstall is swept before long.

```bash
# Install
sudo install -m 0755 setup.sh /usr/local/sbin/block-mdm-apps-setup.sh
sudo install -m 0644 -o root -g wheel \
  launchd/com.github.balcsida.block-mdm-apps.plist \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
sudo launchctl bootstrap system \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist

# Verify
sudo launchctl print system/com.github.balcsida.block-mdm-apps | grep -E "state|last exit"
sudo tail /var/log/block-mdm-apps.log

# Uninstall
sudo launchctl bootout system \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
sudo rm /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
sudo rm /usr/local/sbin/block-mdm-apps-setup.sh
```

Tune the interval by editing `StartInterval` in the plist (seconds). Logs go to `/var/log/block-mdm-apps.log`. This is cat-and-mouse — the daemon is visible via `launchctl list` and a targeted audit would find it.

## Uninstall

```bash
sudo bash uninstall.sh
```

## Caveats

- Works when the MDM policy is scoped via a **Smart Group** that checks app presence/version (the standard practice). If the policy uses a **static group**, only the filesystem protections apply.
- A determined admin can script `chflags noschg` + `chmod -N` in a pre-install script to bypass the protections. In practice, default policies don't do this.
- Your device may show the apps as "installed (v99.0.0)" in MDM inventory. This is visible to your IT team if they look.
- Requires `sudo` for the initial setup (immutable flags and ACLs need root).

## License

MIT
