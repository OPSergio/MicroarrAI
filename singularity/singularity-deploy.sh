#!/bin/bash
# =============================================================================
# MicroarrAI - Deployment script with Singularity/Apptainer
# =============================================================================
# Equivalent to deploy.sh but for Singularity.
# Same management options as the Docker deployment.
#
# Usage: ./singularity-deploy.sh
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

APP_NAME="microarrai"
SIF_FILE="$REPO_ROOT/MicroarrAI.sif"
DEF_FILE="$SCRIPT_DIR/MicroarrAI.def"
INSTANCE_NAME="${APP_NAME}"
PORT=3838
LOGS_DIR="$REPO_ROOT/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# -----------------------------------------------------------------------------
# UTILITY FUNCTIONS
# -----------------------------------------------------------------------------

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║          MicroarrAI - Singularity/Apptainer Deploy          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }
print_warn()    { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info()    { echo -e "${CYAN}→ $1${NC}"; }

check_singularity() {
    if command -v apptainer &>/dev/null; then
        SINGULARITY_CMD="apptainer"
    elif command -v singularity &>/dev/null; then
        SINGULARITY_CMD="singularity"
    else
        print_error "Singularity/Apptainer is not installed."
        echo ""
        echo "Install Apptainer (recommended):"
        echo "  https://apptainer.org/docs/admin/main/installation.html"
        echo ""
        echo "Install Singularity CE:"
        echo "  https://docs.sylabs.io/guides/latest/admin-guide/installation.html"
        exit 1
    fi
    print_info "Using: $SINGULARITY_CMD $(${SINGULARITY_CMD} --version 2>/dev/null | head -1)"
}

check_def_file() {
    if [ ! -f "$DEF_FILE" ]; then
        print_error "$DEF_FILE not found."
        exit 1
    fi
}

check_sif_file() {
    if [ ! -f "$SIF_FILE" ]; then
        print_error "$SIF_FILE not found. Build the image first (option 1)."
        return 1
    fi
    return 0
}

is_running() {
    ${SINGULARITY_CMD} instance list 2>/dev/null | grep -q "^${INSTANCE_NAME} " && return 0 || return 1
}

prepare_directories() {
    mkdir -p "$LOGS_DIR"
    print_info "Logs directory: $LOGS_DIR"
}

# -----------------------------------------------------------------------------
# ACTIONS
# -----------------------------------------------------------------------------

build_image() {
    echo ""
    print_info "Building Singularity image from $DEF_FILE..."
    echo ""

    check_def_file

    # Build must run from repo root so %files paths resolve correctly
    cd "$REPO_ROOT"

    # Detect if fakeroot is available
    FAKEROOT_AVAILABLE=false
    if ${SINGULARITY_CMD} build --fakeroot --help &>/dev/null 2>&1; then
        # Try with fakeroot
        if ${SINGULARITY_CMD} build --fakeroot --version &>/dev/null 2>&1; then
            FAKEROOT_AVAILABLE=true
        fi
    fi

    # Detect if we are root
    if [ "$EUID" -eq 0 ]; then
        print_info "Building as root..."
        ${SINGULARITY_CMD} build "$SIF_FILE" "$DEF_FILE"
    elif $FAKEROOT_AVAILABLE; then
        print_info "Building with --fakeroot..."
        ${SINGULARITY_CMD} build --fakeroot "$SIF_FILE" "$DEF_FILE"
    else
        print_warn "Neither root nor fakeroot available."
        print_info "Attempting build without special privileges (may fail)..."
        echo ""
        echo "If it fails, run as root or configure fakeroot:"
        echo "  sudo singularity build $SIF_FILE $DEF_FILE"
        echo "  # or add your user to /etc/subuid and /etc/subgid for fakeroot"
        echo ""
        ${SINGULARITY_CMD} build "$SIF_FILE" "$DEF_FILE"
    fi

    if [ -f "$SIF_FILE" ]; then
        SIF_SIZE=$(du -sh "$SIF_FILE" | cut -f1)
        print_success "Image built: $SIF_FILE ($SIF_SIZE)"
        echo ""
        echo "Next step: option 2 to start the application."
    else
        print_error "Build failed. Check previous messages."
        exit 1
    fi
}

start_app() {
    echo ""
    check_sif_file || return 1
    prepare_directories

    if is_running; then
        print_warn "The instance '$INSTANCE_NAME' is already running."
        echo "  URL: http://localhost:${PORT}/MicroarrAI"
        return 0
    fi

    print_info "Starting instance '$INSTANCE_NAME'..."

    # Only logs are bind-mounted: users upload their scans through the browser,
    # so no host data directory is exposed to the container.
    BIND_ARGS="--bind ${LOGS_DIR}:/var/log/shiny-server"

    ${SINGULARITY_CMD} instance start \
        $BIND_ARGS \
        "$SIF_FILE" \
        "$INSTANCE_NAME"

    # Esperar a que arranque
    echo ""
    print_info "Waiting for Shiny Server to start..."
    RETRIES=0
    MAX_RETRIES=12
    while [ $RETRIES -lt $MAX_RETRIES ]; do
        sleep 5
        if curl -sf "http://localhost:${PORT}/MicroarrAI" &>/dev/null; then
            break
        fi
        RETRIES=$((RETRIES + 1))
        echo -n "."
    done
    echo ""

    if is_running; then
        print_success "Application started successfully."
        echo ""
        echo "  Local access:  http://localhost:${PORT}/MicroarrAI"
        echo "  Remote access: http://$(hostname -I | awk '{print $1}'):${PORT}/MicroarrAI"
        echo ""
        print_info "Logs: tail -f ${LOGS_DIR}/*.log"
    else
        print_error "Instance failed to start correctly."
        echo "Check the logs: tail -f ${LOGS_DIR}/*.log"
        exit 1
    fi
}

stop_app() {
    echo ""
    if ! is_running; then
        print_warn "No instance '$INSTANCE_NAME' is running."
        return 0
    fi

    print_info "Stopping instance '$INSTANCE_NAME'..."
    ${SINGULARITY_CMD} instance stop "$INSTANCE_NAME"
    print_success "Instance stopped."
}

show_logs() {
    echo ""
    if [ ! -d "$LOGS_DIR" ] || [ -z "$(ls -A "$LOGS_DIR" 2>/dev/null)" ]; then
        print_warn "No log files found in $LOGS_DIR"
        print_info "Start the application first (option 2) with logs mounted."
        return 0
    fi

    print_info "Streaming logs (Ctrl+C to exit)..."
    echo ""
    tail -f "${LOGS_DIR}"/*.log
}

rebuild_app() {
    echo ""
    print_warn "This will rebuild the image from scratch (no cache). May take 15-30 minutes."
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Cancelled."
        return 0
    fi

    stop_app

    if [ -f "$SIF_FILE" ]; then
        print_info "Removing previous image: $SIF_FILE"
        rm -f "$SIF_FILE"
    fi

    build_image
    start_app
}

show_status() {
    echo ""
    print_info "Singularity instances:"
    echo ""
    ${SINGULARITY_CMD} instance list 2>/dev/null || echo "(no active instances)"

    echo ""
    if is_running; then
        print_success "Instance '$INSTANCE_NAME': RUNNING"
        echo ""
        print_info "Checking application health..."
        if curl -sf "http://localhost:${PORT}/MicroarrAI" &>/dev/null; then
            print_success "Shiny Server responding at http://localhost:${PORT}/MicroarrAI"
        else
            print_warn "Shiny Server not responding yet (may still be starting)"
        fi
    else
        print_warn "Instance '$INSTANCE_NAME': STOPPED"
    fi

    if [ -f "$SIF_FILE" ]; then
        echo ""
        SIF_SIZE=$(du -sh "$SIF_FILE" | cut -f1)
        print_info "Image: $SIF_FILE ($SIF_SIZE)"
    fi

    if [ -d "$LOGS_DIR" ]; then
        echo ""
        print_info "Log files:"
        ls -lh "${LOGS_DIR}"/*.log 2>/dev/null | awk '{print "  " $0}' || echo "  (no logs yet)"
    fi
}

open_shell() {
    echo ""
    check_sif_file || return 1
    prepare_directories

    BIND_ARGS="--bind ${LOGS_DIR}:/var/log/shiny-server"

    print_info "Opening interactive shell inside the container..."
    print_info "(type 'exit' to leave)"
    echo ""
    ${SINGULARITY_CMD} shell $BIND_ARGS "$SIF_FILE"
}

cleanup() {
    echo ""
    print_warn "This will stop the instance and remove the image $SIF_FILE."
    read -r -p "Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Cancelled."
        return 0
    fi

    stop_app

    if [ -f "$SIF_FILE" ]; then
        rm -f "$SIF_FILE"
        print_success "Image removed: $SIF_FILE"
    fi

    if [ -d "$LOGS_DIR" ]; then
        read -r -p "Also remove the logs directory ($LOGS_DIR)? [y/N] " confirm_logs
        if [[ "$confirm_logs" =~ ^[yY]$ ]]; then
            rm -rf "$LOGS_DIR"
            print_success "Logs removed."
        fi
    fi

    print_success "Cleanup complete."
}

run_tests() {
    echo ""
    check_sif_file || return 1
    print_info "Running container verification tests..."
    echo ""
    ${SINGULARITY_CMD} test "$SIF_FILE"
}

# -----------------------------------------------------------------------------
# MAIN MENU
# -----------------------------------------------------------------------------

show_menu() {
    echo ""
    echo "  ┌─────────────────────────────────────────────────┐"
    echo "  │  What do you want to do?                        │"
    echo "  ├─────────────────────────────────────────────────┤"
    echo "  │  1) Build image (.sif)                          │"
    echo "  │  2) Start application                           │"
    echo "  │  3) Stop application                            │"
    echo "  │  4) Stream logs                                 │"
    echo "  │  5) Rebuild and start (no cache)                │"
    echo "  │  6) Show instance status                        │"
    echo "  │  7) Open interactive shell                      │"
    echo "  │  8) Run verification tests                      │"
    echo "  │  9) Clean up (stop and remove image)            │"
    echo "  │  0) Exit                                        │"
    echo "  └─────────────────────────────────────────────────┘"
    echo ""
}

main() {
    print_header
    check_singularity
    echo ""

    while true; do
        show_menu
        read -r -p "  Option [0-9]: " choice
        case $choice in
            1) build_image ;;
            2) start_app ;;
            3) stop_app ;;
            4) show_logs ;;
            5) rebuild_app ;;
            6) show_status ;;
            7) open_shell ;;
            8) run_tests ;;
            9) cleanup ;;
            0) echo ""; print_info "Exiting."; echo ""; exit 0 ;;
            *) print_warn "Invalid option. Choose between 0 and 9." ;;
        esac
    done
}

# Allow direct function calls: ./singularity-deploy.sh start
if [ $# -gt 0 ]; then
    check_singularity
    case "$1" in
        build)   build_image ;;
        start)   start_app ;;
        stop)    stop_app ;;
        logs)    show_logs ;;
        rebuild) rebuild_app ;;
        status)  show_status ;;
        shell)   open_shell ;;
        test)    run_tests ;;
        clean)   cleanup ;;
        *)
            echo "Usage: $0 [build|start|stop|logs|rebuild|status|shell|test|clean]"
            echo "       $0           (interactive menu)"
            exit 1
            ;;
    esac
else
    main
fi
