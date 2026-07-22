{
  description = "Development shell for EVE Fit Assistant";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/64c08a7ca051951c8eae34e3e3cb1e202fe36786";

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

      androidVersions = [
        31
        33
        34
        35
        36
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

      # --- Named package sets ---
      pythonPackages = with pkgs; [
        python3
        uv
      ];

      rustPackages = with pkgs; [
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer
      ];

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

      frbPackages = with pkgs; [ flutter_rust_bridge_codegen ];

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
            packages = basePackages ++ [
              pkgs.rustup
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
              pkgs.rustup
              pkgs.worker-build
              androidSdk
              androidComposition.platform-tools
              pkgs.apksigner
            ];

            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";
            JAVA_HOME = jdk17.home;
            flutter = "${pkgs.flutter}";
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
        in
        {
          default = fullShell;
          full = fullShell;
          android = androidShell;

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

            shellHook = ''
              export LD_LIBRARY_PATH_RUNTIME="${runtimeLibraryPath}"
              . scripts/setup-ld-library-path.sh
            '';
          };

          # Minimal Rust shell: linting, formatting, and tests
          rust = pkgs.mkShell {
            packages = pythonPackages ++ rustPackages;

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
          codegen = pkgs.mkShell {
            packages =
              pythonPackages
              ++ rustPackages
              ++ nativeBuildPackages
              ++ dartPackages
              ++ protobufPackages
              ++ frbPackages
              ++ [ pkgs.libsecret ];

            inherit (localeEnv) LANG LC_ALL;
            JAVA_HOME = jdk17.home;
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
