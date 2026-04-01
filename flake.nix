{
  description = "Nix packaging for amux - Claude Code session multiplexer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        runtimeDeps = with pkgs; [
          python311
          tmux
          nodejs_22
          curl
          git
          bash
          coreutils
          gnugrep
          gnused
          gawk
          findutils
          procps
          jq
          openssl
        ];

        amux-version = "0.3.0";
        amux-rev = "3d945d698b3f766ef41f1a6feb08d8455fdf8361";

        amuxSrc = pkgs.fetchFromGitHub {
          owner = "mixpeek";
          repo = "amux";
          rev = amux-rev;
          hash = "sha256-sj+Z/FfBGJm7OTiY7qh8NTI9h+QsfIfAUHPfkSjKQ5M=";
        };

        amux-unwrapped = pkgs.stdenv.mkDerivation {
          pname = "amux";
          version = amux-version;
          src = amuxSrc;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/bin
            install -m755 amux $out/bin/amux
            install -m755 amux-server.py $out/bin/amux-server.py
          '';
        };

        amux = pkgs.buildFHSEnv {
          name = "amux";
          targetPkgs = _: runtimeDeps ++ [ amux-unwrapped ];
          runScript = "amux";
          meta = with pkgs.lib; {
            description = "Claude Code session multiplexer";
            homepage = "https://github.com/mixpeek/amux";
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

      in {
        packages = {
          inherit amux amux-unwrapped;
          default = amux;
        };

        devShells.default = pkgs.mkShell {
          packages = runtimeDeps;
        };
      }
    );
}
