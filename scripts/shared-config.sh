#!/bin/bash
# 共享配置：被 install.sh / hook-session-start.sh / cache.sh / delete-helper.sh 等引用
# 微信公众号提取工具的 Git 仓库地址
WECHAT_TOOL_URL="git+https://github.com/jackwener/wechat-article-to-markdown.git"

# Python 命令检测：Windows 默认安装为 python.exe，不存在 python3 命令
# （Microsoft Store 的 python3 是安装提示 stub，运行会失败）
_python_version_check='import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)'

_python_cmd_is_valid() {
  local candidate="$1"

  command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "$_python_version_check" >/dev/null 2>&1
}

_detect_python_cmd() {
  # 要求 Python 3.8+（见 README Windows 小节与下方错误消息）
  if _python_cmd_is_valid python3; then
    echo "python3"
  elif _python_cmd_is_valid python; then
    echo "python"
  else
    echo ""
  fi
}

require_python_cmd() {
  local detected_cmd

  if [ "${PYTHON_CMD_READY:-0}" = "1" ]; then
    return 0
  fi

  if [ -n "${PYTHON_CMD:-}" ] && _python_cmd_is_valid "$PYTHON_CMD"; then
    export PYTHON_CMD
    PYTHON_CMD_READY=1
    return 0
  fi

  detected_cmd="$(_detect_python_cmd)"
  if [ -z "$detected_cmd" ]; then
    echo "[llm-wiki] 错误：找不到可用的 Python 3，请先安装 Python 3.8+ 并加入 PATH" >&2
    return 1
  fi

  PYTHON_CMD="$detected_cmd"
  export PYTHON_CMD
  PYTHON_CMD_READY=1
}

# 统一 Python 子进程 stdout/stderr 编码为 UTF-8
# Windows 中文环境下 Python 无 TTY 时 sys.stdout.encoding 默认 gbk (cp936)，
# 会导致 Agent 通过 subprocess 读取的 JSON / 输出出现乱码 (issue #16)
export PYTHONIOENCODING="${PYTHONIOENCODING:-utf-8}"
