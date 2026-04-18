# LaunchDaemon (optional)

Periodically re-applies the stubs so that MDM pre-install scripts which strip
`chflags schg` / ACLs (the "determined admin" case in the main README) can't
leave a real app in place for long.

## Install

```bash
# 1. Copy setup.sh to a stable system path
sudo install -m 0755 setup.sh /usr/local/sbin/block-mdm-apps-setup.sh

# 2. Install the LaunchDaemon
sudo install -m 0644 -o root -g wheel \
  launchd/com.github.balcsida.block-mdm-apps.plist \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist

# 3. Load it
sudo launchctl bootstrap system \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
```

## Uninstall

```bash
sudo launchctl bootout system \
  /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
sudo rm /Library/LaunchDaemons/com.github.balcsida.block-mdm-apps.plist
sudo rm /usr/local/sbin/block-mdm-apps-setup.sh
```

## Tuning

- `StartInterval` is in seconds. `900` = 15 minutes. Lower = faster recovery
  after MDM reinstalls an app, higher = less churn.
- Logs to `/var/log/block-mdm-apps.log`.

## Caveats

This is cat-and-mouse. The daemon is visible to IT via `launchctl list` and
the log file. Default MDM policies don't look for it, but a targeted audit
would find it.
