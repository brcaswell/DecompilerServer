#!/bin/bash

# DecompilerServer Container File Watcher Orchestrator
# Monitors assembly files and restarts container when changes are detected

set -euo pipefail

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-decompiler-server}"
IMAGE_NAME="${IMAGE_NAME:-decompiler-server:latest}"
ASSEMBLIES_PATH="${ASSEMBLIES_PATH:-}"
ASSEMBLY_FILE="${ASSEMBLY_FILE:-Assembly-CSharp.dll}"
VERBOSE="${VERBOSE:-false}"
WATCH_INTERVAL="${WATCH_INTERVAL:-2}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

usage() {
    cat << EOF
DecompilerServer Container File Watcher

Usage: $0 [OPTIONS]

Options:
    -p, --path PATH         Path to assemblies directory (required)
    -f, --file FILE         Assembly filename (default: Assembly-CSharp.dll)
    -n, --name NAME         Container name (default: decompiler-server)
    -i, --image IMAGE       Container image (default: decompiler-server:latest)
    -v, --verbose           Enable verbose logging
    -w, --watch-interval N  Watch interval in seconds (default: 2)
    -h, --help              Show this help

Examples:
    $0 -p /path/to/game/Managed -f Assembly-CSharp.dll
    $0 --path ./assemblies --verbose
    $0 -p /games/unity/Managed -w 1 -v

Environment Variables:
    ASSEMBLIES_PATH     Same as --path
    ASSEMBLY_FILE       Same as --file
    CONTAINER_NAME      Same as --name
    IMAGE_NAME          Same as --image
    VERBOSE             Same as --verbose
    WATCH_INTERVAL      Same as --watch-interval
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--path)
                ASSEMBLIES_PATH="$2"
                shift 2
                ;;
            -f|--file)
                ASSEMBLY_FILE="$2"
                shift 2
                ;;
            -n|--name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            -i|--image)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -w|--watch-interval)
                WATCH_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

validate_config() {
    if [[ -z "$ASSEMBLIES_PATH" ]]; then
        error "Assemblies path is required. Use -p/--path or set ASSEMBLIES_PATH"
        exit 1
    fi

    if [[ ! -d "$ASSEMBLIES_PATH" ]]; then
        error "Assemblies directory does not exist: $ASSEMBLIES_PATH"
        exit 1
    fi

    local assembly_full_path="$ASSEMBLIES_PATH/$ASSEMBLY_FILE"
    if [[ ! -f "$assembly_full_path" ]]; then
        error "Assembly file not found: $assembly_full_path"
        exit 1
    fi

    # Check if Docker/Podman is available
    if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
        error "Neither Docker nor Podman found. Please install one of them."
        exit 1
    fi

    # Prefer podman if available, fallback to docker
    if command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
    else
        CONTAINER_RUNTIME="docker"
    fi
}

compute_file_hash() {
    local file_path="$1"
    if command -v sha256sum &> /dev/null; then
        sha256sum "$file_path" | cut -d' ' -f1
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        # Fallback to stat (less reliable)
        stat -f "%m %z" "$file_path" 2>/dev/null || stat -c "%Y %s" "$file_path"
    fi
}

start_container() {
    log "Starting DecompilerServer container..."
    
    local verbose_args=()
    if [[ "$VERBOSE" == "true" ]]; then
        verbose_args=("-e" "DECOMPILER_VERBOSE=true")
    fi

    $CONTAINER_RUNTIME run \
        --name "$CONTAINER_NAME" \
        --rm \
        -i \
        -v "$ASSEMBLIES_PATH:/app/assemblies:ro" \
        -e "ASSEMBLY_PATH=/app/assemblies/$ASSEMBLY_FILE" \
        "${verbose_args[@]}" \
        "$IMAGE_NAME" &
    
    CONTAINER_PID=$!
    success "Container started (PID: $CONTAINER_PID)"
}

stop_container() {
    if [[ -n "${CONTAINER_PID:-}" ]]; then
        log "Stopping container..."
        $CONTAINER_RUNTIME stop "$CONTAINER_NAME" 2>/dev/null || true
        wait $CONTAINER_PID 2>/dev/null || true
        CONTAINER_PID=""
    fi
}

cleanup() {
    log "Cleaning up..."
    stop_container
    exit 0
}

main() {
    parse_args "$@"
    validate_config

    log "DecompilerServer Container File Watcher"
    log "Runtime: $CONTAINER_RUNTIME"
    log "Image: $IMAGE_NAME"
    log "Assemblies: $ASSEMBLIES_PATH"
    log "Assembly File: $ASSEMBLY_FILE"
    log "Watch Interval: ${WATCH_INTERVAL}s"
    
    # Set up signal handlers
    trap cleanup SIGTERM SIGINT

    local assembly_full_path="$ASSEMBLIES_PATH/$ASSEMBLY_FILE"
    local last_hash=""
    
    # Start initial container
    start_container
    last_hash=$(compute_file_hash "$assembly_full_path")
    
    log "Initial hash: ${last_hash:0:8}... (watching for changes)"

    # Watch loop
    while true; do
        sleep "$WATCH_INTERVAL"
        
        if [[ ! -f "$assembly_full_path" ]]; then
            warn "Assembly file no longer exists: $assembly_full_path"
            continue
        fi

        local current_hash
        current_hash=$(compute_file_hash "$assembly_full_path")
        
        if [[ "$current_hash" != "$last_hash" ]]; then
            success "Assembly changed! Hash: ${current_hash:0:8}..."
            
            # Stop current container
            stop_container
            
            # Wait a moment for file operations to complete
            sleep 1
            
            # Start new container
            start_container
            last_hash="$current_hash"
            
            success "Container restarted with fresh assembly"
        elif [[ "$VERBOSE" == "true" ]]; then
            log "No changes detected (${current_hash:0:8}...)"
        fi
    done
}

main "$@"