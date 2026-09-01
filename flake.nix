{
  description = "Development shell for EVE Fit Assistant";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.fenix.url = "github:nix-community/fenix";
  inputs.fenix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { nixpkgs, fenix, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "minio-2025-10-15T17-29-55Z" ];
          android_sdk.accept_license = true;
        };
        overlays = [
          (self: super: {
            # Use FRB codegen's prerelease version.
            # Note that we're hacking through the rust building by directly fetchurl.
            # This should be changed once upstream released a stable version and nixpkgs accepts that.
            flutter_rust_bridge_codegen = pkgs.stdenv.mkDerivation rec {
              pname = "flutter_rust_bridge_codegen";
              version = "2.13.0-beta.6";
              src = super.fetchzip {
                url = "https://github.com/fzyzcjy/flutter_rust_bridge/releases/download/v${version}/flutter_rust_bridge_codegen-x86_64-unknown-linux-gnu-v2.13.0-beta.6.tgz";
                sha256 = "sha256-CpTIFmauY9hP8Q2ZyVxeTYZNsD8TLM42FQYfkN9zJHk=";
              };
              dontBuild = true;

              installPhase = ''
                runHook preInstall
                mkdir -p $out/bin

                install -m755 flutter_rust_bridge_codegen $out/bin/flutter_rust_bridge_codegen

                runHook postInstall
              '';
            };
          })
        ];
      };

      androidVersions = [
        31
        33
        34
        35
        36
        37
      ];
      androidPlatformVersions = map toString androidVersions;
      androidBuildToolsVersions = map (v: "${v}.0.0") androidPlatformVersions;

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        includeCmake = true;
        includeNDK = true;
        platformVersions = androidPlatformVersions;
        buildToolsVersions = androidBuildToolsVersions;
        cmakeVersions = [ "latest" ];
        ndkVersions = [ "28.2.13676358" ];
      };

      developmentAndroidComposition = pkgs.androidenv.composeAndroidPackages {
        includeCmake = true;
        includeNDK = true;
        includeEmulator = true;
        platformVersions = androidPlatformVersions;
        buildToolsVersions = androidBuildToolsVersions;
        cmakeVersions = [ "latest" ];
        ndkVersions = [ "28.2.13676358" ];
      };

      androidSdk = androidComposition.androidsdk;
      androidSdkRoot = "${androidSdk}/libexec/android-sdk";

      developmentAndroidSdk = developmentAndroidComposition.androidsdk;
      developmentAndroidSdkRoot = "${developmentAndroidSdk}/libexec/android-sdk";

      runtimeLibraryPath = pkgs.lib.makeLibraryPath [
        pkgs.stdenv.cc.cc
        pkgs.zlib
        pkgs.openssl
        pkgs.curl
        pkgs.libsecret
      ];

      fenixPkgs = fenix.packages.${system};

      rustCrossTargets = [
        "aarch64-linux-android"
        "armv7-linux-androideabi"
        "i686-linux-android"
        "x86_64-linux-android"
        "wasm32-unknown-unknown"
      ];

      rustToolchain = fenixPkgs.combine (
        [
          (fenixPkgs.latest.withComponents [
            "cargo"
            "clippy"
            "rust-analyzer"
            "rustc"
            "rustfmt"
            "rust-src"
          ])
        ]
        ++ map (target: fenixPkgs.targets.${target}.latest.rust-std) rustCrossTargets
      );

      nativeRustToolchainPath = pkgs.lib.makeBinPath [ rustToolchain ];

      inherit (pkgs)
        flutter
        jdk17
        python3
        ;

      # --- Named package sets ---
      pythonPackages = with pkgs; [
        python3
        uv
      ];

      rustPackages = [ rustToolchain ];

      nativeBuildPackages = with pkgs; [
        pkg-config
        cmake
        ninja
        clang
        llvmPackages.libclang
        lld
      ];

      dartPackages = with pkgs; [
        flutter
        jdk17
      ];

      protobufPackages = with pkgs; [
        protobuf
        protoc-gen-dart
      ];

      frbPackages = with pkgs; [
        flutter_rust_bridge_codegen
        wasm-pack
        # Provides wasm-opt; wasm-pack uses the local binary instead of
        # downloading binaryen from GitHub releases (blocked in some envs).
        binaryen
      ];

      jsPackages = with pkgs; [
        nodejs_26
        pnpm
      ];

      releasePackages = with pkgs; [
        cargo-expand
        git-cliff
        minio
        minio-client
        wrangler
      ];

      # Not packaged in nixpkgs; wrap the upstream AppImage with appimage-run.
      # Not packaged in nixpkgs. The upstream AppImage's payload binaries
      # (appimagetool, mksquashfs, zsyncmake, desktop-file-validate) are
      # statically linked and run natively; the type-2 runtime used for the
      # AppImages it creates is embedded, so no wrapper or network is needed.
      appimagetoolAppImage = pkgs.fetchurl {
        name = "appimagetool-x86_64.AppImage";
        url = "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage";
        hash = "sha256-ptceK2zWb46NFsN60WRliYXgz1/KqVDJCkgokMudE+A=";
      };

      appimagetool = pkgs.runCommand "appimagetool" { nativeBuildInputs = [ pkgs.squashfsTools ]; } ''
        # The payload is a squashfs image appended to the static runtime.
        # Locate it via the 'hsqs' magic; the runtime contains a false
        # positive, so try every offset until extraction succeeds.
        for off in $(grep -abo hsqs ${appimagetoolAppImage} | cut -d: -f1); do
          if unsquashfs -o "$off" -d payload ${appimagetoolAppImage} >/dev/null 2>&1; then
            break
          fi
        done
        test -d payload || { echo "failed to extract appimagetool payload"; exit 1; }
        install -Dm755 payload/usr/bin/* -t $out/bin
      '';

      appimageTools = [
        appimagetool
        pkgs.linuxdeploy
      ];

      ciPackages = with pkgs; [
        zizmor
      ];

      basePackages =
        pythonPackages
        ++ rustPackages
        ++ nativeBuildPackages
        ++ dartPackages
        ++ protobufPackages
        ++ frbPackages
        ++ jsPackages
        ++ releasePackages
        ++ ciPackages;

      # --- Shared environment variables ---
      localeEnv = {
        LANG = "C.UTF-8";
        LC_ALL = "C.UTF-8";
      };
    in
    {
      devShells.${system} =
        let
          # Full development shell
          fullShell = pkgs.mkShell {
            packages =
              basePackages
              ++ appimageTools
              ++ [
                pkgs.worker-build
                developmentAndroidSdk
                developmentAndroidComposition.platform-tools
                pkgs.apksigner

                # linux platform support
                pkgs.libsecret
                pkgs.xdg-user-dirs
              ];

            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";
            JAVA_HOME = jdk17.home;
            flutter = "${pkgs.flutter}";
            FLUTTER_ROOT = "${pkgs.flutter}";
            NIX_ANDROID_SDK_ROOT = developmentAndroidSdkRoot;
            ANDROID_SDK_ROOT = developmentAndroidSdkRoot;
            ANDROID_HOME = developmentAndroidSdkRoot;
            ANDROID_NDK_ROOT = "${developmentAndroidSdkRoot}/ndk-bundle";
            NDK_HOME = "${developmentAndroidSdkRoot}/ndk-bundle";
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
            CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER = "${pkgs.lld}/bin/wasm-ld";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              export NATIVE_RUST_TOOLCHAIN_PATH="${nativeRustToolchainPath}"
              export PATH="${nativeRustToolchainPath}:$PATH"
              . scripts/setup-ld-library-path.sh
              . scripts/setup-rust-toolchain.sh
              . scripts/setup-android-sdk.sh
            '';
          };

          # Android build shell
          androidShell = pkgs.mkShell {
            packages = basePackages ++ [
              pkgs.worker-build
              androidSdk
              androidComposition.platform-tools
              pkgs.apksigner
            ];
            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";
            JAVA_HOME = jdk17.home;
            flutter = "${pkgs.flutter}";
            FLUTTER_ROOT = "${pkgs.flutter}";
            NIX_ANDROID_SDK_ROOT = androidSdkRoot;
            ANDROID_SDK_ROOT = androidSdkRoot;
            ANDROID_HOME = androidSdkRoot;
            ANDROID_NDK_ROOT = "${androidSdkRoot}/ndk-bundle";
            NDK_HOME = "${androidSdkRoot}/ndk-bundle";
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
            CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER = "${pkgs.lld}/bin/wasm-ld";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              export NATIVE_RUST_TOOLCHAIN_PATH="${nativeRustToolchainPath}"
              export PATH="${nativeRustToolchainPath}:$PATH"
              . scripts/setup-ld-library-path.sh
              . scripts/setup-rust-toolchain.sh
              . scripts/setup-android-sdk.sh
            '';
          };

          # Linux desktop build shell (AppImage packaging; no Android SDK)
          linuxShell = pkgs.mkShell {
            packages =
              basePackages
              ++ appimageTools
              ++ [
                pkgs.libsecret
                pkgs.xdg-user-dirs
              ];

            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";
            JAVA_HOME = jdk17.home;
            flutter = "${pkgs.flutter}";
            FLUTTER_ROOT = "${pkgs.flutter}";
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              export NATIVE_RUST_TOOLCHAIN_PATH="${nativeRustToolchainPath}"
              export PATH="${nativeRustToolchainPath}:$PATH"
              . scripts/setup-ld-library-path.sh
              . scripts/setup-rust-toolchain.sh
            '';
          };
        in
        {
          default = fullShell;
          full = fullShell;
          android = androidShell;
          linux = linuxShell;

          # Minimal Python shell: linting, formatting, tests, and CI remote mocks
          python = pkgs.mkShell {
            packages = pythonPackages ++ [
              pkgs.minio
              pkgs.minio-client
            ];

            inherit (localeEnv) LANG LC_ALL;
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Minimal Dart/Flutter shell: linting, formatting, and tests
          dart = pkgs.mkShell {
            packages = pythonPackages ++ dartPackages ++ protobufPackages;

            inherit (localeEnv) LANG LC_ALL;
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
            JAVA_HOME = jdk17.home;
            FLUTTER_ROOT = "${pkgs.flutter}";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Minimal Rust shell: linting, formatting, and tests
          # (protobuf/nativeBuildPackages: workspace crates compile protobuf
          # schemas via prost-build in their build scripts)
          rust = pkgs.mkShell {
            packages = pythonPackages ++ rustPackages ++ protobufPackages ++ nativeBuildPackages;

            inherit (localeEnv) LANG LC_ALL;
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Minimal JS/TS shell: linting, formatting, and type checks
          js = pkgs.mkShell {
            packages = pythonPackages ++ jsPackages;

            inherit (localeEnv) LANG LC_ALL;
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Minimal CI shell: GitHub workflow security scanning
          ci = pkgs.mkShell {
            packages = pythonPackages ++ ciPackages;

            inherit (localeEnv) LANG LC_ALL;
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Code generation shell: protobuf, FRB, dart build_runner, l10n
          # (jsPackages: TS protobuf bindings via buf from node_modules)
          codegen = pkgs.mkShell {
            packages =
              pythonPackages
              ++ rustPackages
              ++ nativeBuildPackages
              ++ dartPackages
              ++ protobufPackages
              ++ frbPackages
              ++ jsPackages
              ++ [ pkgs.libsecret ];

            inherit (localeEnv) LANG LC_ALL;
            JAVA_HOME = jdk17.home;
            FLUTTER_ROOT = "${pkgs.flutter}";
            UV_PYTHON = "${python3}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              export PATH="${nativeRustToolchainPath}:$PATH"
              . scripts/setup-ld-library-path.sh
            '';
          };
        };
    };
}
