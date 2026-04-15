#!/bin/bash
# =============================================================================
# MicroarrAI - Deployment router
# =============================================================================
# Run from the repository root. Delegates to the appropriate install script
# depending on the container runtime available on the system.
# =============================================================================

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================================================="
echo "  MicroarrAI - Deployment"
echo "============================================================================="
echo ""
echo "Select deployment method:"
echo "  1) Docker"
echo "  2) Singularity / Apptainer"
echo "  0) Exit"
echo ""
read -rp "Option: " method

case "$method" in
    1)
        exec bash "$SCRIPT_DIR/docker/docker-deploy.sh"
        ;;
    2)
        exec bash "$SCRIPT_DIR/singularity/singularity-deploy.sh"
        ;;
    0)
        echo -e "${BLUE}[INFO]${NC} Exiting."
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Invalid option."
        exit 1
        ;;
esac
