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

        # ── amux CLI ──────────────────────────────────────────────

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
            license = licenses.mit;
            platforms = platforms.linux;
          };
        };

        # ── amux Desktop (Electron app from GitHub releases) ─────

        amux-desktop-version = "0.2.3";

        amux-desktop-src = pkgs.fetchurl {
          url = "https://github.com/isboyjc/amux/releases/download/desktop-v${amux-desktop-version}/Amux-${amux-desktop-version}-linux-amd64.deb";
          hash = "sha256-t84mBkivBGdaLn/KUq1KrjshdnO6vGDMcyCvbb+HAao=";
        };

        amux-desktop-extracted = pkgs.stdenv.mkDerivation {
          pname = "amux-desktop-extracted";
          version = amux-desktop-version;
          src = amux-desktop-src;
          nativeBuildInputs = [ pkgs.dpkg ];
          unpackPhase = "dpkg-deb -x $src .";
          installPhase = ''
            mkdir -p $out/opt/Amux
            cp -r opt/Amux/* $out/opt/Amux/
            cp -r usr/share $out/share
          '';
        };

        amux-desktop-fhs = pkgs.buildFHSEnv {
          name = "amux-desktop";
          targetPkgs = pkgs: with pkgs; [
            # Electron / Chromium runtime deps
            alsa-lib
            at-spi2-atk
            at-spi2-core
            atk
            cairo
            cups
            dbus
            expat
            gdk-pixbuf
            glib
            gtk3
            libdrm
            libnotify
            libsecret
            libxkbcommon
            mesa
            libgbm
            libGL
            nspr
            nss
            pango
            systemd
            xdg-utils
            libx11
            libxscrnsaver
            libxcomposite
            libxdamage
            libxext
            libxfixes
            libxrandr
            libxtst
            libxcb
            libxshmfence
          ];
          runScript = "${amux-desktop-extracted}/opt/Amux/@amux.aidesktop";
          meta = with pkgs.lib; {
            description = "Amux Desktop - LLM API Proxy Bridge";
            homepage = "https://amux.ai";
            license = licenses.mit;
            platforms = [ "x86_64-linux" ];
          };
        };

        # Wrap with .desktop file and icons for system integration
        amux-desktop = pkgs.stdenv.mkDerivation {
          pname = "amux-desktop";
          version = amux-desktop-version;
          dontUnpack = true;
          installPhase = ''
            mkdir -p $out/bin
            ln -s ${amux-desktop-fhs}/bin/amux-desktop $out/bin/amux-desktop

            # Icons
            for size in 16 32 64 128 256 512 1024; do
              src_icon="${amux-desktop-extracted}/share/icons/hicolor/''${size}x''${size}/apps/@amux.aidesktop.png"
              if [ -f "$src_icon" ]; then
                mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
                cp "$src_icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/amux-desktop.png"
              fi
            done

            # Desktop entry
            mkdir -p $out/share/applications
            cat > $out/share/applications/amux-desktop.desktop << EOF
            [Desktop Entry]
            Name=Amux
            Comment=Amux Desktop - LLM API Proxy Bridge
            Exec=$out/bin/amux-desktop %U
            Icon=amux-desktop
            Type=Application
            Categories=Development;Utility;
            StartupWMClass=@amux.aidesktop
            EOF
          '';
          meta = with pkgs.lib; {
            description = "Amux Desktop - LLM API Proxy Bridge";
            homepage = "https://amux.ai";
            license = licenses.mit;
            platforms = [ "x86_64-linux" ];
          };
        };

      in {
        packages = {
          inherit amux amux-unwrapped amux-desktop;
          default = amux;
        };

        devShells.default = pkgs.mkShell {
          packages = runtimeDeps;
        };
      }
    );
}
