#!/bin/bash
# ============================================================
# Chrome Gemini (GLIC) 区域解锁脚本
# 适用平台: macOS
# 使用前提: VPN 已连接美国节点 + Google 账号为美区
# 用法:
#   ./install.sh                    # 标准 Chrome
#   ./install.sh --chrome Canary    # Canary 版
#   ./install.sh --restore          # 从备份恢复
#   ./install.sh --help             # 查看帮助
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 参数解析 ─────────────────────────────────────────────────
RESTORE_MODE=false
CHROME_APP_NAME="Google Chrome"
CHROME_BUNDLE_ID="com.google.Chrome"
CHROME_DIR_SUFFIX="Google/Chrome"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --help          显示此帮助信息"
            echo "  --restore       从最近的备份恢复配置文件"
            echo "  --chrome NAME   指定 Chrome 版本 (默认: Chrome, 可选: Canary)"
            echo ""
            echo "示例:"
            echo "  $0                       # 标准 Chrome"
            echo "  $0 --chrome Canary       # Canary 版"
            echo "  $0 --restore             # 恢复备份"
            echo ""
            exit 0 ;;
        --restore)
            RESTORE_MODE=true; shift ;;
        --chrome)
            [[ $# -lt 2 ]] && { error "--chrome 需要指定名称参数"; exit 1; }
            case "$2" in
                "Canary"|"Chrome Canary")
                    CHROME_APP_NAME="Google Chrome Canary"
                    CHROME_BUNDLE_ID="com.google.Chrome.canary"
                    CHROME_DIR_SUFFIX="Google/Chrome Canary" ;;
                "Chrome"|"Google Chrome") ;;  # 默认值，无需改变
                *)
                    error "未知版本: $2（可选: Chrome, Canary）"; exit 1 ;;
            esac
            shift 2 ;;
        *)
            error "未知选项: $1（使用 --help 查看帮助）"; exit 1 ;;
    esac
done

# ── 路径定义 ─────────────────────────────────────────────────
LOCAL_STATE="$HOME/Library/Application Support/$CHROME_DIR_SUFFIX/Local State"
BACKUP="$LOCAL_STATE.bak.$(date +%Y%m%d_%H%M%S)"

# ── 前置检查 ─────────────────────────────────────────────────
if [ ! -f "$LOCAL_STATE" ]; then
    error "找不到配置文件: $LOCAL_STATE"
    error "请确认 $CHROME_APP_NAME 已安装并至少启动过一次。"
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    error "未找到 python3，无法进行 JSON 校验。"
    exit 1
fi

# ── 恢复模式 ─────────────────────────────────────────────────
if $RESTORE_MODE; then
    LATEST=$(ls -1t "$LOCAL_STATE".bak.* 2>/dev/null | head -1)
    if [ -z "$LATEST" ]; then
        error "未找到备份文件"; exit 1
    fi
    cp "$LOCAL_STATE" "$LOCAL_STATE.before_restore.$(date +%Y%m%d_%H%M%S)"
    cp "$LATEST" "$LOCAL_STATE"
    success "已从备份恢复: $(basename "$LATEST")"
    echo -e "\n${YELLOW}请重启 $CHROME_APP_NAME 使恢复生效。${NC}\n"
    exit 0
fi

# ── 步骤 1: 关闭 Chrome ──────────────────────────────────────
echo ""
echo "============================================"
echo "  Chrome GLIC 区域解锁   [$CHROME_APP_NAME]"
echo "============================================"
echo ""

info "正在关闭 $CHROME_APP_NAME..."
if pgrep -x "$CHROME_APP_NAME" > /dev/null 2>&1; then
    pkill -x "$CHROME_APP_NAME" 2>/dev/null || true
    WAITED=0
    while pgrep -x "$CHROME_APP_NAME" > /dev/null 2>&1; do
        sleep 0.5; WAITED=$((WAITED + 1))
        if [ $WAITED -ge 30 ]; then
            warn "15 秒未退出，强制终止..."
            pkill -9 -x "$CHROME_APP_NAME" 2>/dev/null || true
            sleep 1; break
        fi
    done
    success "$CHROME_APP_NAME 已关闭"
else
    info "$CHROME_APP_NAME 未在运行，跳过"
fi

# ── 步骤 2: 备份 ─────────────────────────────────────────────
cp "$LOCAL_STATE" "$BACKUP" || { error "备份失败，磁盘可能已满"; exit 1; }
success "备份已保存: $(basename "$BACKUP")"

# ── 步骤 3: 应用修改 ─────────────────────────────────────────
info "正在应用补丁..."
MODIFIED=0

# [1/4] GLIC 资格标志
if grep -q '"is_glic_eligible":[[:space:]]*false' "$LOCAL_STATE" 2>/dev/null; then
    sed -i '' 's/"is_glic_eligible":[[:space:]]*false/"is_glic_eligible":true/g' "$LOCAL_STATE"
    info "  [1/4] is_glic_eligible → true"; MODIFIED=$((MODIFIED + 1))
