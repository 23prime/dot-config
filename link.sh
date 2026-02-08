#!/bin/zsh
set -euo pipefail

# ========================================
# Zellij Config Symlink Manager
# ========================================

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${HOME}/.config/zellij"
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-true}"

# Files and directories to exclude from linking
EXCLUDE_LIST=(
    ".git"
    ".gitignore"
    "README.md"
    "link.sh"
    "LICENSE"
)

# Colors for output
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    GREEN=''
    RED=''
    BLUE=''
    NC=''
fi

# ========================================
# Functions
# ========================================

log_info() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

create_symlink() {
    local source="$1"
    local target="$2"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "Would link: $target -> $source"
        return 0
    fi

    # Create parent directory if it doesn't exist
    local target_dir
    target_dir=$(dirname "$target")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_info "Created directory: $target_dir"
    fi

    # Create symlink
    if ln -snf "$source" "$target"; then
        log_success "Linked: $target -> $source"
        return 0
    else
        log_error "Failed to link: $source -> $target"
        return 1
    fi
}

link_configs() {
    log_info "Linking zellij configs from $SCRIPT_DIR to $TARGET_DIR"

    local count=0
    local failed=0

    # Build find's -prune arguments for excluded directories
    local prune_args=()
    for exclude in "${EXCLUDE_LIST[@]}"; do
        prune_args+=(-name "$exclude" -prune -o)
    done

    # Find all files recursively, skipping excluded directories/files
    while IFS= read -r -d '' file; do
        local rel_path="${file#"$SCRIPT_DIR"/}"
        local target="${TARGET_DIR}/${rel_path}"

        if create_symlink "$file" "$target"; then
            ((count++))
        else
            ((failed++))
        fi
    done < <(find "$SCRIPT_DIR" "${prune_args[@]}" -type f -print0)

    # Summary
    echo ""
    echo "========================================"
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo -e "${BLUE}DRY RUN MODE - No changes made${NC}"
    fi
    echo "Total processed: $((count + failed))"
    echo "  - Linked: $count"
    echo "  - Failed: $failed"
    echo "========================================"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Link zellij config files from this repository to ~/.config/zellij/.

OPTIONS:
    -d, --dry-run       Show what would be done without making changes
    -q, --quiet         Suppress verbose output
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    DRY_RUN            Set to 'true' for dry-run mode (default: false)
    VERBOSE            Set to 'false' for quiet mode (default: true)

EXAMPLES:
    # Normal run
    $0

    # Dry run to see what would be linked
    $0 --dry-run

EOF
}

# ========================================
# Main
# ========================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -q|--quiet)
                VERBOSE="false"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Run linking
    if link_configs; then
        log_success "Zellij config linking completed successfully!"
        exit 0
    else
        log_error "Zellij config linking completed with errors"
        exit 1
    fi
}

main "$@"
