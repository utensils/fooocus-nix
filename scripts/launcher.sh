#!/usr/bin/env bash
# Main launcher for Fooocus - entry point that sources modular components

# Enable strict mode but with error trapping
set -uo pipefail

# Add error trap for debugging
trap 'echo "ERROR: Command failed with exit code $? at line $LINENO in $BASH_SOURCE"' ERR

# Get the directory where this script is located
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# When running in production from Nix store, scripts will be in share directory
if [[ "$SCRIPT_DIR" == *"/bin" ]]; then
  SHARE_DIR="$(dirname "$SCRIPT_DIR")/share/fooocus/scripts"
  if [[ -d "$SHARE_DIR" ]]; then
    SCRIPT_DIR="$SHARE_DIR"
  fi
fi

# Source the component scripts
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/logger.sh"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/persistence.sh"
source "$SCRIPT_DIR/runtime.sh"

# Platform-specific library path handling
# Note: @libPath@ is substituted by Nix at build time (may be empty on macOS)
LIB_PATH="@libPath@"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux: Set LD_LIBRARY_PATH for libstdc++ and other required libraries
    if [[ -n "$LIB_PATH" ]]; then
        export LD_LIBRARY_PATH="$LIB_PATH:${LD_LIBRARY_PATH:-}"
    fi
    # Add NVIDIA/CUDA libraries if available
    if [ -d "/run/opengl-driver/lib" ]; then
        export LD_LIBRARY_PATH="/run/opengl-driver/lib:${LD_LIBRARY_PATH:-}"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Libraries handled by system, DYLD_LIBRARY_PATH usually not needed
    if [[ -n "$LIB_PATH" ]]; then
        export DYLD_LIBRARY_PATH="$LIB_PATH:${DYLD_LIBRARY_PATH:-}"
    fi
fi

# Main function
main() {
    # Parse command-line arguments
    parse_arguments "$@"

    # Export configuration
    export_config

    # Welcome message
    log_section "Fooocus Launcher"
    log_info "Starting Fooocus launcher for version $FOOOCUS_VERSION"
    if [ -n "$FOOOCUS_PRESET" ]; then
        log_info "Using preset: $FOOOCUS_PRESET"
    fi

    # Call debug function from config.sh
    debug_vars

    # Debug info (only shown in debug mode)
    log_debug "SCRIPT_DIR: $SCRIPT_DIR"
    log_debug "BASE_DIR: $BASE_DIR"
    log_debug "PYTHONPATH: $PYTHONPATH"
    log_debug "FOOOCUS_SRC: $FOOOCUS_SRC"

    # Installation steps (includes persistence setup)
    install_all

    # Start Fooocus
    start_fooocus
}

# Run the main function
main "$@"
