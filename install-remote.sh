#!/usr/bin/env bash
# Remote installer for lps-statusline
# Usage: curl -sSL https://raw.githubusercontent.com/lpsgverrilla/lps-statusline/main/install-remote.sh | bash
#    or: wget -qO- https://raw.githubusercontent.com/lpsgverrilla/lps-statusline/main/install-remote.sh | bash

set -e

REPO_URL="https://github.com/lpsgverrilla/lps-statusline.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info() { echo -e "${CYAN}==>${RESET} $1"; }
success() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}==>${RESET} $1"; }
error() { echo -e "${RED}==>${RESET} $1" >&2; exit 1; }

# Check dependencies
check_deps() {
    local missing=()

    command -v git &>/dev/null || missing+=("git")
    command -v bash &>/dev/null || missing+=("bash")
    command -v jq &>/dev/null || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}\nPlease install them and try again."
    fi
}

# Check bash version and find suitable bash
check_bash_version() {
    local version="${BASH_VERSION%%.*}"

    # If current shell is bash 4+, we're good
    if [[ "$version" -ge 4 ]]; then
        return 0
    fi

    # On macOS, check for Homebrew bash
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -x "/opt/homebrew/bin/bash" ]]; then
            warn "Current bash is v$BASH_VERSION, but Homebrew bash 4+ found"
            warn "The installer will use /opt/homebrew/bin/bash"
            return 0
        elif [[ -x "/usr/local/bin/bash" ]]; then
            warn "Current bash is v$BASH_VERSION, but Homebrew bash 4+ found"
            warn "The installer will use /usr/local/bin/bash"
            return 0
        fi
        error "Bash 4.0+ required. You have: $BASH_VERSION\nInstall with: brew install bash"
    fi

    error "Bash 4.0+ required. You have: $BASH_VERSION"
}

main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}     lps-statusline remote installer    ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}"
    echo ""

    info "Checking dependencies..."
    check_deps
    check_bash_version
    success "All dependencies found"

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cleanup() { rm -rf "$TEMP_DIR"; }
    trap cleanup EXIT

    info "Cloning repository..."
    if ! git clone --depth 1 --quiet "$REPO_URL" "$TEMP_DIR"; then
        error "Failed to clone repository. Check your internet connection."
    fi
    success "Repository cloned"

    info "Running installer..."
    cd "$TEMP_DIR"

    # Make installer executable and run it
    chmod +x install.sh
    ./install.sh

    echo ""
    success "Installation complete!"
    echo ""
    echo -e "  ${YELLOW}Next steps:${RESET}"
    echo "  1. Add the statusLine config to ~/.claude/settings.json (see above)"
    echo "  2. Restart Claude Code"
    echo ""
    echo -e "  ${CYAN}Documentation:${RESET} https://github.com/lpsgverrilla/lps-statusline"
    echo ""
}

main "$@"
