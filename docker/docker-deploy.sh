#!/bin/bash
# =============================================================================
# MicroarrAI - Docker deployment menu
# =============================================================================
# Must be called from the repository root (done automatically by deploy.sh).
# =============================================================================

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
# docker compose resolves the ../data and ../logs mounts relative to the compose
# file, not to the caller's cwd, so create them at the repo root explicitly.
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

echo "============================================================================="
echo "  MicroarrAI - Docker Deployment"
echo "============================================================================="
echo ""

if ! command -v docker &>/dev/null; then
    print_error "Docker is not installed."
    echo "  See: docker/get-docker.sh  or  https://docs.docker.com/engine/install/"
    exit 1
fi
print_success "Docker found"

if ! docker info &>/dev/null; then
    print_error "Docker daemon is not running."
    echo "  sudo systemctl start docker"
    exit 1
fi
print_success "Docker daemon is running"

if command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose -f $COMPOSE_FILE"
else
    COMPOSE_CMD="docker compose -f $COMPOSE_FILE"
fi

# Bind-mount target for the logs volume in docker-compose.yml.
mkdir -p "$REPO_ROOT/logs"

echo ""
echo "Select an option:"
echo "  1) Build and start (first time)"
echo "  2) Start existing container"
echo "  3) Stop"
echo "  4) View logs"
echo "  5) Rebuild and restart"
echo "  6) Container status"
echo "  7) Clean up (remove container and image)"
echo "  0) Exit"
echo ""
read -rp "Option: " option

case $option in
    1)
        print_info "Building Docker image (this may take 15-30 min on first run)..."
        $COMPOSE_CMD build
        print_success "Image built"
        print_info "Starting container..."
        $COMPOSE_CMD up -d
        print_success "Container started"
        echo ""
        print_info "Application available at: http://localhost:3838/MicroarrAI"
        print_info "Logs: $COMPOSE_CMD logs -f"
        ;;
    2)
        $COMPOSE_CMD up -d
        print_success "Application started at http://localhost:3838/MicroarrAI"
        ;;
    3)
        $COMPOSE_CMD down
        print_success "Application stopped"
        ;;
    4)
        print_info "Streaming logs (Ctrl+C to exit)..."
        $COMPOSE_CMD logs -f
        ;;
    5)
        $COMPOSE_CMD down
        $COMPOSE_CMD build --no-cache
        $COMPOSE_CMD up -d
        print_success "Application rebuilt and restarted"
        ;;
    6)
        $COMPOSE_CMD ps
        echo ""
        docker stats --no-stream microarrai-app 2>/dev/null || print_warning "Container is not running"
        ;;
    7)
        print_warning "This will remove the container and image."
        read -rp "Continue? (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            $COMPOSE_CMD down
            docker rmi microarrai:latest 2>/dev/null || print_warning "Image not found"
            print_success "Cleanup complete"
        else
            print_info "Cancelled"
        fi
        ;;
    0)
        print_info "Exiting."
        exit 0
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_success "Done"
