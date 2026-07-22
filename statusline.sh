#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# LPS-STATUSLINE: Custom Status Line for Claude Code
# ═══════════════════════════════════════════════════════════════════════════════
# A rich, informative status line showing:
#   • Model name (fable/opus/sonnet/haiku + version) with color coding
#   • Reasoning effort level, color-coded by tier
#   • Git repo name, branch, and file change count
#   • Context window usage percentage
#   • Usage quota (5-hour and 7-day limits) from Claude Code's native data
#   • Consumption pace indicator
#   • Fast mode indicator (⚡)
#   • User's last message (second line)
#
# Theme: Gruvbox Dark (edit colors below to customize)
# Repository: https://github.com/lpsgverrilla/lps-statusline
# ═══════════════════════════════════════════════════════════════════════════════

# Read JSON input from stdin
input=$(cat)

# Validate JSON input
if ! echo "$input" | jq -e . >/dev/null 2>&1; then
    printf "invalid input"
    exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# User config
# ─────────────────────────────────────────────────────────────────────────────
# Show 🚨🚨🚨 when a usage window is exhausted (>=100%). Off by default;
# set to 1 here or export LPS_STATUSLINE_EXTRA_USAGE=1 to enable.
SHOW_EXTRA_USAGE="${LPS_STATUSLINE_EXTRA_USAGE:-0}"

# ─────────────────────────────────────────────────────────────────────────────
# ANSI Color Codes - Gruvbox Dark Theme
# ─────────────────────────────────────────────────────────────────────────────
# Palette:
#   Background dark:   #282828 (not used in status - terminal bg)
#   Background module: #3c3836 (not used in status - terminal bg)
#   Foreground:        #ebdbb2 (cream - primary text)
#   Accent/Yellow:     #fabd2f (highlights, important elements)
#   Warning/Red:       #fb4934 (errors, critical states)
#   Green:             #b8bb26 (success, low usage)
#   Aqua:              #8ec07c (secondary accent, info)
#   Blue:              #83a598 (muted accent)
#   Purple:            #d3869b (special elements)
#   Orange:            #fe8019 (warm accent)
#   Gray:              #928374 (muted/secondary text)
# ─────────────────────────────────────────────────────────────────────────────
# ANSI-C quoting ($'...') stores REAL escape bytes so the final output can be
# printed with %s — never %b, which would reinterpret backslashes inside data
# (e.g. a last message containing "C:\config" would truncate the whole line).
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

# Gruvbox colors using 24-bit true color (RGB)
# Primary text - cream
FG=$'\033[38;2;235;219;178m'

# Accent colors
GRV_YELLOW=$'\033[38;2;250;189;47m'
GRV_RED=$'\033[38;2;251;73;52m'
GRV_GREEN=$'\033[38;2;184;187;38m'
GRV_AQUA=$'\033[38;2;142;192;124m'
GRV_BLUE=$'\033[38;2;131;165;152m'
GRV_PURPLE=$'\033[38;2;211;134;155m'
GRV_ORANGE=$'\033[38;2;254;128;25m'
GRV_GRAY=$'\033[38;2;146;131;116m'

# ─────────────────────────────────────────────────────────────────────────────
# Separator Style (choose your favorite!)
# ─────────────────────────────────────────────────────────────────────────────
# Style 1: Classic pipes
# SEP="${DIM}${FG} │ ${RESET}"

# Style 2: Powerline-ish arrows
# SEP="${DIM}${GRV_AQUA} ❯ ${RESET}"

# Style 3: Dots
# SEP="${DIM}${FG} • ${RESET}"

# Style 4: Diamond separators
# SEP="${DIM}${GRV_PURPLE} ◆ ${RESET}"

# Style 5: Double angle
# SEP="${DIM}${GRV_AQUA} » ${RESET}"

# Style 6: Simple pipe (current) - Gruvbox gray
SEP="${GRV_GRAY} | ${RESET}"

