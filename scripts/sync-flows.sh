#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# NiFi Registry Flows Sync Script
# =============================================================================
# Sincroniza flows do NiFi Registry (container) com o repositório principal
#
# Usage: ./scripts/sync-flows.sh [--dry-run]
# =============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="nifi-registry"
CONTAINER_FLOW_PATH="//opt//nifi-registry//flow-storage"
LOCAL_FLOW_PATH="flows"
DRY_RUN=false

# Parse arguments
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}DRY RUN MODE - No changes will be made${NC}"
    echo ""
fi

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Validation
# =============================================================================

log_info "Validating environment..."

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_error "Container '${CONTAINER_NAME}' is not running"
    log_info "Start it with: docker compose -f docker/docker-compose.yml up -d nifi-registry"
    exit 1
fi

log_success "Container is running"

# Check if container has flows
if ! docker exec "${CONTAINER_NAME}" test -d "${CONTAINER_FLOW_PATH}"; then
    log_error "Flow directory not found in container: ${CONTAINER_FLOW_PATH}"
    exit 1
fi

log_success "Flow directory found in container"

# =============================================================================
# Sync Flows
# =============================================================================

log_info "Syncing flows from container to local repository..."

# Create local flows directory if it doesn't exist
if [[ ! -d "${LOCAL_FLOW_PATH}" ]]; then
    if [[ "${DRY_RUN}" == false ]]; then
        mkdir -p "${LOCAL_FLOW_PATH}"
        log_success "Created local flows directory: ${LOCAL_FLOW_PATH}/"
    else
        log_info "[DRY RUN] Would create: ${LOCAL_FLOW_PATH}/"
    fi
fi

# Copy flows from container
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

log_info "Copying flows from container to temporary directory..."
docker cp "${CONTAINER_NAME}:${CONTAINER_FLOW_PATH}/." "${TEMP_DIR}/"

# Remove .git directory from temp (we don't want to copy that)
rm -rf "${TEMP_DIR}/.git"

# Count snapshots
SNAPSHOT_COUNT=$(find "${TEMP_DIR}" -name "*.snapshot" -type f | wc -l)
log_info "Found ${SNAPSHOT_COUNT} flow snapshots"

if [[ "${SNAPSHOT_COUNT}" -eq 0 ]]; then
    log_warning "No flow snapshots found. Have you versioned any flows yet?"
    log_info "See docs/NIFI_REGISTRY_SETUP.md for instructions"
    exit 0
fi

# Sync files
if [[ "${DRY_RUN}" == false ]]; then
    # Rsync to preserve structure and only update changed files
    cp -r "${TEMP_DIR}"/* "${LOCAL_FLOW_PATH}/"
    log_success "Flows synced to ${LOCAL_FLOW_PATH}/"
else
    log_info "[DRY RUN] Would sync ${SNAPSHOT_COUNT} snapshots to ${LOCAL_FLOW_PATH}/"
    log_info "[DRY RUN] Files that would be synced:"
    find "${TEMP_DIR}" -name "*.snapshot" -type f | sed "s|${TEMP_DIR}|${LOCAL_FLOW_PATH}|" | head -10
    if [[ "${SNAPSHOT_COUNT}" -gt 10 ]]; then
        log_info "[DRY RUN] ... and $((SNAPSHOT_COUNT - 10)) more files"
    fi
fi

# =============================================================================
# Git Status
# =============================================================================

log_info "Checking git status..."

if [[ "${DRY_RUN}" == false ]]; then
    # Check if there are changes
    if git diff --quiet "${LOCAL_FLOW_PATH}" && git diff --cached --quiet "${LOCAL_FLOW_PATH}"; then
        log_success "No changes detected - flows are up to date!"
    else
        log_warning "Changes detected in flows/"
        echo ""
        git status "${LOCAL_FLOW_PATH}"
        echo ""
        log_info "Review changes with: git diff ${LOCAL_FLOW_PATH}"
        log_info "Stage changes with: git add ${LOCAL_FLOW_PATH}"
        log_info "Commit with: git commit -m 'feat: update NiFi flows'"
    fi
else
    log_info "[DRY RUN] Would check git status for changes"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Sync Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Container:    ${CONTAINER_NAME}:${CONTAINER_FLOW_PATH}"
echo "  Local:        ${LOCAL_FLOW_PATH}/"
echo "  Snapshots:    ${SNAPSHOT_COUNT}"
echo ""

if [[ "${DRY_RUN}" == false ]]; then
    log_success "Sync completed successfully!"
    echo ""
    log_info "Next steps:"
    echo "  1. Review changes: git status"
    echo "  2. View diffs: git diff ${LOCAL_FLOW_PATH}"
    echo "  3. Commit: git add ${LOCAL_FLOW_PATH} && git commit -m 'feat: update NiFi flows'"
else
    log_info "This was a dry run - no changes were made"
    log_info "Run without --dry-run to sync flows"
fi

echo ""
