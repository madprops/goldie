{
  description = "Goldie - Find text in files recursively";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {self, nixpkgs}:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs {inherit system;});

      mkPcre = pkgs: pkgs.stdenv.mkDerivation {
        pname = "pcre";
        version = "8.45";
        src = pkgs.fetchurl {
          url = "mirror://sourceforge/pcre/pcre/8.45/pcre-8.45.tar.bz2";
          sha256 = "4dae6fdcd2bb0bb6c37b5f97c33c2be954da743985369cddac3546e3218bffb8";
        };
        configureFlags = [
          "--enable-unicode-properties"
          "--enable-utf"
        ];
      };
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          pcre = mkPcre pkgs;
        in {
          default = pkgs.buildNimPackage {
            pname = "goldie";
            version = "unstable";
            src = ./.;
            buildInputs = [
              pcre
            ];
            nimFlags = [
              "-d:usePcre"
              "--define:pcreDll:${pcre}/lib/libpcre.so"
            ];
          };
        });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          pcre = mkPcre pkgs;
        in {
          default = pkgs.mkShell {
            packages = [
              pkgs.nim
              pkgs.nimble
              pcre
            ];
          };
        });
    };
}