{
  description = "Development shell for EVE Fit Assistant";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "minio-2025-10-15T17-29-55Z" ];
          android_sdk.accept_license = true;
        };
      };

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        includeCmake = true;
        includeEmulator = true;
        includeNDK = true;
        includeSystemImages = true;
        systemImageTypes = [ "google_apis" ];
        abiVersions = [ "x86_64" ];
        platformVersions = [
          "31"
          "33"
          "34"
          "35"
          "36"
        ];
        buildToolsVersions = [ "35.0.0" ];
        cmakeVersions = [ "latest" ];
        ndkVersions = [ "28.2.13676358" ];
      };

      androidEmulatorFhs = pkgs.buildFHSEnv {
        name = "android-emulator-fhs";
        targetPkgs = pkgs: [
          pkgs.alsa-lib
          pkgs.dbus
          pkgs.expat
          pkgs.fontconfig
          pkgs.freetype
          pkgs.glib
          pkgs.gperftools
          pkgs.libbsd
          pkgs.libdrm
          pkgs.libGL
          pkgs.libpng
          pkgs.libpulseaudio
          pkgs.libuuid
          pkgs.libxkbcommon
          pkgs.nspr
          pkgs.nss
          pkgs.stdenv.cc.cc
          pkgs.vulkan-loader
          pkgs.libx11
          pkgs.libxcomposite
          pkgs.libxcursor
          pkgs.libxdamage
          pkgs.libxext
          pkgs.libxfixes
          pkgs.libxi
          pkgs.libxrandr
          pkgs.libxrender
          pkgs.libice
          pkgs.libsm
          pkgs.libxtst
          pkgs.libxcb
          pkgs.xcb-util-cursor
          pkgs.xcbutilimage
          pkgs.xcbutilkeysyms
          pkgs.xcbutilrenderutil
          pkgs.xcbutilwm
          pkgs.libxkbfile
          pkgs.zlib
        ];
        runScript = "bash";
      };
      androidEmulatorWrapper = pkgs.writeShellScript "android-emulator" ''
        export EFA_HOST_ANDROID_EMULATOR="$HOME/Android/Sdk/emulator"
        fhs_command='export LD_LIBRARY_PATH="$EFA_HOST_ANDROID_EMULATOR/lib64:$EFA_HOST_ANDROID_EMULATOR/lib64/qt/lib:$EFA_HOST_ANDROID_EMULATOR/lib64/gles_swiftshader:$LD_LIBRARY_PATH"; exec "$@"'

        case " $* " in
          *" -list-avds "* | *" -accel-check "* | *" -version "*)
            exec ${androidEmulatorFhs}/bin/android-emulator-fhs -c "$fhs_command" android-emulator "$EFA_HOST_ANDROID_EMULATOR/emulator" "$@"
            ;;
          *)
            mkdir -p "$HOME/.cache/eve-fit-assistant"
            setsid ${androidEmulatorFhs}/bin/android-emulator-fhs -c "$fhs_command" android-emulator "$EFA_HOST_ANDROID_EMULATOR/emulator" "$@" \
              > "$HOME/.cache/eve-fit-assistant/android-emulator.log" 2>&1 < /dev/null &
            ;;
        esac
      '';
      androidSdk = androidComposition.androidsdk;
      androidSdkRoot = "${androidSdk}/libexec/android-sdk";
      runtimeLibraryPath = pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc
        pkgs.openssl
        pkgs.curl
      ];
      nativeRustToolchainPath = pkgs.lib.makeBinPath [
        pkgs.cargo
        pkgs.rustc
        pkgs.rustfmt
        pkgs.clippy
        pkgs.rust-analyzer
      ];
      inherit (pkgs)
        flutter
        jdk17
        python3
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          androidSdk
          androidComposition.platform-tools
          flutter
          jdk17
          uv
          python3
          rustup
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer
          pkg-config
          cmake
          ninja
          minio
          minio-client
          clang
          llvmPackages.libclang
          protobuf
          protoc-gen-dart
          flutter_rust_bridge_codegen
          git-cliff
          cargo-expand
        ];

        LANG = "C.UTF-8";
        LC_ALL = "C.UTF-8";
        JAVA_HOME = jdk17.home;
        NIX_ANDROID_SDK_ROOT = androidSdkRoot;
        ANDROID_SDK_ROOT = androidSdkRoot;
        ANDROID_HOME = androidSdkRoot;
        ANDROID_NDK_ROOT = "${androidSdkRoot}/ndk-bundle";
        NDK_HOME = "${androidSdkRoot}/ndk-bundle";
        UV_PYTHON = "${python3}/bin/python3";
        UV_PYTHON_DOWNLOADS = "never";
        LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

        shellHook = ''
                            export LD_LIBRARY_PATH="${runtimeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
                            # Prefer the Nix-wrapped Rust toolchain for local builds and codegen.
                            # rustup remains available later in PATH for target management via cargokit.
                            export PATH="${nativeRustToolchainPath}:$PATH"

          host_android_sdk="$HOME/Android/Sdk"
          if [ -x "$host_android_sdk/emulator/emulator" ]; then
            sdk_shim="$PWD/.direnv/android-sdk"
            mkdir -p "$sdk_shim/emulator"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/build-tools" "$sdk_shim/build-tools"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/cmake" "$sdk_shim/cmake"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/cmdline-tools" "$sdk_shim/cmdline-tools"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/licenses" "$sdk_shim/licenses"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/ndk" "$sdk_shim/ndk"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/ndk-bundle" "$sdk_shim/ndk-bundle"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/platform-tools" "$sdk_shim/platform-tools"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/platforms" "$sdk_shim/platforms"
            ln -sfn "$NIX_ANDROID_SDK_ROOT/tools" "$sdk_shim/tools"
            ln -sfn "$host_android_sdk/system-images" "$sdk_shim/system-images"
            ln -sfn "${androidEmulatorWrapper}" "$sdk_shim/emulator/emulator"

          export ANDROID_SDK_ROOT="$sdk_shim"
                              export ANDROID_HOME="$sdk_shim"
                            fi

                            aapt2_path="$(echo "$NIX_ANDROID_SDK_ROOT/build-tools/"*"/aapt2")"
                            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$aapt2_path''${GRADLE_OPTS:+ $GRADLE_OPTS}"

                            cmake_root="$(echo "$NIX_ANDROID_SDK_ROOT/cmake/"*/)"
                            export PATH="$cmake_root/bin:$PATH"

          local_properties="android/local.properties"
          marker="# Generated by nix develop from flake.nix"

          if [ ! -f "$local_properties" ] \
            || grep -Fqx "$marker" "$local_properties" \
            || grep -Fqx "sdk.dir=$ANDROID_SDK_ROOT" "$local_properties"; then
            {
              printf '%s\n' \
                "$marker" \
                "flutter.sdk=${flutter}" \
                "sdk.dir=$ANDROID_SDK_ROOT" \
                "ndk.dir=$ANDROID_SDK_ROOT/ndk-bundle" \
                "cmake.dir=$ANDROID_SDK_ROOT/cmake/$(basename "$cmake_root")"
            } > "$local_properties"
          fi
        '';
      };
    };
}
