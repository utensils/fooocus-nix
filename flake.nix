{
  description = "A Nix flake for Fooocus with Python 3.12";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fooocus-src = {
      url = "github:lllyasviel/Fooocus";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      fooocus-src,
      ...
    }:
    let
      # Version is derived from flake.lock (updated via `nix flake update`)
      fooocusVersion = fooocus-src.shortRev or "HEAD";
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        # Allow unfree packages
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
          };
        };

        # Python environment with minimal dependencies for bootstrapping
        # All Fooocus dependencies are installed via pip in the virtual environment
        pythonEnv = pkgs.python312.buildEnv.override {
          extraLibs = with pkgs.python312Packages; [
            setuptools
            wheel
            pip
          ];
          ignoreCollisions = true;
        };

        # Process each script file individually using replaceVars
        # Only replace variables that actually exist in each script
        configScript = pkgs.replaceVars ./scripts/config.sh {
          inherit pythonEnv;
          fooocusSrc = fooocus-src;
        };

        # Main launcher script with substitutions
        launcherScript = pkgs.replaceVars ./scripts/launcher.sh {
          libPath = "${pkgs.stdenv.cc.cc.lib}/lib";
        };

        # Create a directory with all scripts
        scriptDir = pkgs.runCommand "fooocus-scripts" { } ''
          mkdir -p $out
          cp ${configScript} $out/config.sh
          cp ${./scripts/logger.sh} $out/logger.sh
          cp ${./scripts/install.sh} $out/install.sh
          cp ${./scripts/persistence.sh} $out/persistence.sh
          cp ${./scripts/runtime.sh} $out/runtime.sh
          cp ${launcherScript} $out/launcher.sh
          chmod +x $out/*.sh
        '';

        # Define all packages in one attribute set
        packages = rec {
          default = pkgs.stdenv.mkDerivation {
            pname = "fooocus";
            version = fooocusVersion;

            src = fooocus-src;

            # Passthru for scripting and testing
            passthru = {
              inherit fooocus-src;
              version = fooocusVersion;
            };

            nativeBuildInputs = [
              pkgs.makeWrapper
              pythonEnv
            ];
            buildInputs = [
              pkgs.libGL
              pkgs.libGLU
              pkgs.stdenv.cc.cc.lib
            ];

            # Skip build and configure phases
            dontBuild = true;
            dontConfigure = true;

            installPhase = ''
              # Create directories
              mkdir -p "$out/bin"
              mkdir -p "$out/share/fooocus"

              # Copy Fooocus files
              cp -r ${fooocus-src}/* "$out/share/fooocus/"

              # Create scripts directory
              mkdir -p "$out/share/fooocus/scripts"

              # Copy all script files
              cp -r ${scriptDir}/* "$out/share/fooocus/scripts/"

              # Install the launcher script
              ln -s "$out/share/fooocus/scripts/launcher.sh" "$out/bin/fooocus-launcher"
              chmod +x "$out/bin/fooocus-launcher"

              # Create a symlink to the launcher
              ln -s "$out/bin/fooocus-launcher" "$out/bin/fooocus"
            '';

            meta = with pkgs.lib; {
              description = "Fooocus - Focus on prompting and generating";
              homepage = "https://github.com/lllyasviel/Fooocus";
              license = licenses.mit;
              platforms = platforms.all;
              mainProgram = "fooocus";
            };
          };

          # Docker image for Fooocus (CPU)
          dockerImage = pkgs.dockerTools.buildImage {
            name = "fooocus";
            tag = "latest";

            # Include essential utilities and core dependencies
            copyToRoot = pkgs.buildEnv {
              name = "root";
              paths = [
                pkgs.bash
                pkgs.coreutils
                pkgs.netcat
                pkgs.git
                pkgs.curl
                pkgs.cacert
                pkgs.libGL
                pkgs.libGLU
                pkgs.stdenv.cc.cc.lib
                default
              ];
              pathsToLink = [
                "/bin"
                "/etc"
                "/lib"
                "/share"
              ];
            };

            # Set up volumes and ports
            config = {
              Cmd = [
                "/bin/bash"
                "-c"
                "export FOOOCUS_USER_DIR=/data && mkdir -p /data && /bin/fooocus --listen 0.0.0.0"
              ];
              Env = [
                "FOOOCUS_USER_DIR=/data"
                "PATH=/bin:/usr/bin"
                "PYTHONUNBUFFERED=1"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
                "CUDA_VERSION=cpu"
              ];
              ExposedPorts = {
                "7865/tcp" = { };
              };
              WorkingDir = "/data";
              Volumes = {
                "/data" = { };
              };
              Healthcheck = {
                Test = [
                  "CMD"
                  "nc"
                  "-z"
                  "localhost"
                  "7865"
                ];
                Interval = 30000000000; # 30 seconds in nanoseconds
                Timeout = 5000000000; # 5 seconds in nanoseconds
                Retries = 3;
                StartPeriod = 60000000000; # 60 seconds grace period for startup
              };
              Labels = {
                "org.opencontainers.image.title" = "Fooocus";
                "org.opencontainers.image.description" = "Fooocus - Focus on prompting and generating";
                "org.opencontainers.image.version" = fooocusVersion;
                "org.opencontainers.image.source" = "https://github.com/utensils/fooocus-nix";
                "org.opencontainers.image.licenses" = "GPL-3.0";
              };
            };
          };

          # Docker image for Fooocus with CUDA support
          dockerImageCuda = pkgs.dockerTools.buildImage {
            name = "fooocus";
            tag = "cuda";

            # Include essential utilities, core dependencies, and CUDA libraries
            copyToRoot = pkgs.buildEnv {
              name = "root";
              paths = [
                pkgs.bash
                pkgs.coreutils
                pkgs.netcat
                pkgs.git
                pkgs.curl
                pkgs.cacert
                pkgs.libGL
                pkgs.libGLU
                pkgs.stdenv.cc.cc.lib
                default
              ];
              pathsToLink = [
                "/bin"
                "/etc"
                "/lib"
                "/share"
              ];
            };

            # Set up volumes and ports
            config = {
              Cmd = [
                "/bin/bash"
                "-c"
                "export FOOOCUS_USER_DIR=/data && mkdir -p /data && /bin/fooocus --listen 0.0.0.0"
              ];
              Env = [
                "FOOOCUS_USER_DIR=/data"
                "PATH=/bin:/usr/bin"
                "PYTHONUNBUFFERED=1"
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
                "NVIDIA_VISIBLE_DEVICES=all"
                "NVIDIA_DRIVER_CAPABILITIES=compute,utility"
                "CUDA_VERSION=cu124"
              ];
              ExposedPorts = {
                "7865/tcp" = { };
              };
              WorkingDir = "/data";
              Volumes = {
                "/data" = { };
              };
              Healthcheck = {
                Test = [
                  "CMD"
                  "nc"
                  "-z"
                  "localhost"
                  "7865"
                ];
                Interval = 30000000000; # 30 seconds in nanoseconds
                Timeout = 5000000000; # 5 seconds in nanoseconds
                Retries = 3;
                StartPeriod = 60000000000; # 60 seconds grace period for startup
              };
              Labels = {
                "org.opencontainers.image.title" = "Fooocus CUDA";
                "org.opencontainers.image.description" = "Fooocus with CUDA support for GPU acceleration";
                "org.opencontainers.image.version" = fooocusVersion;
                "org.opencontainers.image.source" = "https://github.com/utensils/fooocus-nix";
                "org.opencontainers.image.licenses" = "GPL-3.0";
                "com.nvidia.volumes.needed" = "nvidia_driver";
              };
            };
          };
        };
      in
      {
        # Export packages
        inherit packages;

        # Define apps
        apps = rec {
          default = {
            type = "app";
            program = "${packages.default}/bin/fooocus";
            meta = {
              description = "Run Fooocus with default preset";
            };
          };

          # Anime preset app
          anime = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "fooocus-anime" ''
                exec ${packages.default}/bin/fooocus --preset=anime "$@"
              ''
            );
            meta = {
              description = "Run Fooocus with anime preset";
            };
          };

          # Realistic preset app
          realistic = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "fooocus-realistic" ''
                exec ${packages.default}/bin/fooocus --preset=realistic "$@"
              ''
            );
            meta = {
              description = "Run Fooocus with realistic preset";
            };
          };

          # Add a buildDocker command
          buildDocker =
            let
              script = pkgs.writeShellScriptBin "build-docker" ''
                echo "Building Docker image for Fooocus..."
                # Load the Docker image directly
                ${pkgs.docker}/bin/docker load < ${self.packages.${system}.dockerImage}
                echo "Docker image built successfully! You can now run it with:"
                echo "docker run -p 7865:7865 -v \$PWD/data:/data fooocus:latest"
              '';
            in
            {
              type = "app";
              program = "${script}/bin/build-docker";
              meta = {
                description = "Build Fooocus Docker image (CPU)";
              };
            };

          # Add a buildDockerCuda command
          buildDockerCuda =
            let
              script = pkgs.writeShellScriptBin "build-docker-cuda" ''
                echo "Building Docker image for Fooocus with CUDA support..."
                # Load the Docker image directly
                ${pkgs.docker}/bin/docker load < ${self.packages.${system}.dockerImageCuda}
                echo "CUDA-enabled Docker image built successfully! You can now run it with:"
                echo "docker run --gpus all -p 7865:7865 -v \$PWD/data:/data fooocus:cuda"
                echo ""
                echo "Note: Requires nvidia-container-toolkit and Docker GPU support."
              '';
            in
            {
              type = "app";
              program = "${script}/bin/build-docker-cuda";
              meta = {
                description = "Build Fooocus Docker image with CUDA support";
              };
            };

          # Update helper script
          update = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "update-fooocus" ''
                set -e
                echo "Fetching latest Fooocus release..."
                LATEST=$(curl -s https://api.github.com/repos/lllyasviel/Fooocus/releases/latest | ${pkgs.jq}/bin/jq -r '.tag_name')
                echo "Latest version: $LATEST"
                echo ""
                echo "To update, modify these values in flake.nix:"
                echo "  fooocusVersion = \"''${LATEST#v}\";"
                echo "  fooocusRev = \"$LATEST\";"
                echo ""
                echo "Then run: nix flake update"
                echo "And update the hash with: nix build 2>&1 | grep 'got:' | awk '{print \$2}'"
              ''
            );
            meta = {
              description = "Check for Fooocus updates";
            };
          };

          # Linting and formatting apps
          lint =
            let
              script = pkgs.writeShellScriptBin "lint" ''
                echo "Running ruff linter..."
                ${pkgs.ruff}/bin/ruff check --no-cache .
              '';
            in
            {
              type = "app";
              program = "${script}/bin/lint";
              meta = {
                description = "Run ruff linter on Python code";
              };
            };

          format =
            let
              script = pkgs.writeShellScriptBin "format" ''
                echo "Formatting code with ruff..."
                ${pkgs.ruff}/bin/ruff format --no-cache .
              '';
            in
            {
              type = "app";
              program = "${script}/bin/format";
              meta = {
                description = "Format Python code with ruff";
              };
            };

          lint-fix =
            let
              script = pkgs.writeShellScriptBin "lint-fix" ''
                echo "Running ruff linter with auto-fix..."
                ${pkgs.ruff}/bin/ruff check --no-cache --fix .
              '';
            in
            {
              type = "app";
              program = "${script}/bin/lint-fix";
              meta = {
                description = "Run ruff linter with auto-fix";
              };
            };

          type-check =
            let
              script = pkgs.writeShellScriptBin "type-check" ''
                echo "Running pyright type checker..."
                ${pkgs.pyright}/bin/pyright .
              '';
            in
            {
              type = "app";
              program = "${script}/bin/type-check";
              meta = {
                description = "Run pyright type checker on Python code";
              };
            };

          check-all =
            let
              script = pkgs.writeShellScriptBin "check-all" ''
                echo "Running all checks..."
                echo ""
                echo "==> Running ruff linter..."
                ${pkgs.ruff}/bin/ruff check --no-cache .
                RUFF_EXIT=$?
                echo ""
                echo "==> Running pyright type checker..."
                ${pkgs.pyright}/bin/pyright .
                PYRIGHT_EXIT=$?
                echo ""
                if [ $RUFF_EXIT -eq 0 ] && [ $PYRIGHT_EXIT -eq 0 ]; then
                  echo "All checks passed!"
                  exit 0
                else
                  echo "Some checks failed."
                  exit 1
                fi
              '';
            in
            {
              type = "app";
              program = "${script}/bin/check-all";
              meta = {
                description = "Run all Python code checks (ruff + pyright)";
              };
            };
        };

        # Define development shell
        devShells.default = pkgs.mkShell {
          packages = [
            pythonEnv
            pkgs.stdenv.cc
            pkgs.libGL
            pkgs.libGLU
            # Development tools
            pkgs.git
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.nixfmt-rfc-style
            # Python linting and type checking
            pkgs.ruff
            pkgs.pyright
            # Utilities
            pkgs.jq
            pkgs.curl
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # macOS-specific tools
            pkgs.darwin.apple_sdk.frameworks.Metal
          ];

          shellHook = ''
            echo "Fooocus development environment activated"
            echo "  Fooocus version: ${fooocusVersion}"
            export FOOOCUS_USER_DIR="$HOME/.config/fooocus"
            mkdir -p "$FOOOCUS_USER_DIR"
            echo "User data will be stored in $FOOOCUS_USER_DIR"
            export PYTHONPATH="$PWD:$PYTHONPATH"
          '';
        };

        # Formatter for `nix fmt`
        formatter = pkgs.nixfmt-rfc-style;

        # Checks for CI (run with `nix flake check`)
        checks = {
          # Verify the package builds
          package = packages.default;

          # Shell script linting with cross-file analysis
          shellcheck =
            pkgs.runCommand "shellcheck"
              {
                nativeBuildInputs = [ pkgs.shellcheck ];
                src = ./.;
              }
              ''
                cp -r $src source
                chmod -R u+w source
                cd source/scripts
                # Check launcher.sh with -x to follow all source statements
                # This allows shellcheck to see variables defined in config.sh and used in install.sh
                shellcheck -x launcher.sh
                # Also check individual utility scripts
                shellcheck logger.sh runtime.sh persistence.sh
                touch $out
              '';

          # Nix formatting check
          nixfmt =
            pkgs.runCommand "nixfmt-check"
              {
                nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
                src = ./.;
              }
              ''
                cp -r $src source
                chmod -R u+w source
                cd source
                nixfmt --check flake.nix
                touch $out
              '';
        };
      }
    )
    // {
      # Overlay for integrating with other flakes
      overlays.default = final: prev: {
        fooocus = self.packages.${final.system}.default;
      };
    };
}
