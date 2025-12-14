#!/usr/bin/env bash
# config.sh: Configuration variables for Fooocus launcher

# Guard against multiple sourcing
[[ -n "${_CONFIG_SH_SOURCED:-}" ]] && return
_CONFIG_SH_SOURCED=1

# Enable strict mode but with verbose error reporting
set -uo pipefail

# Function to print variable values for debugging
debug_vars() {
  # Only show debug variables when in debug mode
  if [[ $LOG_LEVEL -le $DEBUG ]]; then
    echo "DEBUG VARIABLES:"
    echo "FOOOCUS_VERSION=$FOOOCUS_VERSION"
    echo "BASE_DIR=$BASE_DIR"
    echo "CODE_DIR=$CODE_DIR"
    echo "FOOOCUS_SRC=$FOOOCUS_SRC"
    echo "DIRECTORIES defined: ${!DIRECTORIES[*]:-NONE}"
  fi
}

# Add trap for debugging
trap 'echo "ERROR in config.sh: Command failed with exit code $? at line $LINENO"' ERR

# Version and port configuration
FOOOCUS_VERSION="2.5.5"
FOOOCUS_PORT="7865"

# CUDA configuration (can be overridden via environment)
# Supported versions: cu118, cu121, cu124, cpu
CUDA_VERSION="${CUDA_VERSION:-cu124}"

# Directory structure
BASE_DIR="$HOME/.config/fooocus"
CODE_DIR="$BASE_DIR/app"
FOOOCUS_VENV="$BASE_DIR/venv"

# Environment variables
ENV_VARS=(
  "PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0"
  "FOOOCUS_USER_DIR=$BASE_DIR"
  "GRADIO_SERVER_PORT=$FOOOCUS_PORT"
)

# Flag for browser opening
OPEN_BROWSER=false

# Preset configuration (default, anime, realistic)
FOOOCUS_PRESET=""

# Python paths (to be substituted by Nix)
PYTHON_ENV="@pythonEnv@/bin/python"

# Source paths (to be substituted by Nix)
FOOOCUS_SRC="@fooocusSrc@"

# Directory lists for creation
declare -A DIRECTORIES=(
  [base]="$BASE_DIR $CODE_DIR"
  [main]="$BASE_DIR/outputs"
  [models]="$BASE_DIR/models/checkpoints $BASE_DIR/models/loras
           $BASE_DIR/models/embeddings $BASE_DIR/models/controlnet
           $BASE_DIR/models/clip_vision $BASE_DIR/models/upscale_models
           $BASE_DIR/models/inpaint $BASE_DIR/models/safety_checker
           $BASE_DIR/models/prompt_expansion $BASE_DIR/models/vae"
)

# Python packages to install (as arrays for proper handling)
BASE_PACKAGES=(pip setuptools wheel)

# PyTorch installation will be determined dynamically based on GPU availability
# This is set in install.sh based on platform detection

# Function to parse command line arguments
parse_arguments() {
  ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --open)
        OPEN_BROWSER=true
        ;;
      --port=*)
        FOOOCUS_PORT="${arg#*=}"
        ;;
      --preset=*)
        FOOOCUS_PRESET="${arg#*=}"
        ;;
      --debug)
        export LOG_LEVEL=$DEBUG
        ;;
      --verbose)
        export LOG_LEVEL=$DEBUG
        ;;
      *)
        ARGS+=("$arg")
        ;;
    esac
  done
}

# Export the configuration
export_config() {
  # Export all defined variables to make them available to sourced scripts
  export FOOOCUS_VERSION FOOOCUS_PORT BASE_DIR CODE_DIR FOOOCUS_VENV
  export OPEN_BROWSER PYTHON_ENV
  export FOOOCUS_SRC FOOOCUS_PRESET

  # Export environment variables (eval is needed to properly export var=value pairs)
  for var in "${ENV_VARS[@]}"; do
    eval export "$var"
  done

  # Add CODE_DIR to PYTHONPATH
  export PYTHONPATH="$CODE_DIR:${PYTHONPATH:-}"
}
