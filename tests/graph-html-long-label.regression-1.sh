#!/bin/bash
# Regression: long card labels should truncate safely and expose full title text

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAPH_HTML_BASIC="tests/fixtures/graph-interactive-basic"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local text="$2"

    if ! grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to contain: $text"
    fi
}

build_graph_html_fixture() {
    local tmp_dir="$1"
    local output_dir="$tmp_dir/wiki"

    mkdir -p "$output_dir"
    cp "$REPO_ROOT/$GRAPH_HTML_BASIC/wiki/graph-data.json" "$output_dir/graph-data.json"

    bash "$REPO_ROOT/scripts/build-graph-html.sh" \
        "$tmp_dir" > /dev/null 2>&1 \
        || fail "build-graph-html.sh should succeed on basic fixture"
}

test_graph_html_has_truncate_label_runtime() {
    local tmp_dir output_dir
    tmp_dir="$(mktemp -d)"
    output_dir="$tmp_dir/wiki"

    build_graph_html_fixture "$tmp_dir"

    assert_file_contains "$output_dir/graph-wash.js" 'const labelSegmenter = new Intl.Segmenter("zh", { granularity: "grapheme" });'
    assert_file_contains "$output_dir/graph-wash.js" 'function truncateLabel(label, maxWidth) {'
    assert_file_contains "$output_dir/graph-wash.js" 'gg.append("title").text(label);'
    assert_file_contains "$output_dir/graph-wash.js" 'const { text: displayLabel, truncated } = truncateLabel(label, 180);'

    rm -rf "$tmp_dir"
}

test_graph_html_has_truncate_label_warning() {
    local tmp_dir output_dir
    tmp_dir="$(mktemp -d)"
    output_dir="$tmp_dir/wiki"

    build_graph_html_fixture "$tmp_dir"

    assert_file_contains "$output_dir/graph-wash.js" '[wiki] truncateLabel: invalid input'

    rm -rf "$tmp_dir"
}

main() {
    test_graph_html_has_truncate_label_runtime
    test_graph_html_has_truncate_label_warning
    echo "PASS: graph HTML long label regression coverage"
}

main "$@"
