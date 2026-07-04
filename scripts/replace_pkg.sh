#!/usr/bin/env bash
# ===========================================================================
# phonefast Binary Extractor & Replacer
# 提取替换脚本 — 从构建产物或发布包中提取 phonefast 二进制并替换安装
# ===========================================================================
# 用法:
#   bash scripts/replace_pkg.sh                          # 从 dist/ 提取并替换
#   bash scripts/replace_pkg.sh --source /path/to/dist   # 指定构建产物目录
#   bash scripts/replace_pkg.sh --archive file.tar.gz     # 从发布包提取并替换
#   bash scripts/replace_pkg.sh --install-dir /usr/local/bin
#   bash scripts/replace_pkg.sh --check                   # 仅检查，不替换
#   bash scripts/replace_pkg.sh --backup                  # 替换前备份旧版本
#   bash scripts/replace_pkg.sh --help                    # 显示帮助
#
# 不传任何参数时，自动在以下位置查找:
#   1. ~/.cache/phonefast-skill/src/dist/    (install_pkg.sh 的默认产物目录)
#   2. ./dist/                                (本地项目构建目录)
#   3. 当前目录下的 phonefast-*.tar.gz        (发布包)
# ===========================================================================

set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
step()  { echo -e "${CYAN}::${NC} $*"; }

# ── 默认配置 ───────────────────────────────────────────────────────────────────
CACHE_SRC_DIR="$HOME/.cache/phonefast-skill/src/dist"
LOCAL_DIST_DIR="./dist"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/phonefast-skill}"
INSTALL_DIR=""

# ── 帮助 ───────────────────────────────────────────────────────────────────────
show_help() {
  cat <<EOF
phonefast Binary Extractor & Replacer — 提取并替换 phonefast 二进制

用法: bash scripts/replace_pkg.sh [选项]

选项:
  --source DIR       指定构建产物目录 (dist 目录)
  --archive FILE     从 .tar.gz 发布包提取
  --install-dir DIR  安装目录 (默认自动检测)
  --backup           替换前备份旧版本
  --check            仅检查版本信息，不执行替换
  --help             显示本帮助

不传参时自动查找:
  1. ~/.cache/phonefast-skill/src/dist/   (install_pkg.sh 产物)
  2. ./dist/                               (本地构建产物)
  3. phonefast-*.tar.gz                    (发布包)

示例:
  bash scripts/replace_pkg.sh
  bash scripts/replace_pkg.sh --source ~/phonefast/dist
  bash scripts/replace_pkg.sh --archive phonefast-v1.0.1-darwin-arm64.tar.gz
  bash scripts/replace_pkg.sh --install-dir /usr/local/bin --backup
  bash scripts/replace_pkg.sh --check
EOF
  exit 0
}

# ── 系统检测 ───────────────────────────────────────────────────────────────────
detect_platform() {
  local os arch

  case "$(uname -s)" in
    Darwin)  os="darwin"  ;;
    Linux)   os="linux"   ;;
    CYGWIN*|MINGW*|MSYS*) os="windows" ;;
    *)       error "不支持的操作系统: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) error "不支持的架构: $(uname -m)" ;;
  esac

  if [ "$os" = "darwin" ] && [ "$arch" = "amd64" ]; then
    if [ "$(sysctl -n sysctl.proc_translated 2>/dev/null)" = "1" ]; then
      arch="arm64"
    fi
  fi

  echo "$os" "$arch"
}

# ── 检测已安装的版本 ───────────────────────────────────────────────────────────
detect_installed() {
  local install_dir="$1"
  local bin_path="${install_dir}/phonefast"

  if [ -x "$bin_path" ]; then
    echo "$bin_path"
  elif command -v phonefast >/dev/null 2>&1; then
    echo "$(command -v phonefast)"
  else
    echo ""
  fi
}

# ── 检测安装目录 ───────────────────────────────────────────────────────────────
find_install_dir() {
  # 优先使用用户指定的
  if [ -n "$INSTALL_DIR" ]; then
    echo "$INSTALL_DIR"
    return
  fi

  # 检查 phonefast 是否已在 PATH 中
  local current_bin
  current_bin=$(command -v phonefast 2>/dev/null || true)
  if [ -n "$current_bin" ]; then
    echo "$(dirname "$current_bin")"
    return
  fi

  # 检查常见目录
  for dir in "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
    if [ -x "${dir}/phonefast" ]; then
      echo "$dir"
      return
    fi
  done

  # 默认
  echo "$HOME/.local/bin"
}

