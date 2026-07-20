{ pkgs ? import <nixpkgs> {} }:

let
  wasmLd = "${pkgs.lld}/bin/wasm-ld";
in

pkgs.mkShell {
  buildInputs = with pkgs; [
    worker-build
    openssl.dev
    pkg-config
    lld
    nodejs
  ];

  shellHook = ''
    export OPENSSL_NO_VENDOR=1
    export OPENSSL_DIR="${pkgs.openssl.dev}"
    export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
    export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig"
    export CARGO_TARGET_WASM32_UNKNOWN_UNKNOWN_LINKER="${wasmLd}"
  '';
}
