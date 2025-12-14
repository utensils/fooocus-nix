# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Build the package
nix build

# Run Fooocus
nix run                     # Default preset
nix run .#anime             # Anime preset
nix run .#realistic         # Realistic preset

# Run all CI checks (package build, shellcheck, nixfmt)
nix flake check

# Enter development shell
nix develop

# Format Nix files
nix fmt

# Docker images
nix run .#buildDocker       # Build CPU image
nix run .#buildDockerCuda   # Build CUDA image

# Check for upstream Fooocus updates
nix run .#update
```

## Architecture Overview

This is a Nix flake that packages [Fooocus](https://github.com/lllyasviel/Fooocus) for reproducible deployment. The flake uses a hybrid approach: Nix handles environment setup and packaging, while pip manages Python dependencies at runtime.

### Key Design Decisions

1. **Runtime pip installation**: Python dependencies are installed via pip into a venv at `~/.config/fooocus/venv` on first run, not at Nix build time. This allows GPU-specific PyTorch versions to be detected and installed dynamically.

2. **Nix variable substitution**: Shell scripts use `@varName@` placeholders that `pkgs.replaceVars` substitutes at build time. Only `config.sh` and `launcher.sh` have substitutions; other scripts are copied directly.

3. **Persistent data**: All user data lives in `~/.config/fooocus/` with symlinks from the app directory. Models, outputs, and venv persist across updates.

### Script Flow

```
launcher.sh (entry point)
  → sources config.sh (sets paths, parses args)
  → sources logger.sh (logging utilities)
  → sources install.sh (creates venv, installs deps)
  → sources persistence.sh (sets up symlinks)
  → sources runtime.sh (starts Fooocus via launch.py)
```

### Flake Structure

- **Inputs**: `nixpkgs`, `flake-utils`, `fooocus-src` (non-flake GitHub source)
- **Version**: Derived from `fooocus-src.shortRev` (git short hash)
- **Packages**: `default` (main), `dockerImage` (CPU), `dockerImageCuda` (CUDA)
- **Apps**: `default`, `anime`, `realistic`, `buildDocker`, `buildDockerCuda`, `update`, linting apps
- **Checks**: `package`, `shellcheck`, `nixfmt`

### Known Issue: Symlinked Paths

Gradio blocks file access through symlinks. If users report "File not allowed" for log.html, they need to edit `~/.config/fooocus/app/config.txt` and change `path_outputs` from the symlink path to the real path (`~/.config/fooocus/outputs` instead of `~/.config/fooocus/app/outputs`).

## Updating Fooocus Version

Fooocus source is tracked as a flake input, so updating is simple:

```bash
nix flake update fooocus-src
```

This fetches the latest HEAD from GitHub. The version shown will be the git short rev (e.g., `ae05379`).
