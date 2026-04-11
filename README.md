# block-mdm-microsoft-apps

Prevent MDM (Jamf Pro, etc.) from reinstalling unwanted Microsoft apps on macOS.

Creates **stub `.app` bundles** with the correct bundle identifiers and a high version number, then locks them with **immutable flags** and **ACL deny rules**.

## How it works

1. **Smart Group evasion** — MDM policies typically target devices where "app not installed" or "version < X". A stub with version `99.0.0` and the real bundle ID causes your device to fall out of scope, so the install policy **never runs**.
2. **`chflags schg`** — System immutable flag prevents the `installer` binary from overwriting the stub, even as root.
3. **ACL deny rules** — Denies write/delete to everyone as a second layer.

## Quick start

```bash
git clone https://github.com/balcsida/block-mdm-microsoft-apps.git
cd block-mdm-microsoft-apps

# Review/edit the APPS array in setup.sh, then:
sudo bash setup.sh

# Optionally force MDM to re-inventory immediately (Jamf example):
# sudo jamf recon
```

## Customise

Edit the `APPS` associative array at the top of `setup.sh`:

```bash
declare -A APPS=(
  ["Microsoft Outlook"]="com.microsoft.Outlook"
  ["Microsoft Excel"]="com.microsoft.Excel"
  ["Microsoft OneNote"]="com.microsoft.onenote.mac"
  ["Microsoft OneDrive"]="com.microsoft.OneDrive"
  # ["Microsoft Word"]="com.microsoft.Word"
  # ["Microsoft PowerPoint"]="com.microsoft.Powerpoint"
)
```

Then re-run `sudo bash setup.sh`.

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
