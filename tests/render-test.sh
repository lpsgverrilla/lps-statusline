#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# LPS-STATUSLINE Render Tests
# ═══════════════════════════════════════════════════════════════════════════════
# Feeds fixture JSON inputs through statusline.sh and asserts on the
# ANSI-stripped output. Run: bash tests/render-test.sh
# ═══════════════════════════════════════════════════════════════════════════════
# JSON fixtures are assembled by string concatenation on purpose:
# shellcheck disable=SC2089,SC2090

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE="$SCRIPT_DIR/../statusline.sh"

PASS=0
FAIL=0

# Render a JSON fixture through the statusline, ANSI codes stripped
render() {
    echo "$1" | bash "$STATUSLINE" | sed -e 's/\x1b\[[0-9;]*m//g'
}

assert_contains() {
    local label="$1" output="$2" needle="$3"
    if [[ "$output" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
        echo "  ok: $label"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $label"
        echo "      expected to contain: $needle"
        echo "      got: $output"
    fi
}

assert_not_contains() {
    local label="$1" output="$2" needle="$3"
    if [[ "$output" != *"$needle"* ]]; then
        PASS=$((PASS + 1))
        echo "  ok: $label"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $label"
        echo "      expected NOT to contain: $needle"
        echo "      got: $output"
    fi
}

# Future epochs for reset countdowns
NOW=$(date +%s)
IN_2H=$((NOW + 7200))
IN_1D=$((NOW + 86400))

RL='"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":'$IN_2H'},"seven_day":{"used_percentage":30,"resets_at":'$IN_1D'}}'

# ─── Model families and effort ────────────────────────────────────────────────

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"effort":{"level":"xhigh"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "fable5 + xhigh effort" "$out" "fable5(xhigh)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable"},"effort":{"level":"high"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "versionless display name falls back to model id" "$out" "fable5(high)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-mythos-5","display_name":"Mythos"},"effort":{"level":"max"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "mythos5 + max effort" "$out" "mythos5(max)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-opus-4-8","display_name":"Opus"},"effort":{"level":"max"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "opus4.8 + max effort" "$out" "opus4.8(max)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-opus-4-6","display_name":"Claude Opus 4.6"},"effort":{"level":"high"},"context_window":{"context_window_size":200000},'$RL'}')
assert_contains "legacy dotted display name still works" "$out" "opus4.6(high)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-sonnet-5","display_name":"Sonnet"},"effort":{"level":"medium"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "sonnet5 + medium effort" "$out" "sonnet5(medium)"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-sonnet-4-5-20250929","display_name":"Sonnet 4.5"},"context_window":{"context_window_size":200000},'$RL'}')
assert_contains "dated model id parses version" "$out" "sonnet4.5"
assert_not_contains "no effort field -> no parentheses" "$out" "("

out=$(render '{"cwd":"/tmp","model":{"id":"claude-haiku-4-5-20251001","display_name":"Haiku"},"context_window":{"context_window_size":200000},'$RL'}')
assert_contains "haiku4.5" "$out" "haiku4.5"

# ─── Fast mode ────────────────────────────────────────────────────────────────

out=$(render '{"cwd":"/tmp","model":{"id":"claude-opus-4-8","display_name":"Opus"},"effort":{"level":"high"},"fast_mode":true,"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "fast mode shows electric ray" "$out" "⚡"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-opus-4-8","display_name":"Opus"},"effort":{"level":"high"},"fast_mode":false,"context_window":{"context_window_size":1000000},'$RL'}')
assert_not_contains "fast mode off hides electric ray" "$out" "⚡"

# ─── Native quota (rate_limits) ───────────────────────────────────────────────

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "5h percentage shown" "$out" "42%"
assert_contains "reset countdown shown" "$out" "⏱️"
assert_not_contains "7d hidden at 30%" "$out" "7d:"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":'$IN_2H'},"seven_day":{"used_percentage":80,"resets_at":'$IN_1D'}}}')
assert_contains "7d shown above 65%" "$out" "7d:80%"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000}}')
assert_not_contains "no rate_limits -> no quota section" "$out" "⏱️"

# ─── Extra-usage sirens (opt-in) ──────────────────────────────────────────────

OVER='{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000},"rate_limits":{"five_hour":{"used_percentage":110,"resets_at":'$IN_2H'},"seven_day":{"used_percentage":50,"resets_at":'$IN_1D'}}}'

out=$(echo "$OVER" | LPS_STATUSLINE_EXTRA_USAGE=1 bash "$STATUSLINE" | sed -e 's/\x1b\[[0-9;]*m//g')
assert_contains "sirens shown when opted in and >=100%" "$out" "🚨🚨🚨"

out=$(render "$OVER")
assert_not_contains "sirens hidden by default" "$out" "🚨"

out=$(echo '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000},'$RL'}' | LPS_STATUSLINE_EXTRA_USAGE=1 bash "$STATUSLINE" | sed -e 's/\x1b\[[0-9;]*m//g')
assert_not_contains "sirens hidden when opted in but under 100%" "$out" "🚨"

# ─── Context window ───────────────────────────────────────────────────────────

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000,"used_percentage":37},'$RL'}')
assert_contains "native used_percentage fallback (no transcript)" "$out" "🧠 37%"

out=$(render '{"cwd":"/tmp","model":{"id":"claude-fable-5","display_name":"Fable 5"},"context_window":{"context_window_size":1000000},'$RL'}')
assert_contains "baseline estimate when nothing available" "$out" "🧠 ~"

# ─── Robustness ───────────────────────────────────────────────────────────────

out=$(echo 'not json at all' | bash "$STATUSLINE" | sed -e 's/\x1b\[[0-9;]*m//g')
assert_contains "invalid input handled" "$out" "invalid input"

out=$(render '{}')
assert_contains "empty object renders something" "$out" "unknown"

# ─── Summary ──────────────────────────────────────────────────────────────────

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
