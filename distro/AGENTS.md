# Native Packaging

Scope: platform packaging assets under `distro/linux/` and `distro/windows/`.

## Linux

- `./x build linux` emits `appimage` and `native` variants into
  `cache/releases/linux/<ver>/`.
- The AppImage path requires `linuxdeploy` and `appimagetool` from the Nix dev shell.
- `distro/linux/appimage/efa.desktop` declares the `efa://` scheme handler on a best-effort
  basis.

## Windows

- `./x build windows` runs only on a Windows host and emits `native` and `installer`
  variants into `cache/releases/windows/<ver>/`.
- The MSI source is `distro/windows/installer/Package.wxs` plus per-culture
  `Package.<culture>.wxl` files.
- Windows packaging uses WiX v6; WiX v7 is intentionally excluded because it requires
  accepting the OSMF EULA.
- `Package.wxs` registers the `efa://` scheme per user.

See @docs/agents/build-and-test and @docs/agents/environment for prerequisites and detailed
variant behavior.
