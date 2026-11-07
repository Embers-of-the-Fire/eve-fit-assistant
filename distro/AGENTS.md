# Native Packaging

Scope: platform packaging assets under `distro/linux/` and `distro/windows/`.

## Hard Constraints

- `./x build linux` requires `linuxdeploy` and `appimagetool` from the Nix dev shell.
- `./x build windows` runs only on a Windows host.
- Windows packaging uses WiX v6; WiX v7 is intentionally excluded because it requires
  accepting the OSMF EULA.
- The MSI source is `distro/windows/installer/Package.wxs` plus per-culture
  `Package.<culture>.wxl` files.
- `efa://` scheme registration: `distro/linux/appimage/efa.desktop` (best-effort) and
  `Package.wxs` (per user on Windows).

## Docs

- Builds and prerequisites: [docs/dev/build-and-test.md](../docs/dev/build-and-test.md)
- Environment setup: [docs/dev/setup-and-config.md](../docs/dev/setup-and-config.md)