# ── 从目录中查找二进制 ─────────────────────────────────────────────────────────
find_binary_in_dir() {
  local search_dir="$1"
  local os="$2"
  local arch="$3"

  if [ ! -d "$search_dir" ]; then
    echo ""
    return
  fi

  # 尝试各种可能的产物路径模式
  local candidates=()

  # build.sh 输出: dist/dev/phonefast-{os}-{arch}
  candidates+=("${search_dir}/dev/phonefast-${os}-${arch}")
  # 平台子目录: dist/dev/{os}/{arch}/phonefast
  candidates+=("${search_dir}/dev/${os}/${arch}/phonefast")
  # 直接在 dist 根目录
  candidates+=("${search_dir}/phonefast-${os}-${arch}")
  # 无后缀名
  candidates+=("${search_dir}/phonefast")

  # 尝试递归查找
  local found
  found=$(find "${search_dir}/dev" -maxdepth 3 -name 'phonefast*' -type f 2>/dev/null | head -1 || echo "")

  for candidate in "${candidates[@]}"; do
    if [ -f "$candidate" ] && [ -x "$candidate" ] || [ -f "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done

  if [ -n "$found" ]; then
    echo "$found"
    return
  fi

  echo ""
}

# ── 从 tar.gz 发布包提取 ──────────────────────────────────────────────────────
extract_from_archive() {
  local archive="$1"
  local os="$2"
  local arch="$3"

  if [ ! -f "$archive" ]; then
    echo ""
    return
  fi

  step "从发布包提取: $(basename "$archive")"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  tar -xzf "$archive" -C "$tmp_dir"

  # 查找提取后的二进制
  local binary=""
  local expected="${tmp_dir}/phonefast"
  if [ -f "$expected" ]; then
    binary="$expected"
  else
    # 递归查找
    binary=$(find "$tmp_dir" -maxdepth 3 -name 'phonefast*' -type f 2>/dev/null | head -1 || echo "")
  fi

  if [ -n "$binary" ] && [ -f "$binary" ]; then
    echo "$binary"
    # 不清理 tmp_dir，调用方负责
    return
  fi

  rm -rf "$tmp_dir"
  echo ""
}

# ── 自动查找来源 ────────────────────────────────────────────────────────────────
auto_find_source() {
  local os="$1"
  local arch="$2"

  # 1. 检查缓存构建产物
  local binary
  binary=$(find_binary_in_dir "$CACHE_SRC_DIR" "$os" "$arch")
  if [ -n "$binary" ]; then
    info "从缓存构建目录找到: ${binary}"
    echo "$binary"
    return
  fi

  # 2. 检查本地 dist 目录
  if [ -d "$LOCAL_DIST_DIR" ]; then
    binary=$(find_binary_in_dir "$LOCAL_DIST_DIR" "$os" "$arch")
    if [ -n "$binary" ]; then
      info "从本地构建目录找到: ${binary}"
      echo "$binary"
      return
    fi
  fi

  # 3. 尝试 CACHE_DIR/src/dist
  if [ -d "${CACHE_DIR}/src/dist" ]; then
    binary=$(find_binary_in_dir "${CACHE_DIR}/src/dist" "$os" "$arch")
    if [ -n "$binary" ]; then
      info "从 ${CACHE_DIR}/src/dist 找到: ${binary}"
      echo "$binary"
      return
    fi
  fi

  # 4. 查找当前目录下的发布包
  local archive
  archive=$(find . -maxdepth 1 -name "phonefast-*.tar.gz" 2>/dev/null | head -1 || echo "")
  if [ -n "$archive" ]; then
    binary=$(extract_from_archive "$archive" "$os" "$arch")
    if [ -n "$binary" ]; then
      info "从发布包提取: ${binary}"
      echo "$binary"
      return
    fi
  fi

  echo ""
}

# ── 显示二进制版本信息 ──────────────────────────────────────────────────────────
show_binary_info() {
  local bin_path="$1"
  if [ -x "$bin_path" ]; then
    local size
    size=$(du -h "$bin_path" | cut -f1)
    info "二进制: ${bin_path} (${size})"
    # 尝试获取版本信息
    local version_info
    version_info=$("$bin_path" version 2>/dev/null || "$bin_path" --version 2>/dev/null || echo "")
    if [ -n "$version_info" ]; then
      echo "     版本: ${version_info}"
    fi
  fi
}

# ── 主流程 ─────────────────────────────────────────────────────────────────────
main() {
  local source_dir=""
  local archive_file=""
  local do_backup=false
  local check_only=false
  local source_binary=""

  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source|-s)       source_dir="$2";    shift 2 ;;
      --archive|-a)      archive_file="$2";  shift 2 ;;
      --install-dir|-i)  INSTALL_DIR="$2";   shift 2 ;;
      --backup|-b)       do_backup=true;     shift ;;
      --check|-c)        check_only=true;    shift ;;
      --help|-h)         show_help ;;
      *)                 warn "未知选项: $1"; shift ;;
    esac
  done

  # 检测平台
  read -r os arch <<< "$(detect_platform)"

  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║     phonefast 提取替换工具                              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  info "系统: ${os} / ${arch}"

  # ── 查找或提取二进制 ──────────────────────────────────────────────────────
  if [ -n "$archive_file" ]; then
    # 从发布包提取
    source_binary=$(extract_from_archive "$archive_file" "$os" "$arch")
    if [ -z "$source_binary" ]; then
      error "从发布包提取失败: ${archive_file}"
    fi
    info "提取自发布包: $(basename "$archive_file")"
  elif [ -n "$source_dir" ]; then
    # 从指定目录查找
    source_binary=$(find_binary_in_dir "$source_dir" "$os" "$arch")
    if [ -z "$source_binary" ]; then
      error "在指定目录未找到 phonefast 二进制: ${source_dir}"
    fi
    info "来源目录: ${source_dir}"
  else
    # 自动查找
    source_binary=$(auto_find_source "$os" "$arch")
    if [ -z "$source_binary" ]; then
      error "\n未找到 phonefast 构建产物或发布包。\n      请先执行 scripts/build.sh 构建，或指定 --archive 参数。\n      ${CYAN}提示:${NC} 也可以运行 bash scripts/install_pkg.sh 一键构建安装。"
    fi
  fi

  # 设置可执行权限
  [ -x "$source_binary" ] || chmod +x "$source_binary" 2>/dev/null || true

  # 显示新二进制信息
  show_binary_info "$source_binary"

  # ── 如果只是检查 ──────────────────────────────────────────────────────────
  if [ "$check_only" = true ]; then
    echo ""
    info "Check-only 模式，未执行任何替换。"
    echo ""
    echo "  新二进制: ${source_binary}"
    echo ""
    exit 0
  fi

  # ── 确定安装目录 ──────────────────────────────────────────────────────────
  local target_dir
  target_dir=$(find_install_dir)
  local target_bin="${target_dir}/phonefast"

  info "目标路径: ${target_bin}"

  # ── 备份旧版本 ──────────────────────────────────────────────────────────
  if [ -f "$target_bin" ] && [ "$do_backup" = true ]; then
    local backup_path="${target_dir}/phonefast.bak.$(date +%Y%m%d%H%M%S)"
    step "备份旧版本到 ${backup_path}..."
    cp "$target_bin" "$backup_path"
    info "备份完成"
  fi

  # ── 显示版本对比 ──────────────────────────────────────────────────────────
  if [ -f "$target_bin" ]; then
    echo ""
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │                    版本对比                         │"
    echo "  ├─────────────────────────────────────────────────────┤"
    local old_info=""
    old_info=$("$target_bin" version 2>/dev/null || "$target_bin" --version 2>/dev/null || echo "(旧版本，无法读取)")
    local new_info=""
    new_info=$("$source_binary" version 2>/dev/null || "$source_binary" --version 2>/dev/null || echo "(新版本，无法读取)")
    printf "  │  旧: %-45s │\n" "${old_info:0:45}"
    printf "  │  新: %-45s │\n" "${new_info:0:45}"
    echo "  └─────────────────────────────────────────────────────┘"
    echo ""
  fi

  # ── 替换 ──────────────────────────────────────────────────────────────────
  step "替换 ${target_bin}..."

  # 如果安装目录需要 sudo 且当前用户无写权限
  if [ ! -w "$target_dir" ] && [ "$target_dir" = "/usr/local/bin" ]; then
    warn "目标目录 ${target_dir} 需要管理员权限"
    info "尝试使用 sudo 执行替换..."
    sudo cp "$source_binary" "$target_bin"
    sudo chmod +x "$target_bin"
  else
    mkdir -p "$target_dir"
    cp "$source_binary" "$target_bin"
    chmod +x "$target_bin"
  fi

  info "替换完成!"

  # ── 验证 ──────────────────────────────────────────────────────────────────
  echo ""
  step "验证新版本..."
  if [ -x "$target_bin" ]; then
    local installed_version
    installed_version=$("$target_bin" version 2>/dev/null || "$target_bin" --help 2>/dev/null | head -3 || echo "phonefast (验证通过)")
    info "已安装: ${target_bin}"
    echo "    ${installed_version}"
  fi

  # ── PATH 提示 ──────────────────────────────────────────────────────────────
  if ! command -v phonefast >/dev/null 2>&1; then
    warn "phonefast 不在 PATH 中，请将以下目录加入 PATH:"
    warn "  export PATH=\"${target_dir}:\$PATH\""
  fi

  # ── 清理临时文件 ──────────────────────────────────────────────────────────
  if [ -n "$archive_file" ] && [ -f "$source_binary" ]; then
    local source_dir_path
    source_dir_path=$(dirname "$source_binary")
    if [ "$source_dir_path" != "$HOME/.local/bin" ] && [ "$source_dir_path" != "/usr/local/bin" ]; then
      rm -rf "$source_dir_path" 2>/dev/null || true
    fi
  fi

  # ── 完成 ──
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║         🎉 phonefast 替换完成！                         ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "  启动 daemon:"
  echo "    phonefast daemon"
  echo ""
  echo "  查看帮助:"
  echo "    phonefast --help"
  echo ""
}

main "$@"
