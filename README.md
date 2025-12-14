# fooocus-nix

A Nix flake for [Fooocus](https://github.com/lllyasviel/Fooocus) - an image generating software focused on simplicity.

## Features

- Reproducible builds with Nix
- Automatic GPU detection (NVIDIA CUDA, Apple Silicon MPS, CPU fallback)
- Persistent data storage in `~/.config/fooocus`
- Docker images (CPU and CUDA variants)
- Multiple preset support (default, anime, realistic)

## Quick Start

Run Fooocus directly without installation:

```bash
nix run github:utensils/fooocus-nix
```

Or with a specific preset:

```bash
nix run github:utensils/fooocus-nix#anime
nix run github:utensils/fooocus-nix#realistic
```

## Installation

### Using Flakes

Add to your `flake.nix`:

```nix
{
  inputs.fooocus-nix.url = "github:utensils/fooocus-nix";
}
```

Then use the overlay or package:

```nix
# Using the overlay
nixpkgs.overlays = [ fooocus-nix.overlays.default ];

# Or directly reference the package
environment.systemPackages = [ fooocus-nix.packages.${system}.default ];
```

### Local Development

```bash
git clone https://github.com/utensils/fooocus-nix
cd fooocus-nix
nix develop  # Enter development shell
nix run      # Run Fooocus
```

## Usage

### Command Line Options

```bash
# Run with default settings
nix run .

# Open browser automatically when ready
nix run . -- --open

# Use a specific port
nix run . -- --port=7866

# Use a preset
nix run . -- --preset=anime

# Enable debug logging
nix run . -- --debug
```

### Available Apps

| Command | Description |
|---------|-------------|
| `nix run` | Run Fooocus with default preset |
| `nix run .#anime` | Run with anime preset |
| `nix run .#realistic` | Run with realistic preset |
| `nix run .#buildDocker` | Build CPU Docker image |
| `nix run .#buildDockerCuda` | Build CUDA Docker image |
| `nix run .#update` | Check for Fooocus updates |

### Docker

Build and run the Docker image:

```bash
# CPU version
nix run .#buildDocker
docker run -p 7865:7865 -v $PWD/data:/data fooocus:latest

# CUDA version (requires nvidia-container-toolkit)
nix run .#buildDockerCuda
docker run --gpus all -p 7865:7865 -v $PWD/data:/data fooocus:cuda
```

## Directory Structure

Fooocus stores persistent data in `~/.config/fooocus`:

```
~/.config/fooocus/
├── app/              # Fooocus application code
├── venv/             # Python virtual environment
├── models/           # Downloaded models
│   ├── checkpoints/  # Main model files
│   ├── loras/        # LoRA models
│   ├── embeddings/   # Text embeddings
│   ├── controlnet/   # ControlNet models
│   └── ...
└── outputs/          # Generated images
```

## GPU Support

The flake automatically detects your GPU:

- **NVIDIA**: Uses CUDA (cu124 by default, configurable via `CUDA_VERSION` env var)
- **Apple Silicon**: Uses MPS acceleration
- **CPU**: Falls back to CPU-only mode

Override CUDA version:

```bash
CUDA_VERSION=cu121 nix run .
```

Supported CUDA versions: `cu118`, `cu121`, `cu124`, `cpu`

## Development

### Enter Development Shell

```bash
nix develop
```

This provides:
- Python 3.12 environment
- Development tools (git, shellcheck, shfmt)
- Linting tools (ruff, pyright)
- Nix formatting (nixfmt-rfc-style)

### Code Quality

```bash
# Run all checks
nix flake check

# Individual checks
nix run .#lint        # Python linting
nix run .#format      # Python formatting
nix run .#type-check  # Type checking
nix run .#check-all   # All Python checks
```

### Updating Fooocus Version

Fooocus is tracked as a flake input, so updating to HEAD is simple:

```bash
nix flake update fooocus-src
```

## Troubleshooting

### Port Already in Use

If port 7865 is already in use, the launcher will offer options to:
1. Open browser to existing instance
2. Use a different port
3. Kill the process using the port

### CUDA Not Detected

If CUDA isn't detected despite having an NVIDIA GPU:

1. Ensure NVIDIA drivers are installed
2. Check that `nvidia-smi` works
3. Try setting `CUDA_VERSION` explicitly

### First Run is Slow

The first run downloads:
- Python dependencies
- PyTorch with appropriate GPU support
- Base models (automatically on first generation)

Subsequent runs use cached dependencies.

### Log Button Shows "File not allowed"

If clicking the Log button in the UI shows `{"detail":"File not allowed: .../log.html"}`, this is a Gradio security issue with symlinked paths. Fix by editing `~/.config/fooocus/app/config.txt`:

```json
"path_outputs": "/home/YOUR_USER/.config/fooocus/outputs"
```

Change from `.../app/outputs` to the real path (without the `app/` symlink), then restart Fooocus.

## License

This flake is licensed under GPL-3.0, same as Fooocus.

## Acknowledgments

- [Fooocus](https://github.com/lllyasviel/Fooocus) by lllyasviel
- Inspired by [nix-comfyui](https://github.com/utensils/nix-comfyui)