# ─────────────────────────────────────────────────────────────────────────────
# Extract Data from JSON (single jq call for performance)
# ─────────────────────────────────────────────────────────────────────────────
# Use IFS=$'\t' to split only on tabs (display_name may contain spaces)
# IMPORTANT: Use "_" placeholder for empty strings to prevent bash read from
# collapsing consecutive tabs (empty fields get skipped otherwise)
IFS=$'\t' read -r cwd model_id model_display ctx_size effort_level five_used five_reset seven_used seven_reset fast_mode ctx_used_pct < <(
    echo "$input" | jq -r '
        [
            ((.workspace.current_dir // .cwd // "") | if . == "" then "_" else . end),
            ((.model.id // "") | if . == "" then "_" else . end),
            ((.model.display_name // "") | if . == "" then "_" else . end),
            (.context_window.context_window_size // 200000),
            ((.effort.level // "") | if . == "" then "_" else . end),
            ((.rate_limits.five_hour.used_percentage // "") | if . == "" then "_" else . end),
            ((.rate_limits.five_hour.resets_at // "") | if . == "" then "_" else . end),
            ((.rate_limits.seven_day.used_percentage // "") | if . == "" then "_" else . end),
            ((.rate_limits.seven_day.resets_at // "") | if . == "" then "_" else . end),
            (.fast_mode // false),
            ((.context_window.used_percentage // "") | if . == "" then "_" else . end)
        ] | @tsv'
)
# Convert placeholders back to empty strings
[ "$cwd" = "_" ] && cwd=""
[ "$model_id" = "_" ] && model_id=""
[ "$model_display" = "_" ] && model_display=""
[ "$effort_level" = "_" ] && effort_level=""
[ "$five_used" = "_" ] && five_used=""
[ "$five_reset" = "_" ] && five_reset=""
[ "$seven_used" = "_" ] && seven_used=""
[ "$seven_reset" = "_" ] && seven_reset=""
[ "$ctx_used_pct" = "_" ] && ctx_used_pct=""
ctx_used_pct=${ctx_used_pct%.*}   # truncate decimals

# ─────────────────────────────────────────────────────────────────────────────
# Parse Model Name (opus/sonnet/haiku)
# ─────────────────────────────────────────────────────────────────────────────
parse_model() {
    local model_str="$1"
    local display="$2"
    local model_name=""
    local version=""

    # Convert to lowercase for matching
    local lower_model lower_display
    lower_model=$(echo "$model_str" | tr '[:upper:]' '[:lower:]')
    lower_display=$(echo "$display" | tr '[:upper:]' '[:lower:]')

    # Determine model family
    if [[ "$lower_model" == *"fable"* ]] || [[ "$lower_display" == *"fable"* ]]; then
        model_name="fable"
    elif [[ "$lower_model" == *"mythos"* ]] || [[ "$lower_display" == *"mythos"* ]]; then
        model_name="mythos"
    elif [[ "$lower_model" == *"opus"* ]] || [[ "$lower_display" == *"opus"* ]]; then
        model_name="opus"
    elif [[ "$lower_model" == *"haiku"* ]] || [[ "$lower_display" == *"haiku"* ]]; then
        model_name="haiku"
    elif [[ "$lower_model" == *"sonnet"* ]] || [[ "$lower_display" == *"sonnet"* ]]; then
        model_name="sonnet"
    else
        # Unknown family: use the display name as-is (it may already contain
        # its own version — appending an extracted one would double it)
        echo "${display:-unknown}"
        return
    fi

    # Extract version from display name (e.g., "Claude Opus 4.6" → "4.6", "Fable 5" → "5")
    if [ -n "$display" ]; then
        version=$(echo "$display" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    fi

    # Fallback: extract version from model_id (e.g., "claude-opus-4-6" → "4.6")
    if [ -z "$version" ] && [ -n "$model_str" ] && [ "$model_name" != "${display:-unknown}" ]; then
        # Strip trailing date suffix (8+ consecutive digits) for clean parsing
        local clean_id
        clean_id=$(echo "$lower_model" | sed -E 's/-[0-9]{8,}$//')

        # Try: version after family name (e.g., opus-4-6 → 4.6, sonnet-4-5 → 4.5)
        version=$(echo "$clean_id" | sed -n "s/.*${model_name}-//p" | grep -oE '^[0-9]+(-[0-9]+)?' | tr '-' '.')
        # Try: version before family name (e.g., 3-5-sonnet → 3.5, 3-opus → 3)
        if [ -z "$version" ]; then
            version=$(echo "$clean_id" | sed -n "s/-${model_name}.*//p" | grep -oE '[0-9]+(-[0-9]+)?$' | tr '-' '.')
        fi
    fi

    # Combine: e.g., "opus4.6", "sonnet4.5"
    if [ -n "$version" ]; then
        echo "${model_name}${version}"
    else
        echo "$model_name"
    fi
}

MODEL_FORMATTED=$(parse_model "$model_id" "$model_display")

# Model color based on type (Gruvbox palette)
get_model_color() {
    local model="$1"
    case "$model" in
        fable*|mythos*) echo "$GRV_PURPLE" ;;  # Purple for Mythos-class tier
        opus*) echo "$GRV_ORANGE" ;;      # Warm orange for premium model
        sonnet*) echo "$GRV_BLUE" ;;      # Muted blue for mid-tier
        haiku*) echo "$GRV_AQUA" ;;       # Aqua for fast model
        *) echo "$FG" ;;                  # Default cream
    esac
}
MODEL_COLOR=$(get_model_color "$MODEL_FORMATTED")

# Effort level suffix: (low|medium|high|xhigh|max), lightly color-coded by tier
# Omitted entirely when the model doesn't support effort (field absent)
EFFORT_SECTION=""
if [ -n "$effort_level" ]; then
    case "$effort_level" in
        low)    EFFORT_COLOR="$GRV_GRAY" ;;
        medium) EFFORT_COLOR="$GRV_AQUA" ;;
        high)   EFFORT_COLOR="$GRV_YELLOW" ;;
        xhigh)  EFFORT_COLOR="$GRV_ORANGE" ;;
        max)    EFFORT_COLOR="$GRV_RED" ;;
        *)      EFFORT_COLOR="$GRV_GRAY" ;;
    esac
    EFFORT_SECTION="${DIM}${GRV_GRAY}(${RESET}${EFFORT_COLOR}${effort_level}${RESET}${DIM}${GRV_GRAY})${RESET}"
fi

# Fast mode indicator: ⚡ only when fast mode is active
FAST_SECTION=""
if [ "$fast_mode" = "true" ]; then
    FAST_SECTION="⚡"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Git Information (repo name, branch, file count)
# All git commands run in subshell to avoid changing main script's directory
# ─────────────────────────────────────────────────────────────────────────────
GIT_SECTION=""
REPO_NAME=""

# Check for Claude project markers (CLAUDE.md OR .claude/) - fast stat calls
HAS_CLAUDE_PROJECT=false
if [ -f "$cwd/CLAUDE.md" ] || [ -d "$cwd/.claude" ]; then
    HAS_CLAUDE_PROJECT=true
fi

# Check if directory is valid and is a git repo (run in subshell)
if [ -n "$cwd" ] && [ -d "$cwd" ] && (cd "$cwd" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1); then
    # Get git info in a subshell to avoid directory change side effects
    GIT_INFO=$(cd "$cwd" && {
        # Get repo name from remote URL or folder name
        REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null)

        if [ -n "$REMOTE_URL" ]; then
            REPO_NAME=$(basename -s .git "$REMOTE_URL" 2>/dev/null)
        fi

        # Fallback to git root directory name
        if [ -z "$REPO_NAME" ]; then
            GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
            if [ -n "$GIT_ROOT" ]; then
                REPO_NAME=$(basename "$GIT_ROOT")
            fi
        fi

        # Get current branch
        BRANCH=$(git branch --show-current 2>/dev/null)
        if [ -z "$BRANCH" ]; then
            BRANCH="@$(git rev-parse --short HEAD 2>/dev/null)"
        fi

        # Count all files in git status (tracked changes + untracked files)
        GIT_STATUS_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

        # Output tab-separated: repo\tbranch\tcount
        printf '%s\t%s\t%s' "$REPO_NAME" "$BRANCH" "$GIT_STATUS_COUNT"
    })

    # Parse git info output
    REPO_NAME=$(echo "$GIT_INFO" | cut -f1)
    BRANCH=$(echo "$GIT_INFO" | cut -f2)
    GIT_STATUS_COUNT=$(echo "$GIT_INFO" | cut -f3)

    # Defensive validation: ensure count is numeric
    if ! [[ "$GIT_STATUS_COUNT" =~ ^[0-9]+$ ]]; then
        GIT_STATUS_COUNT=0
    fi

    # Color for file count: green if 0, yellow if 1-5, red if more (Gruvbox)
    if [ "$GIT_STATUS_COUNT" -eq 0 ]; then
        FILE_COUNT_COLOR="${GRV_GREEN}"
        FILE_ICON="✓"
    elif [ "$GIT_STATUS_COUNT" -le 5 ]; then
        FILE_COUNT_COLOR="${GRV_YELLOW}"
        FILE_ICON="△"
    else
        FILE_COUNT_COLOR="${GRV_RED}"
        FILE_ICON="●"
    fi

    # Build git section: repo(branch) | files - repo name uses accent yellow
    GIT_SECTION="${BOLD}${GRV_YELLOW}${REPO_NAME}${RESET}"
    GIT_SECTION="${GIT_SECTION}${GRV_GRAY}(${RESET}${FG}${BRANCH}${RESET}${GRV_GRAY})${RESET}"
    GIT_SECTION="${GIT_SECTION}${SEP}${FILE_COUNT_COLOR}${FILE_ICON} ${GIT_STATUS_COUNT}${RESET}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Working Directory (ALWAYS shown first)
# Color: Gruvbox red if missing both CLAUDE.md and .claude/, aqua otherwise
# ─────────────────────────────────────────────────────────────────────────────
WORKDIR_SECTION=""
if [ -n "$cwd" ]; then
    WORKDIR_NAME=$(basename "$cwd" 2>/dev/null || echo "~")
    # Color based on Claude project markers: aqua if valid, muted red if missing
    if [ "$HAS_CLAUDE_PROJECT" = true ]; then
        WORKDIR_SECTION="${GRV_AQUA}${WORKDIR_NAME}${RESET}"
    else
        WORKDIR_SECTION="${DIM}${GRV_RED}${WORKDIR_NAME}${RESET}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Context Window Usage (transcript-based calculation)
# Reads actual token usage from transcript file for accuracy.
# This is more accurate than context_window.total_input_tokens from JSON,
# which excludes system prompt, tools, and memory.
# See: github.com/anthropics/claude-code/issues/13652
# Uses 20k baseline estimate at conversation start (before first response)
# ─────────────────────────────────────────────────────────────────────────────
CONTEXT_SECTION=""

# Get transcript path from JSON input
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

# Check if we have valid context window data (ctx_size > 0)
if [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
    # 20k baseline: system prompt (~3k), tools (~15k), memory (~300), env/framing (~2k)
    baseline=20000
    pct_prefix=""

    if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
        # Calculate context from transcript: sum tokens from last message with usage data
        context_length=$(jq -s '
            map(select(.message.usage and .isSidechain != true and .isApiErrorMessage != true)) |
            last |
            if . then
                (.message.usage.input_tokens // 0) +
                (.message.usage.cache_read_input_tokens // 0) +
                (.message.usage.cache_creation_input_tokens // 0)
            else 0 end
        ' < "$transcript_path" 2>/dev/null)

        # Validate context_length is numeric
        if ! [[ "$context_length" =~ ^[0-9]+$ ]]; then
            context_length=0
        fi

        if [ "$context_length" -gt 0 ]; then
            pct=$((context_length * 100 / ctx_size))
        elif [[ "$ctx_used_pct" =~ ^[0-9]+$ ]]; then
            # Fall back to Claude Code's own pre-computed percentage
            pct=$ctx_used_pct
        else
            # At conversation start, use baseline estimate
            pct=$((baseline * 100 / ctx_size))
            pct_prefix="~"
        fi
    else
        # Transcript not available yet
        if [[ "$ctx_used_pct" =~ ^[0-9]+$ ]]; then
            pct=$ctx_used_pct
        else
            pct=$((baseline * 100 / ctx_size))
            pct_prefix="~"
        fi
    fi

    # Cap at 100%
    [ "$pct" -gt 100 ] && pct=100

    # Color based on percentage (Gruvbox palette)
    if [ "$pct" -lt 40 ]; then
        PCT_COLOR="${GRV_GREEN}"
    elif [ "$pct" -lt 70 ]; then
        PCT_COLOR="${GRV_YELLOW}"
    else
        PCT_COLOR="${GRV_RED}"
    fi
    CONTEXT_SECTION="${PCT_COLOR}🧠 ${pct_prefix}${pct}%${RESET}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# User's Last Message (extracted from transcript)
# Shows the most recent user message, truncated to fit terminal width
# ─────────────────────────────────────────────────────────────────────────────
USER_MESSAGE=""

if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    # Extract last user message from transcript JSONL
    # Message format: { role: "user", content: string | array }
    # - If content is string: use directly
    # - If content is array: extract first text element
    # - Skip interrupted requests, local-command caveats, and empty messages
    USER_MESSAGE=$(jq -r '
        select(.type == "user") |
        .message.content |
        if type == "array" then
            [.[] | select(.type == "text") | .text][0] // ""
        elif type == "string" then
            .
        else
            ""
        end
    ' < "$transcript_path" 2>/dev/null | grep -v '^[[:space:]]*$' | grep -v '^\[Request interrupted' | grep -v '^<local-command' | tail -n1)

    # Normalize: convert newlines to spaces, collapse multiple spaces, trim
    if [ -n "$USER_MESSAGE" ]; then
        USER_MESSAGE=$(echo "$USER_MESSAGE" | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//')
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Usage Quota + Reset Time (native rate_limits from Claude Code's JSON input)
# Format: 31% ⏱️ 2h40m (5h limit with colored percentage and aqua countdown)
# 7d section shown separately only if > 65%
# 🚨 extra-usage sirens are opt-in via SHOW_EXTRA_USAGE (see User config)
# ─────────────────────────────────────────────────────────────────────────────
USAGE_SECTION=""
SEVEN_DAY_SECTION=""
EXTRA_SECTION=""
PACE_SECTION=""

# Truncate decimals (used_percentage may be fractional) and validate.
# 5h and 7d are computed independently — one may be present without the other.
five_pct=""
seven_pct=""
if [ -n "$five_used" ]; then
    five_pct=${five_used%.*}
    [[ "$five_pct" =~ ^[0-9]+$ ]] || five_pct=0
fi
if [ -n "$seven_used" ]; then
    seven_pct=${seven_used%.*}
    [[ "$seven_pct" =~ ^[0-9]+$ ]] || seven_pct=0
fi

if [ -n "$five_pct" ]; then
    # Color based on 5h percentage only (Gruvbox palette)
    if [ "$five_pct" -lt 50 ]; then
        USAGE_COLOR="${GRV_GREEN}"
    elif [ "$five_pct" -lt 75 ]; then
        USAGE_COLOR="${GRV_YELLOW}"
    else
        USAGE_COLOR="${GRV_RED}"
    fi

    # Reset countdown from resets_at (epoch seconds)
    reset_formatted=""
    hours_part=0
    mins_part=0
    if [[ "$five_reset" =~ ^[0-9]+$ ]]; then
        now_epoch=$(date +%s)
        rem_secs=$((five_reset - now_epoch))
        [ "$rem_secs" -lt 0 ] && rem_secs=0
        hours_part=$((rem_secs / 3600))
        mins_part=$(( (rem_secs % 3600) / 60 ))
        if [ "$hours_part" -gt 0 ]; then
            reset_formatted="${hours_part}h${mins_part}m"
        else
            reset_formatted="${mins_part}m"
        fi
    fi

    # Build 5h section: 31% ⏱️ 2h40m
    if [ -n "$reset_formatted" ]; then
        USAGE_SECTION="${USAGE_COLOR}${five_pct}%${RESET} ⏱️ ${GRV_AQUA}${reset_formatted}${RESET}"
    else
        USAGE_SECTION="⏱️ ${USAGE_COLOR}${five_pct}%${RESET}"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # Pace Indicator: shows if consuming quota at sustainable rate
    # pace = quota_used_pct / time_elapsed_pct
    # where time_elapsed_pct = (5 - hours_remaining) / 5
    # ─────────────────────────────────────────────────────────────────────────
    if [ -n "$reset_formatted" ]; then
        # Hours remaining as x100 integer (e.g., 3h24m = 340)
        hours_remaining_x100=$((hours_part * 100 + mins_part * 100 / 60))

        # time_elapsed_pct = (5 - hours_remaining) / 5
        # In x100 terms: (500 - hours_remaining_x100) / 5
        time_elapsed_x100=$(( (500 - hours_remaining_x100) * 100 / 500 ))

        # Edge case: if time_elapsed is 0 or negative (just started), show green
        if [ "$time_elapsed_x100" -le 5 ]; then
            PACE_SECTION="🟢"
        else
            # pace = quota_used_pct / time_elapsed_pct
            # Both five_pct and time_elapsed_x100 are percentages (0-100)
            # pace_x100 = pace * 100 for integer comparison
            pace_x100=$((five_pct * 100 / time_elapsed_x100))

            # Cap at 500 to prevent overflow with extreme values
            [ "$pace_x100" -gt 500 ] && pace_x100=500

            # Determine emoji based on pace (x100 scale: 100 = pace 1.0)
            if [ "$pace_x100" -lt 50 ]; then
                PACE_SECTION="💤"
            elif [ "$pace_x100" -lt 90 ]; then
                PACE_SECTION="🔵"
            elif [ "$pace_x100" -lt 105 ]; then
                PACE_SECTION="🟢"
            elif [ "$pace_x100" -lt 120 ]; then
                PACE_SECTION="🟡"
            elif [ "$pace_x100" -lt 140 ]; then
                PACE_SECTION="🟠"
            elif [ "$pace_x100" -lt 170 ]; then
                PACE_SECTION="🔴"
            else
                PACE_SECTION="🔥"
            fi
        fi
    fi
fi

# Build 7d section (independent of 5h): only show if > 65%
if [ -n "$seven_pct" ] && [ "$seven_pct" -gt 65 ]; then
    if [ "$seven_pct" -lt 75 ]; then
        SEVEN_DAY_COLOR="${GRV_YELLOW}"
    else
        SEVEN_DAY_COLOR="${GRV_RED}"
    fi
    SEVEN_DAY_SECTION="${SEVEN_DAY_COLOR}7d:${seven_pct}%${RESET}"
fi

# Extra usage section (opt-in): 🚨🚨🚨 when a usage window is exhausted
if [ "$SHOW_EXTRA_USAGE" = "1" ]; then
    if [ "${five_pct:-0}" -ge 100 ] || [ "${seven_pct:-0}" -ge 100 ]; then
        EXTRA_SECTION="🚨🚨🚨"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Assemble the Status Line
# Order: workdir | git | model(effort) | fast | context | usage | 7d | extra | pace
# ─────────────────────────────────────────────────────────────────────────────
OUTPUT=""

# Working directory section (colored by Claude project markers)
if [ -n "$WORKDIR_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${WORKDIR_SECTION}"
fi

# Git section: repo(branch) | files (only if in git repo)
if [ -n "$GIT_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${GIT_SECTION}"
fi

# Model section
if [ -n "$MODEL_FORMATTED" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${MODEL_COLOR}${MODEL_FORMATTED}${RESET}${EFFORT_SECTION}"
fi

# Fast mode section (⚡ only when fast mode is active)
if [ -n "$FAST_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${FAST_SECTION}"
fi

# Context section
if [ -n "$CONTEXT_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${CONTEXT_SECTION}"
fi

# Claude.ai usage quota section (5h limit + reset time)
if [ -n "$USAGE_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${USAGE_SECTION}"
fi

# 7-day section (only if > 65%): 7d:N%
if [ -n "$SEVEN_DAY_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${SEVEN_DAY_SECTION}"
fi

# Extra usage section (opt-in, only when a window is exhausted): 🚨🚨🚨
if [ -n "$EXTRA_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${EXTRA_SECTION}"
fi

# Pace indicator (far right): 💤🔵🟢🟡🟠🔴🔥 based on consumption rate
if [ -n "$PACE_SECTION" ]; then
    if [ -n "$OUTPUT" ]; then
        OUTPUT="${OUTPUT}${SEP}"
    fi
    OUTPUT="${OUTPUT}${PACE_SECTION}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Build Second Line: User's Last Message
# ─────────────────────────────────────────────────────────────────────────────
SECOND_LINE=""

if [ -n "$USER_MESSAGE" ]; then
    # Get terminal width, default to 80 if unavailable
    term_width=$(tput cols 2>/dev/null || echo 80)

    # Reserve space for "💬 " prefix (emoji + space = ~3 visible chars)
    max_msg_len=$((term_width - 5))
    [ "$max_msg_len" -lt 20 ] && max_msg_len=20

    # Truncate message if needed
    if [ "${#USER_MESSAGE}" -gt "$max_msg_len" ]; then
        USER_MESSAGE="${USER_MESSAGE:0:$max_msg_len}..."
    fi

    SECOND_LINE="${GRV_GRAY}💬 ${USER_MESSAGE}${RESET}"
fi

# Print the final status line(s) — %s so data is never escape-expanded
printf '%s' "$OUTPUT"

# Print second line if we have a user message
if [ -n "$SECOND_LINE" ]; then
    printf '\n%s' "$SECOND_LINE"
fi
