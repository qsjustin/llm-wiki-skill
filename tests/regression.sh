#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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

assert_file_not_contains() {
    local file="$1"
    local text="$2"

    if grep -F -- "$text" "$file" > /dev/null; then
        fail "Expected $file to not contain: $text"
    fi
}

assert_text_contains() {
    local text="$1"
    local expected="$2"

    if ! printf '%s' "$text" | grep -F -- "$expected" > /dev/null; then
        fail "Expected output to contain: $expected"
    fi
}

assert_path_exists() {
    local path="$1"

    [ -e "$path" ] || fail "Expected path to exist: $path"
}

make_stub() {
    local path="$1"
    local body="$2"

    printf '%s\n' "$body" > "$path"
    chmod +x "$path"
}

test_setup_runs_on_bash_3_2() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" "#!/bin/sh
printf '%s\n' \"\$*\" >> \"$tmp_dir/uv.log\"
printf '%s\n' '#!/bin/sh' 'exit 0' > \"$tmp_dir/bin/wechat-article-to-markdown\"
chmod +x \"$tmp_dir/bin/wechat-article-to-markdown\"
exit 0"

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/setup.sh" 2>&1
    )" || fail "setup.sh should run successfully under bash 3.2"

    [ -d "$tmp_dir/home/.claude/skills/baoyu-url-to-markdown" ] || fail "Expected baoyu-url-to-markdown to be installed"
    [ -d "$tmp_dir/home/.claude/skills/youtube-transcript" ] || fail "Expected youtube-transcript to be installed"
    [ ! -d "$tmp_dir/home/.claude/skills/x-article-extractor" ] || fail "Did not expect x-article-extractor to be installed"
    assert_path_exists "$tmp_dir/bin/wechat-article-to-markdown"
    assert_file_contains "$tmp_dir/uv.log" "tool install git+https://github.com/jackwener/wechat-article-to-markdown.git"

    assert_text_contains "$output" "Chrome 调试端口 9222 未监听"
    assert_text_contains "$output" "open -na \"Google Chrome\" --args --remote-debugging-port=9222"
    assert_text_contains "$output" "wechat-article-to-markdown 安装完成"
}

test_install_dry_run_for_claude() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills"

    output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform claude --dry-run 2>&1
    )" || fail "install.sh dry-run for Claude should succeed"

    assert_text_contains "$output" "平台：claude"
    assert_text_contains "$output" "$tmp_dir/home/.claude/skills/llm-wiki"
}

test_install_auto_refuses_ambiguous_platforms() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/home/.codex/skills"

    if output="$(
        HOME="$tmp_dir/home" \
        bash "$REPO_ROOT/install.sh" --platform auto 2>&1
    )"; then
        fail "install.sh auto should fail when multiple platform homes are present"
    fi

    assert_text_contains "$output" "检测到多个可用平台"
    assert_text_contains "$output" "--platform"
}

test_install_openclaw_copies_bundle() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.openclaw/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$REPO_ROOT/install.sh" --platform openclaw > /dev/null 2>&1 || fail "install.sh should install for OpenClaw"

    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/SKILL.md"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/llm-wiki/install.sh"
    assert_path_exists "$tmp_dir/home/.openclaw/skills/baoyu-url-to-markdown"
}

test_init_fills_language_placeholder() {
    local tmp_dir wiki_root
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    wiki_root="$tmp_dir/Test Wiki"
    bash "$REPO_ROOT/scripts/init-wiki.sh" "$wiki_root" "测试主题" "English" > /dev/null

    assert_file_contains "$wiki_root/.wiki-schema.md" "- 语言：English"
    assert_file_not_contains "$wiki_root/.wiki-schema.md" "{{LANGUAGE}}"
}

test_readme_sections() {
    assert_file_contains "$REPO_ROOT/README.md" "## 前置条件"
    assert_file_contains "$REPO_ROOT/README.md" "## 常见问题"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform claude"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform codex"
    assert_file_contains "$REPO_ROOT/README.md" "bash install.sh --platform openclaw"
    assert_file_contains "$REPO_ROOT/README.md" "wechat-article-to-markdown"
    assert_file_not_contains "$REPO_ROOT/README.md" "x-article-extractor"
    assert_file_not_contains "$REPO_ROOT/README.md" "baoyu-danger-x-to-markdown"
}

