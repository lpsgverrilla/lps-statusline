---
name: lps-statusline
description: The user's Claude Code statusline (lps-statusline). Use when the user wants to customize, tweak, or troubleshoot their statusline — colors, thresholds, separators, indicators, effort display, quota section, or adding/removing segments. Triggers on "statusline", "status line", "statusline.sh", "lps-statusline".
---

# lps-statusline — customization guide

The statusline is ONE bash script: `~/.local/share/lps-statusline/statusline.sh`
(wired via `statusLine.command` in `~/.claude/settings.json`). No Python, no
network, no cache — Claude Code pipes a JSON payload to it on stdin per render.

## How it works

One jq call extracts everything from the JSON input:
`model.id`/`display_name`, `effort.level`, `context_window.{context_window_size,used_percentage}`,
`rate_limits.five_hour/.seven_day.{used_percentage,resets_at}` (epoch seconds),
`fast_mode`, `transcript_path`, `cwd`. Each display section is built
independently and omitted when its data is absent, then assembled with `|`
separators:

```
workdir | repo(branch) | ✓ 0 | fable5(xhigh) | ⚡ | 🧠 25% | 31% ⏱️ 2h40m | 7d:70% | 🚨🚨🚨 | 🟢
💬 last user message
```

## Common customizations (all in statusline.sh)

- **Colors**: Gruvbox definitions at the top (`GRV_*`). Keep the ANSI-C quoting
  (`$'\033[...'`) — output is printed with `%s`; NEVER switch to `%b`
  (it escape-expands user data and corrupts the line).
- **Separator**: `SEP=` — alternative styles are in comments right above it.
- **Effort colors**: the `case "$effort_level"` block (low=gray … max=red).
- **Model colors**: `get_model_color()`; families are matched in `parse_model()`.
- **Thresholds**: context 🧠 colors (40/70), 5h quota colors (50/75),
  7d visibility (`-gt 65`), pace emoji breakpoints (×100 integers).
- **🚨 extra-usage sirens**: opt-in — `SHOW_EXTRA_USAGE=1` at the top, or
  `export LPS_STATUSLINE_EXTRA_USAGE=1`.
- **Second line (💬)**: built in the "User's Last Message" section; empty
  `SECOND_LINE` suppresses it.
- **New segment**: add the field to the single jq `@tsv` array (with the `"_"`
  empty-placeholder pattern), build a `MY_SECTION` string, append it in the
  "Assemble the Status Line" section following the existing pattern.

## Testing a change

```bash
echo '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"effort":{"level":"high"},"context_window":{"context_window_size":1000000}}' | bash ~/.local/share/lps-statusline/statusline.sh
```

Changes apply on the next render — no restart needed. If working from the
cloned repo, also run `bash tests/render-test.sh`.

## Requirements / gotchas

- Quota + effort sections need Claude Code ≥ 2.1.214 and a subscription
  (API-key sessions have no rate limits) — absent data hides the section.
- bash 4+, jq, git. macOS needs Homebrew bash in the settings command.