else
    info "  [1/4] is_glic_eligible 无需修改，跳过"
fi

# [2/4] variations_country
if grep -q '"variations_country":"[^"]*"' "$LOCAL_STATE" 2>/dev/null; then
    CURR=$(grep -o '"variations_country":"[^"]*"' "$LOCAL_STATE" | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
    if [ "$CURR" != "us" ]; then
        sed -i '' 's/"variations_country":"[^"]*"/"variations_country":"us"/g' "$LOCAL_STATE"
        info "  [2/4] variations_country: \"$CURR\" → \"us\""; MODIFIED=$((MODIFIED + 1))
    else
        info "  [2/4] variations_country 已为 \"us\"，跳过"
    fi
else
    warn "  [2/4] variations_country 字段不存在"
fi

# [3/4] variations_permanent_consistency_country
# 两种格式均处理: ["cn", timestamp] 或 [timestamp, "cn"]
MOD3=false
if grep -qE '"variations_permanent_consistency_country":\["[a-z]{2}"' "$LOCAL_STATE" 2>/dev/null; then
    sed -i '' 's/\("variations_permanent_consistency_country":\[\)"[a-z][a-z]"/\1"us"/' "$LOCAL_STATE"
    MOD3=true
fi
if grep -qE '"variations_permanent_consistency_country":\[[0-9]+,"[a-z]{2}"' "$LOCAL_STATE" 2>/dev/null; then
    sed -i '' 's/\("variations_permanent_consistency_country":\[[^,]*,\)"[^"]*"/\1"us"/' "$LOCAL_STATE"
    MOD3=true
fi
if $MOD3; then
    info "  [3/4] variations_permanent_consistency_country → \"us\""; MODIFIED=$((MODIFIED + 1))
else
    info "  [3/4] variations_permanent_consistency_country 无需修改，跳过"
fi

# [4/4] app_locale
if grep -q '"app_locale":"[^"]*"' "$LOCAL_STATE" 2>/dev/null; then
    CURR=$(grep -o '"app_locale":"[^"]*"' "$LOCAL_STATE" | head -1 | sed 's/.*:"\([^"]*\)".*/\1/')
    if [ "$CURR" != "en-US" ]; then
        sed -i '' 's/"app_locale":"[^"]*"/"app_locale":"en-US"/g' "$LOCAL_STATE"
        info "  [4/4] app_locale: \"$CURR\" → \"en-US\""; MODIFIED=$((MODIFIED + 1))
    else
        info "  [4/4] app_locale 已为 \"en-US\"，跳过"
    fi
else
    warn "  [4/4] app_locale 字段不存在，将通过 defaults 设置"
fi

# ── 步骤 4: JSON 完整性校验 ──────────────────────────────────
if ! python3 -m json.tool "$LOCAL_STATE" > /dev/null 2>&1; then
    error "JSON 结构损坏，正在自动恢复备份..."
    cp "$BACKUP" "$LOCAL_STATE"
    error "已恢复至: $(basename "$BACKUP")"
    exit 1
fi
success "JSON 结构校验通过"

# ── 步骤 5: macOS 系统级持久化 ───────────────────────────────
defaults write "$CHROME_BUNDLE_ID" VariationsRestrictParameter -string "us" 2>/dev/null \
    || warn "VariationsRestrictParameter 写入失败（非致命）"
defaults delete "$CHROME_BUNDLE_ID" AppleLanguages 2>/dev/null || true
success "macOS 系统级设置已写入，并已清除 Chrome 单应用语言覆盖"

# ── 完成 ─────────────────────────────────────────────────────
echo ""
echo "============================================"
success "完成！共修改 $MODIFIED 处"
echo "============================================"
echo ""
echo -e "${YELLOW}后续步骤:${NC}"
echo "  1. 确保 VPN 已连接到美国节点"
echo "  2. 重新启动 $CHROME_APP_NAME"
echo "  3. Chrome 界面语言会跟随 macOS 系统语言；如需英文界面，可在系统设置中单独配置 $CHROME_APP_NAME"
echo ""
echo -e "${YELLOW}若 Gemini 侧边栏仍未出现，依次检查:${NC}"
echo -e "  ${CYAN}①${NC} chrome://flags → 搜索 Glic，将 Glic / Glic Actor / Glic Pre-Warming 设为 Enabled"
echo -e "  ${CYAN}②${NC} chrome://settings/languages → English (United States) 可用，但无需作为界面语言"
echo -e "  ${CYAN}③${NC} 打开 Gemini 侧边栏，完成 Personal Intelligence 初始化"
echo -e "  ${CYAN}④${NC} 确认 Google 账号为美区账号"
echo ""
echo -e "${BLUE}如需回滚:${NC} $0 --restore"
echo ""
