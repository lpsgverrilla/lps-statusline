# lps-statusline

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-blue)](#requirements)

A two-line status line for [Claude Code](https://github.com/anthropics/claude-code): model and reasoning effort, usage quota with reset countdown, burn-rate pace, git status, and context window — at a glance, in Gruvbox.

![lps-statusline](screenshot.png)

> **Disclosure:** this project was written almost entirely by Claude Code itself — code, tests, and docs — with a human steering, vetoing, and using it daily. A statusline for Claude, by Claude.

It's one bash script. No Python, no network calls, no credentials — it just renders the JSON that Claude Code already pipes to statusline commands.

## Install

```bash
curl -sSL https://raw.githubusercontent.com/lpsgverrilla/lps-statusline/main/install-remote.sh | bash
```

Or clone and run `./install.sh`. Restart Claude Code afterwards.
Uninstall anytime with `~/.local/share/lps-statusline/uninstall.sh`.

## What it shows

- **directory** — aqua when it's a Claude project (`CLAUDE.md`/`.claude/` present)
- **git** — `repo(branch)` plus changed-file count (✓ clean, △ few, ● many)
- **model + effort** — `fable5(xhigh)`: family-colored model, effort color-coded low→max
- 🧠 — context window used, green→red
- **quota** — 5-hour usage % and ⏱️ time until reset
- **pace** — 💤 🔵 🟢 🟡 🟠 🔴 🔥 — how fast you're burning the 5-hour window
- 💬 — your last message, on the second line (best-effort)

And only when it matters: **7d:N%** (weekly quota past 65%), **⚡** (fast mode), **🚨🚨🚨** (a quota window exhausted — opt-in via `LPS_STATUSLINE_EXTRA_USAGE=1`).

## Customize

Colors, separators, and every threshold live at the top of `statusline.sh` — edit them and the next render picks it up, no restart. The installer can also add a small Claude Code **skill** so Claude itself can make those edits for you, from any directory.

## Requirements

- bash 4+, `jq`, `git` — Linux, macOS (Homebrew bash), or WSL, on any true-color terminal
- Claude Code ≥ 2.1.214 for the quota and effort sections (they hide gracefully on older versions)
- quota is meaningful on Claude Pro/Max plans — API-key sessions have no rate limits to show

## Credits

Context-window logic inspired by [ccstatusline](https://github.com/sirmalloc/ccstatusline); the last-message line is adapted from [claude-code-tips](https://github.com/ykdojo/claude-code-tips). Earlier versions fetched quota from claude.ai with browser cookies — Claude Code now provides it natively, so all of that machinery is gone (it lives in git history).

MIT licensed. Independent community project — not affiliated with Anthropic; "Claude" and "Claude Code" are Anthropic trademarks.
