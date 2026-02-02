# lps-statusline

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-blue)](#compatibility)
[![Bash 4+](https://img.shields.io/badge/bash-4.0+-green)](#requirements)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-compatible-orange)](https://github.com/anthropics/claude-code)

A custom status line for Claude Code that displays real-time minimalist usage quota tracking, git integration, accurate context window, an iguana that looks like a lizzard, and more.

![Statusline Example](screenshot.png)

## Features

- **Model indicator** — Shows current model (opus/sonnet/haiku) with color coding
- **Git integration** — Repository name, branch, and changed file count
- **Context window** — Shows percentage of context used with color gradient
- **Usage quota tracking** — Real-time 5-hour and 7-day Claude.ai usage limits
- **Reset timer** — Time remaining until quota resets
- **Pace indicator** — Visual feedback on consumption rate
- **Second line** — Shows your last message for context (experimental)
- **Gruvbox theme** — Warm, easy-on-the-eyes color palette

## Quick Install

**One-liner:**
```bash
curl -sSL https://raw.githubusercontent.com/lpsgverrilla/lps-statusline/main/install-remote.sh | bash
```

**Or clone manually:**
```bash
git clone https://github.com/lpsgverrilla/lps-statusline.git
cd lps-statusline
./install.sh
```

The installer will:
1. Copy files to `~/.local/share/lps-statusline/`
2. Install Python dependencies
3. Configure Claude Code (or show manual steps if you decline)

Then restart Claude Code. Done!

> **Important:** Add the installation directory to your PATH for the usage tracking to work:
> ```bash
> echo 'export PATH="$PATH:$HOME/.local/share/lps-statusline"' >> ~/.bashrc  # or ~/.zshrc
> source ~/.bashrc
> ```


### Status Line Layout

```
🦎 | project-name | repo(main) | ✓ 0 | opus | 🧠 15% | 31% ⏱️ 2h40m | 🟢
💬 Your last message appears here...
```

### Status Indicators

| Element | Description |
|---------|-------------|
| 🦎 | Iguana indicator — shows `💡value💡` if `iguana_necktie` is set in the usage API response (an undocumented field, purpose unknown) |
| project-name | Working directory name. **Aqua** if the directory contains `CLAUDE.md` or `.claude/` (a Claude project), **dim red** otherwise |
| repo(main) | Git repository name and current branch. Only shown when inside a git repository |
| ✓ 0 | Git status: **✓** (green) = clean working tree, **△** (yellow) = 1-5 changed files, **●** (red) = 6+ changed files |
| opus | Current model: **orange** = opus, **blue** = sonnet, **aqua** = haiku |
| 🧠 15% | Context window usage — how much of the model's context limit is currently in use. Shows `~N%` (with tilde) when estimated before first API response |
| 31% ⏱️ 2h40m | 5-hour usage quota percentage and time until reset |
| 🟢 | Pace indicator (see below) |

### Conditional Indicators

The statusline follows a **minimalist philosophy** — additional indicators only appear when they require attention:

| Element | When Shown | Description |
|---------|------------|-------------|
| 7d:N% | When > 65% | 7-day rolling usage quota (weekly limit) |
| 🌹N% | When > 65% | Sonnet-specific weekly quota |
| 🚨🚨🚨 | When active | Extra usage indicator (you've exceeded normal limits) |

This keeps the statusline clean during normal usage while surfacing warnings when you're approaching limits.

### Line 2: Last Message

The second line shows your most recent message for context:

```
💬 Your last message appears here...
```

> **Note:** This feature is experimental. The implementation is adapted from [claude-code-tips](https://github.com/ykdojo/claude-code-tips) by ykdojo and parses the transcript file directly. It may not work correctly in all situations — messages might be stale, missing, or incorrectly extracted. Consider it a "best effort" feature.

### Pace Indicator Reference

| Emoji | Meaning |
|-------|---------|
| 💤 | Very low usage (< 50% of expected) |
| 🔵 | Below average (50-90%) |
| 🟢 | On track (90-105%) |
| 🟡 | Slightly fast (105-120%) |
| 🟠 | Fast (120-140%) |
| 🔴 | Very fast (140-170%) |
| 🔥 | Burning through quota (> 170%) |

## Compatibility

### Operating Systems

| OS | Status | Notes |
|----|--------|-------|
| **Linux** | ✅ Full support | Any distro (Arch, Ubuntu, Fedora, etc.) |
| **macOS** | ✅ Supported | Requires bash 4+ (install via Homebrew: `brew install bash`) |
| **Windows (WSL)** | ✅ Supported | Use WSL2 with any Linux distro |
| **Windows (native)** | ❌ Not supported | Scripts require bash |

### Terminals

Any terminal with **24-bit true color** support:
- Kitty, Alacritty, iTerm2, Windows Terminal, WezTerm
- GNOME Terminal, Konsole, Tilix (most modern terminals)
- VS Code integrated terminal

### Requirements

- **bash** 4.0+
- **jq** — JSON processor
- **git** — For repository info
- **Python** 3.10+ — For usage fetcher
- **uv** or **pip** — Python package manager
- **A browser** with active claude.ai session (Chrome, Firefox, Edge, or Chromium)

## Configuration

### Changing Colors

The statusline uses Gruvbox Dark theme by default. To customize, edit the color definitions at the top of `statusline.sh`.

## Troubleshooting

### "ERROR" in usage section

1. Make sure you're logged into claude.ai in your browser
2. Test the fetcher directly:
   ```bash
   cd ~/.local/share/lps-statusline/usage-fetch
   python3 script.py
   ```
3. On Linux, ensure your keyring is unlocked (browsers encrypt cookies with the system keyring)
4. Check if cookies are accessible — some browsers require additional setup

### Usage not updating

The usage data is cached for 3 minutes to avoid API spam. Wait or clear the cache:
```bash
rm ~/.cache/claude-code/usage-cache
```

### Git section not appearing

The git section only shows when inside a git repository. Verify with:
```bash
git rev-parse --git-dir
```

Also ensure `git` is installed and in your PATH.

### Context always shows ~N% (with tilde)

The `~` prefix indicates an estimate before Claude Code provides actual token counts. This happens:
- At conversation start (before any assistant response)
- If the transcript file path isn't being passed correctly

This resolves automatically after the first assistant response.

### macOS: Statusline errors or wrong behavior

macOS ships with bash 3.2, but lps-statusline requires bash 4+. Ensure you're using Homebrew bash:
```bash
# Check Homebrew bash version
/opt/homebrew/bin/bash --version  # Apple Silicon
/usr/local/bin/bash --version     # Intel Mac
```

Your `~/.claude/settings.json` must use the full path to Homebrew bash in the command field.

## How It Works

1. **statusline.sh** — Main script that Claude Code calls. Parses JSON input from Claude, extracts git info, and formats the output.

2. **claude-usage-status** — Non-blocking wrapper that caches API responses. Returns immediately with cached data while refreshing in background.

3. **usage-fetch/script.py** — Python script that reads browser cookies and fetches usage data from claude.ai API.

```
Claude Code → statusline.sh → claude-usage-status → script.py → claude.ai API
                   ↓                    ↓
              Terminal output      Cache file
```

### Claude Code Subagent

This project includes a **statusline-specialist** subagent for Claude Code. When installed, Claude Code can automatically spawn this specialist agent to help with statusline-related tasks.

**What the subagent can help with:**

- Troubleshooting display issues or errors
- Debugging data sources (usage API, git info, context window)
- Modifying appearance, colors, or components
- Adding new features or indicators
- Understanding how specific parts work
- Fixing calculation errors (e.g., context percentage issues)

**Model selection:**

During installation, you'll be asked to choose which model the subagent should use:

| Model      | Best for                                  |
| ---------- | ----------------------------------------- |
| **sonnet** | Faster responses, good for most tasks     |
| **opus**   | More thorough analysis, complex debugging |

The installer copies the agent definition to `~/.local/share/lps-statusline/.claude/agents/`. The specialist is available when Claude Code is running in that directory, or you can copy it to any project's `.claude/agents/` folder.

## Security

**No passwords or API keys are stored.** The usage fetcher works by reading session cookies from your browser.

| Concern | Answer |
|---------|--------|
| Are my credentials stored? | **No.** Nothing is saved to disk except a cache of the usage response. |
| Can someone steal my login? | **No.** Cookies are read locally from your browser's existing storage. |
| What if I log out of claude.ai? | The usage fetcher will stop working until you log in again. |
| Is anything sent to third parties? | **No.** Requests go directly to `claude.ai` only. |

### How authentication works

1. You log into [claude.ai](https://claude.ai) normally in your browser
2. Your browser stores session cookies locally (as all browsers do)
3. The `script.py` uses the `browser_cookie3` library to read these cookies
4. Cookies are used to make authenticated requests to `claude.ai/api/.../usage`

**Browser cookie access:**

The `browser_cookie3` library reads cookies from:
- Chrome/Chromium: `~/.config/google-chrome/`
- Firefox: `~/.mozilla/firefox/`
- Edge: `~/.config/microsoft-edge/`

On Linux, some browsers encrypt cookies with the system keyring. The `secretstorage` dependency handles this. If you get authentication errors, ensure your keyring is unlocked.

## Credits

Created by [lps](https://github.com/lpsgverrilla).

### Inspiration

This project was inspired by and builds upon ideas from:

- **[ccstatusline](https://github.com/sirmalloc/ccstatusline)** by sirmalloc — A clean statusline implementation that showed what's possible with Claude Code's custom statusline feature. The context window calculation logic in this project uses their implementation.
- **[claude-code-tips](https://github.com/ykdojo/claude-code-tips)** by ykdojo — Great collection of Claude Code tips including statusline customization ideas. The "last message" second line feature is adapted from their transcript parsing approach.

If you're looking for alternatives or want to explore different approaches, check out their work!

## License & Disclaimer

**MIT License** — see [LICENSE](LICENSE)

### Disclaimer

This is an independent community project. It is **not affiliated with, endorsed by, or sponsored by Anthropic** in any way, shape or form. "Claude" and "Claude Code" are trademarks of Anthropic.

**Who can use this?**

The usage quota tracking feature is designed for **Claude Pro and Claude Max subscribers**, as these plans have the 5-hour and 7-day usage limits that the statusline displays. If you're on the free tier or using Claude Code with an API key, the usage section won't show meaningful data.

**Important:**

By using this tool, you acknowledge that:
- You are responsible for reviewing and complying with [Anthropic's Consumer Terms](https://www.anthropic.com/legal/consumer-terms) and any applicable usage policies
- This tool accesses claude.ai APIs using your browser session cookies
- The author is not responsible for any issues arising from your use of this tool, including but not limited to account restrictions, data loss, or terms of service violations
- You use this tool at your own risk and discretion

**No warranty:**

This software is provided "as is", without warranty of any kind. Use at your own risk.

**Tested environment:**

This project was developed and tested on:
- **Claude Code**: 2.x
- **OS**: Arch Linux (kernel 6.x)
- **Terminal**: Kitty
- **Shell**: bash/zsh

It *should* work on other Claude Code versions, Linux distributions, macOS, and WSL, but your mileage may vary. Bug reports and contributions for other platforms are welcome, but no promises.
