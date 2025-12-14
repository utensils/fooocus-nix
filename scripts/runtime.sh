#!/usr/bin/env bash
# runtime.sh: Runtime functions for Fooocus

# Guard against multiple sourcing
[[ -n "${_RUNTIME_SH_SOURCED:-}" ]] && return
_RUNTIME_SH_SOURCED=1

# Source shared libraries
[ -z "$SCRIPT_DIR" ] && SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "$SCRIPT_DIR/logger.sh"

# Check if port is already in use
check_port() {
    log_section "Checking port availability"

    if nc -z localhost "$FOOOCUS_PORT" 2>/dev/null; then
        log_warn "Port $FOOOCUS_PORT is in use. Fooocus may already be running."
        display_options "1. Open browser to existing Fooocus" "2. Try a different port" "3. Kill the process using port $FOOOCUS_PORT"

        echo -n "Enter choice (1-3, default=1): "
        read -r choice

        case "$choice" in
            "3")
                free_port
                ;;
            "2")
                log_info "To use a different port, restart with --port option."
                exit 0
                ;;
            *)
                log_info "Opening browser to existing Fooocus"
                open_browser "http://127.0.0.1:$FOOOCUS_PORT"
                exit 0
                ;;
        esac
    else
        log_info "Port $FOOOCUS_PORT is available"
    fi
}

# Free up the port by killing processes
free_port() {
    log_info "Attempting to free up port $FOOOCUS_PORT"

    PIDS=$(lsof -t -i:"$FOOOCUS_PORT" 2>/dev/null || netstat -anv | grep ".$FOOOCUS_PORT " | awk '{print $9}' | sort -u)
    if [ -n "$PIDS" ]; then
        for PID in $PIDS; do
            log_info "Killing process $PID"
            kill -9 "$PID" 2>/dev/null
        done

        sleep 2
        if nc -z localhost "$FOOOCUS_PORT" 2>/dev/null; then
            log_error "Failed to free up port $FOOOCUS_PORT. Try a different port."
            exit 1
        else
            log_info "Successfully freed port $FOOOCUS_PORT"
        fi
    else
        log_warn "Could not find any process using port $FOOOCUS_PORT"
    fi
}

# Display final startup information
display_startup_info() {
    display_url_info
    display_notices
}

# Build the Fooocus command arguments
build_fooocus_args() {
    local args=()

    # Add preset if specified
    if [ -n "$FOOOCUS_PRESET" ]; then
        args+=("--preset" "$FOOOCUS_PRESET")
    fi

    # Add port
    args+=("--port" "$FOOOCUS_PORT")

    # Add any additional arguments passed through (ARGS is set in config.sh)
    # shellcheck disable=SC2153
    args+=("${ARGS[@]}")

    echo "${args[@]}"
}

# Start Fooocus with browser opening if requested
start_with_browser() {
    log_section "Starting Fooocus with browser"

    # Set up a trap to kill the child process when this script receives a signal
    trap 'kill "$PID" 2>/dev/null' INT TERM

    # Start Fooocus in the background using launch.py directly (bypasses update check)
    cd "$CODE_DIR" || exit 1
    log_info "Starting Fooocus in background..."

    # Build command arguments
    local fooocus_args
    fooocus_args=$(build_fooocus_args)

    # Ensure library paths are preserved for the Python subprocess
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # shellcheck disable=SC2086
        LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" "$FOOOCUS_VENV/bin/python" "$CODE_DIR/launch.py" $fooocus_args &
    else
        # shellcheck disable=SC2086
        "$FOOOCUS_VENV/bin/python" "$CODE_DIR/launch.py" $fooocus_args &
    fi
    PID=$!

    # Wait for server to start
    log_info "Waiting for Fooocus to start..."
    until nc -z localhost "$FOOOCUS_PORT" 2>/dev/null; do
        sleep 1
        # Check if process is still running
        if ! kill -0 "$PID" 2>/dev/null; then
            log_error "Fooocus process exited unexpectedly"
            exit 1
        fi
    done

    log_info "Fooocus started! Opening browser..."
    open_browser "http://127.0.0.1:$FOOOCUS_PORT"

    # Wait for the process to finish
    while kill -0 "$PID" 2>/dev/null; do
        wait "$PID" 2>/dev/null || break
    done

    # Make sure to clean up any remaining process
    kill "$PID" 2>/dev/null || true
    log_info "Fooocus has shut down"
    exit 0
}

# Start Fooocus normally without browser opening
start_normal() {
    log_section "Starting Fooocus"

    cd "$CODE_DIR" || exit 1
    log_info "Starting Fooocus... Press Ctrl+C to exit"

    # Build command arguments
    local fooocus_args
    fooocus_args=$(build_fooocus_args)

    # Ensure library paths are preserved for the Python subprocess
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # shellcheck disable=SC2086
        LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" exec "$FOOOCUS_VENV/bin/python" "$CODE_DIR/launch.py" $fooocus_args
    else
        # shellcheck disable=SC2086
        exec "$FOOOCUS_VENV/bin/python" "$CODE_DIR/launch.py" $fooocus_args
    fi
}

# Start Fooocus with appropriate mode
start_fooocus() {
    check_port
    display_startup_info

    if [ "$OPEN_BROWSER" = true ]; then
        start_with_browser
    else
        start_normal
    fi
}
