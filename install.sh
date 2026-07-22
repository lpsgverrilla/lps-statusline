#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# LPS-STATUSLINE Installer
# ═══════════════════════════════════════════════════════════════════════════════
# Installs the custom Claude Code statusline with usage quota tracking
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default installation directory
DEFAULT_INSTALL_DIR="$HOME/.local/share/lps-statusline"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           LPS-STATUSLINE Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# Get script directory (where the repo was cloned)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────────────────────────────────────
# Check Dependencies
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Checking dependencies...${NC}"

missing_deps=()

if ! command -v jq &>/dev/null; then
    missing_deps+=("jq")
fi

if ! command -v git &>/dev/null; then
    missing_deps+=("git")
fi

# Check for missing dependencies first (report all at once)
if [ ${#missing_deps[@]} -gt 0 ]; then
    echo -e "${RED}Missing required dependencies: ${missing_deps[*]}${NC}"
    echo "Please install them first:"
    echo "  Arch Linux: sudo pacman -S ${missing_deps[*]}"
    echo "  Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
    echo "  macOS: brew install ${missing_deps[*]}"
    exit 1
fi

# Check bash version and find correct bash path
# macOS ships with bash 3.2, so we need Homebrew bash
BASH_CMD="bash"  # Default for Linux

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: find Homebrew bash
    if [ -x "/opt/homebrew/bin/bash" ]; then
        # Apple Silicon
        BASH_CMD="/opt/homebrew/bin/bash"
    elif [ -x "/usr/local/bin/bash" ]; then
        # Intel Mac
        BASH_CMD="/usr/local/bin/bash"
    else
        echo -e "${RED}Error: Homebrew bash not found${NC}"
        echo "  macOS requires bash 4.0+ from Homebrew."
        echo "  Install with: brew install bash"
        exit 1
    fi
    bash_version=$("$BASH_CMD" --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
else
    bash_version=$(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
fi

# Validate version was extracted and is sufficient
bash_major=$(echo "$bash_version" | cut -d. -f1)
if [ -z "$bash_major" ] || [ "$bash_major" -lt 4 ]; then
    echo -e "${RED}Error: bash 4.0+ required (found ${bash_version:-unknown})${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  Install with: brew install bash"
    else
        echo "  Check your distribution's package manager to upgrade bash."
    fi
    exit 1
fi

echo -e "${GREEN}✓ All dependencies found${NC}"
echo -e "  bash $bash_version ${CYAN}($BASH_CMD)${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Check for Existing Statusline
# ─────────────────────────────────────────────────────────────────────────────
echo
if [ -f "$CLAUDE_SETTINGS" ]; then
    existing_statusline=$(jq -r '.statusLine.command // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
    if [ -n "$existing_statusline" ]; then
        echo -e "${YELLOW}⚠️  Warning: You already have a custom statusline configured:${NC}"
        echo -e "   ${CYAN}$existing_statusline${NC}"
        echo
        echo -e "${YELLOW}A backup will be created before making changes.${NC}"
        echo
        read -rp "Continue with installation? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Choose Installation Directory
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "Where should lps-statusline be installed?"
echo -e "  Default: ${BLUE}$DEFAULT_INSTALL_DIR${NC}"
read -rp "Press Enter for default, or type a custom path: " INSTALL_DIR

if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
fi

# Expand ~ if used
INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

echo
echo -e "Installing to: ${BLUE}$INSTALL_DIR${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Choose Subagent Model
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "Which model should the statusline-specialist agent use?"
echo -e "  ${CYAN}1)${NC} sonnet ${GREEN}(recommended)${NC} — Faster, good for most tasks"
echo -e "  ${CYAN}2)${NC} opus — More thorough, better for complex debugging"
echo
read -rp "Choose [1/2, default=1]: " model_choice

case "$model_choice" in
    2|opus)
        AGENT_MODEL="opus"
        ;;
    *)
        AGENT_MODEL="sonnet"
        ;;
esac

echo -e "Using model: ${CYAN}$AGENT_MODEL${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Copy Files
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${YELLOW}Copying files...${NC}"

mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/statusline.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"

# Copy and configure agent
mkdir -p "$INSTALL_DIR/.claude/agents"
if [ -f "$SCRIPT_DIR/.claude/agents/statusline-specialist.md" ]; then
    sed "s/^model: sonnet$/model: $AGENT_MODEL/" \
        "$SCRIPT_DIR/.claude/agents/statusline-specialist.md" \
        > "$INSTALL_DIR/.claude/agents/statusline-specialist.md"
fi

# Make scripts executable
chmod +x "$INSTALL_DIR/statusline.sh"
chmod +x "$INSTALL_DIR/uninstall.sh"

echo -e "${GREEN}✓ Files copied${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Configure Claude Code
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${YELLOW}Configuring Claude Code...${NC}"

configure_claude() {
    mkdir -p "$HOME/.claude"

    if [ -f "$CLAUDE_SETTINGS" ]; then
        # Backup existing settings
        backup_file="$CLAUDE_SETTINGS.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CLAUDE_SETTINGS" "$backup_file"
        echo -e "${GREEN}✓ Backed up settings to: ${CYAN}$backup_file${NC}"

        # Update statusLine in existing settings
        tmp_file=$(mktemp)
        jq --arg cmd "$BASH_CMD $INSTALL_DIR/statusline.sh" \
           '.statusLine = {"type": "command", "command": $cmd, "padding": 0}' \
           "$CLAUDE_SETTINGS" > "$tmp_file" && mv "$tmp_file" "$CLAUDE_SETTINGS"
    else
        # Create new settings file using jq to properly escape the path
        jq -n --arg cmd "$BASH_CMD $INSTALL_DIR/statusline.sh" \
           '{"statusLine": {"type": "command", "command": $cmd, "padding": 0}}' \
           > "$CLAUDE_SETTINGS"
    fi
    echo -e "${GREEN}✓ Claude Code configured${NC}"
}

read -rp "Configure Claude Code settings.json automatically? [Y/n] " configure_choice
if [[ ! "$configure_choice" =~ ^[Nn]$ ]]; then
    configure_claude
else
    echo -e "${YELLOW}Skipped. Add this to ~/.claude/settings.json manually:${NC}"
    echo
    echo -e "  ${CYAN}\"statusLine\": {${NC}"
    echo -e "  ${CYAN}  \"type\": \"command\",${NC}"
    echo -e "  ${CYAN}  \"command\": \"$BASH_CMD $INSTALL_DIR/statusline.sh\",${NC}"
    echo -e "  ${CYAN}  \"padding\": 0${NC}"
    echo -e "  ${CYAN}}${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}Remaining steps:${NC}"
echo
echo "1. Restart Claude Code to see the new statusline!"
echo
echo -e "${YELLOW}Note:${NC} usage quota and effort display require Claude Code >= 2.1.214"
echo "(older versions simply won't show those sections)."
echo
echo -e "${YELLOW}To uninstall later:${NC}"
echo "   $INSTALL_DIR/uninstall.sh"
echo