test_uv_tool_install_failure_is_graceful() {
    local tmp_dir output
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    mkdir -p "$tmp_dir/home/.claude/skills" "$tmp_dir/bin"

    make_stub "$tmp_dir/bin/bun" '#!/bin/sh
mkdir -p node_modules
exit 0'

    make_stub "$tmp_dir/bin/lsof" '#!/bin/sh
exit 1'

    make_stub "$tmp_dir/bin/uv" '#!/bin/sh
exit 1'

    output="$(
        HOME="$tmp_dir/home" \
        PATH="$tmp_dir/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$REPO_ROOT/install.sh" --platform claude 2>&1
    )" || fail "install.sh should keep going when uv tool install fails"

    assert_text_contains "$output" "wechat-article-to-markdown 安装失败"
    assert_text_contains "$output" "llm-wiki 已准备完成"
    assert_path_exists "$tmp_dir/home/.claude/skills/llm-wiki/SKILL.md"
}

test_skill_md_routes_wechat_to_new_tool() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "mp.weixin.qq.com"
    assert_file_contains "$REPO_ROOT/SKILL.md" "wechat-article-to-markdown"
    assert_file_contains "$REPO_ROOT/SKILL.md" '- `x.com` / `twitter.com` → 调用 `baoyu-url-to-markdown`'
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "x-article-extractor"
}

test_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/entity-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/source-template.md" "- [[]]"
    assert_file_not_contains "$REPO_ROOT/templates/topic-template.md" "- [[]]"
}

test_batch_ingest_has_step_two() {
    local section
    section="$(sed -n '/## 工作流 3：batch-ingest/,/## 工作流 4：query/p' "$REPO_ROOT/SKILL.md")"

    assert_text_contains "$section" "1. **确认知识库路径**"
    assert_text_contains "$section" "2. **列出所有可处理文件**"
    assert_text_contains "$section" "3. **展示文件列表**"
}

test_english_templates_exist_and_have_placeholders() {
    assert_path_exists "$REPO_ROOT/templates/index-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/overview-en-template.md"
    assert_path_exists "$REPO_ROOT/templates/log-en-template.md"

    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/index-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/overview-en-template.md" "{{TOPIC}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{DATE}}"
    assert_file_contains "$REPO_ROOT/templates/log-en-template.md" "{{TOPIC}}"
}

test_english_templates_have_no_empty_links() {
    assert_file_not_contains "$REPO_ROOT/templates/index-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/overview-en-template.md" "[[]]"
    assert_file_not_contains "$REPO_ROOT/templates/log-en-template.md" "[[]]"
}

test_skill_md_has_shared_preflight_and_language_rules() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "## 通用前置检查"
    assert_file_contains "$REPO_ROOT/SKILL.md" "## 输出语言规则"
    assert_file_contains "$REPO_ROOT/SKILL.md" "素材 → Source"
    assert_file_contains "$REPO_ROOT/SKILL.md" "知识图谱 → Knowledge Graph"
}

test_skill_md_uses_external_english_templates_and_no_english_output_blocks() {
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/index-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/overview-en-template.md"
    assert_file_contains "$REPO_ROOT/SKILL.md" "templates/log-en-template.md"
    assert_file_not_contains "$REPO_ROOT/SKILL.md" "**English（en）**："
}

test_setup_wrapper_is_marked_deprecated() {
    assert_file_contains "$REPO_ROOT/setup.sh" "已废弃：请使用 bash install.sh --platform claude"
}

test_setup_runs_on_bash_3_2
test_install_dry_run_for_claude
test_install_auto_refuses_ambiguous_platforms
test_install_openclaw_copies_bundle
test_init_fills_language_placeholder
test_readme_sections
test_uv_tool_install_failure_is_graceful
test_skill_md_routes_wechat_to_new_tool
test_templates_have_no_empty_links
test_batch_ingest_has_step_two
test_english_templates_exist_and_have_placeholders
test_english_templates_have_no_empty_links
test_skill_md_has_shared_preflight_and_language_rules
test_skill_md_uses_external_english_templates_and_no_english_output_blocks
test_setup_wrapper_is_marked_deprecated

echo "All regression checks passed."
