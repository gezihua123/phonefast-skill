#!/usr/bin/env bash
# ===========================================================================
# phonefast Package Installer (Bootstrapper)
# ===========================================================================
# 每次运行实时从 phonefast 仓库拉取最新的安装脚本，避免在 skill 包中
# 维护副本。确保安装逻辑始终与 phonefast 官方一致。
#
# 来源: https://raw.githubusercontent.com/gezihua123/phonefast/master/scripts/install_pkg.sh
# ===========================================================================

set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/gezihua123/phonefast/master/scripts/install_pkg.sh"
TMP_SCRIPT=""

cleanup() {
  if [ -n "$TMP_SCRIPT" ] && [ -f "$TMP_SCRIPT" ]; then
    rm -f "$TMP_SCRIPT"
  fi
}
trap cleanup EXIT

# ── 输出函数（在下载真正脚本前自包含） ──────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
step()  { echo -e "${CYAN}::${NC} $*"; }

# ── 检测 curl / wget ──────────────────────────────────────────────────────────
has_curl=false; has_wget=false
command -v curl >/dev/null 2>&1 && has_curl=true
command -v wget >/dev/null 2>&1 && has_wget=true

if [ "$has_curl" = false ] && [ "$has_wget" = false ]; then
  error "需要 curl 或 wget 来下载安装脚本"
fi

# 如果用户传了 --help 且只想看帮助，直接显示而不联网
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  # 尝试下载远程帮助，失败则回退本地信息
  echo "phonefast Package Installer (Bootstrapper)"
  echo ""
  echo "从 ${RAW_URL} 实时拉取安装脚本并执行。"
  echo ""
  echo "支持 install_pkg.sh 的所有参数，参见:"
  echo "  ${RAW_URL}"
  echo ""
  echo "用法: bash scripts/install_pkg.sh [选项]"
  echo ""
  echo "选项 (由远程脚本处理):"
  echo "  --local       安装到 ~/.local/bin"
  echo "  --global      安装到 /usr/local/bin"
  echo "  --version V   指定版本号"
  echo "  --dry-run     仅检测系统信息"
  echo "  --help        显示本帮助"
  echo ""
  echo "环境变量:"
  echo "  VERSION       版本号"
  echo "  INSTALL_DIR   安装目录"
  echo "  GITHUB_MIRROR GitHub 镜像地址"
  exit 0
fi

# ── 下载安装脚本 ──────────────────────────────────────────────────────────────
step "从 phonefast 仓库拉取安装脚本..."
TMP_SCRIPT=$(mktemp)

if [ "$has_curl" = true ]; then
  curl -fsSL --retry 3 --connect-timeout 10 "$RAW_URL" -o "$TMP_SCRIPT"
else
  wget -q --retry-connrefused --timeout=10 "$RAW_URL" -O "$TMP_SCRIPT"
fi

if [ ! -s "$TMP_SCRIPT" ]; then
  error "下载安装脚本失败\n      ${RAW_URL}\n      请检查网络连接"
fi

# ── 验证为合法 shell 脚本 ─────────────────────────────────────────────────────
if ! head -1 "$TMP_SCRIPT" | grep -qE '^#!/usr/bin/env bash|^#!/bin/bash|^#!/bin/sh'; then
  error "下载的文件不是有效的 shell 脚本"
fi

info "拉取成功 ($(du -h "$TMP_SCRIPT" | cut -f1))"

# ── 执行真正的安装脚本，透传所有参数 ─────────────────────────────────────────
step "执行安装..."
echo ""
bash "$TMP_SCRIPT" "$@"
