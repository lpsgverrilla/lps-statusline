#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# LPS-STATUSLINE Uninstaller
# ═══════════════════════════════════════════════════════════════════════════════
# Removes lps-statusline and optionally restores previous settings
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

DEFAULT_INSTALL_DIR="$HOME/.local/share/lps-statusline"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           LPS-STATUSLINE Uninstaller${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Find Installation
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Looking for lps-statusline installation...${NC}"

# Check default location
if [ -d "$DEFAULT_INSTALL_DIR" ] && [ -f "$DEFAULT_INSTALL_DIR/statusline.sh" ]; then
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    echo -e "Found at: ${CYAN}$INSTALL_DIR${NC}"
else
    echo -e "${YELLOW}Not found at default location ($DEFAULT_INSTALL_DIR)${NC}"
    read -rp "Enter installation path (or press Enter to skip file removal): " INSTALL_DIR
    INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Confirm Uninstall
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${YELLOW}This will:${NC}"
if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
    echo "  • Remove $INSTALL_DIR"
fi
echo "  • Remove statusLine config from ~/.claude/settings.json"
echo "  • Remove the Claude Code skill at ~/.claude/skills/lps-statusline"
echo
read -rp "Continue with uninstall? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Remove Installation Directory
# ─────────────────────────────────────────────────────────────────────────────
if [ -n "$INSTALL_DIR" ] && [ -d "$INSTALL_DIR" ]; then
    echo
    echo -e "${YELLOW}Removing installation directory...${NC}"
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓ Removed $INSTALL_DIR${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Remove Customization Skill
# ─────────────────────────────────────────────────────────────────────────────
if [ -d "$HOME/.claude/skills/lps-statusline" ]; then
    echo
    echo -e "${YELLOW}Removing Claude Code skill...${NC}"
    rm -rf "$HOME/.claude/skills/lps-statusline"
    echo -e "${GREEN}✓ Removed ~/.claude/skills/lps-statusline${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Update Claude Code Settings
# ─────────────────────────────────────────────────────────────────────────────
echo
if [ -f "$CLAUDE_SETTINGS" ]; then
    echo -e "${YELLOW}Updating Claude Code settings...${NC}"

    # Check if statusLine is configured
    current_statusline=$(jq -r '.statusLine // empty' "$CLAUDE_SETTINGS" 2>/dev/null)

    if [ -n "$current_statusline" ]; then
        # Check for backups
        backups=$(ls -t "$CLAUDE_SETTINGS".backup.* 2>/dev/null | head -5)

        if [ -n "$backups" ]; then
            echo
            echo -e "${CYAN}Found settings backups:${NC}"
            echo "$backups" | head -5 | nl
            echo
            read -rp "Restore from a backup? [number/N] " restore_choice

            if [[ "$restore_choice" =~ ^[0-9]+$ ]]; then
                backup_file=$(echo "$backups" | sed -n "${restore_choice}p")
                if [ -f "$backup_file" ]; then
                    cp "$backup_file" "$CLAUDE_SETTINGS"
                    echo -e "${GREEN}✓ Restored from $backup_file${NC}"
                else
                    echo -e "${RED}Invalid selection${NC}"
                fi
            else
                # Just remove the statusLine key
                tmp_file=$(mktemp)
                jq 'del(.statusLine)' "$CLAUDE_SETTINGS" > "$tmp_file" && mv "$tmp_file" "$CLAUDE_SETTINGS"
                echo -e "${GREEN}✓ Removed statusLine config (other settings preserved)${NC}"
            fi
        else
            # No backups, just remove statusLine key
            tmp_file=$(mktemp)
            jq 'del(.statusLine)' "$CLAUDE_SETTINGS" > "$tmp_file" && mv "$tmp_file" "$CLAUDE_SETTINGS"
            echo -e "${GREEN}✓ Removed statusLine config${NC}"
        fi
    else
        echo -e "${CYAN}No statusLine config found in settings${NC}"
    fi
else
    echo -e "${CYAN}No Claude settings file found${NC}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PATH Reminder
# ─────────────────────────────────────────────────────────────────────────────
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Uninstall complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}Don't forget to:${NC}"
echo "  • Remove the PATH export from ~/.bashrc or ~/.zshrc if you added one"
echo "  • Restart Claude Code to apply changes"
echo
