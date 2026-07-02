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

RESTORE_MODE=false
CHROME_APP_NAME="Google Chrome"
CHROME_BUNDLE_ID="com.google.Chrome"
CHROME_DIR_SUFFIX="Google/Chrome"
PROFILE_DIR_NAME="Default"

usage() {
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
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            exit 0 ;;
        --restore)
            RESTORE_MODE=true
            shift ;;
        --chrome)
            [[ $# -lt 2 ]] && { error "--chrome 需要指定名称参数"; exit 1; }
            case "$2" in
                "Canary"|"Chrome Canary")
                    CHROME_APP_NAME="Google Chrome Canary"
                    CHROME_BUNDLE_ID="com.google.Chrome.canary"
                    CHROME_DIR_SUFFIX="Google/Chrome Canary" ;;
                "Chrome"|"Google Chrome") ;;
                *)
                    error "未知版本: $2（可选: Chrome, Canary）"
                    exit 1 ;;
            esac
            shift 2 ;;
        *)
            error "未知选项: $1（使用 --help 查看帮助）"
            exit 1 ;;
    esac
done

CHROME_DATA_DIR="$HOME/Library/Application Support/$CHROME_DIR_SUFFIX"
LOCAL_STATE="$CHROME_DATA_DIR/Local State"
PREFERENCES="$CHROME_DATA_DIR/$PROFILE_DIR_NAME/Preferences"
BACKUP_TS="$(date +%Y%m%d_%H%M%S)"

require_local_state() {
    if [ ! -f "$LOCAL_STATE" ]; then
        error "找不到配置文件: $LOCAL_STATE"
        error "请确认 $CHROME_APP_NAME 已安装并至少启动过一次。"
        exit 1
    fi
}

require_python() {
    if ! command -v python3 &>/dev/null; then
        error "未找到 python3，无法修改 Chrome JSON 配置。"
        exit 1
    fi
}

latest_backup_for() {
    ls -1t "$1".bak.* 2>/dev/null | head -1 || true
}

backup_one() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        warn "找不到 $label，跳过: $path"
        return 0
    fi

    cp "$path" "$path.bak.$BACKUP_TS" || { error "$label 备份失败，磁盘可能已满"; exit 1; }
    success "$label 备份已保存: $(basename "$path.bak.$BACKUP_TS")"
}

restore_one() {
    local path="$1"
    local label="$2"
    local backup="$3"
    local restore_ts="$4"

    if [ ! -f "$backup" ]; then
        warn "未找到 $label 配套备份，跳过"
        return 0
    fi

    if [ -f "$path" ]; then
        cp "$path" "$path.before_restore.$restore_ts"
    fi
    cp "$backup" "$path"
    success "$label 已从备份恢复: $(basename "$backup")"
}

restore_latest_backup() {
    local latest_local_state
    local backup_id
    local restore_ts

    latest_local_state="$(latest_backup_for "$LOCAL_STATE")"
    if [ -z "$latest_local_state" ]; then
        error "未找到 Local State 备份文件"
        exit 1
    fi

    backup_id="${latest_local_state##*.bak.}"
    restore_ts="$(date +%Y%m%d_%H%M%S)"

    restore_one "$LOCAL_STATE" "Local State" "$latest_local_state" "$restore_ts"
    restore_one "$PREFERENCES" "Preferences" "$PREFERENCES.bak.$backup_id" "$restore_ts"

    echo -e "\n${YELLOW}请重启 $CHROME_APP_NAME 使恢复生效。${NC}\n"
}

close_chrome() {
    info "正在关闭 $CHROME_APP_NAME..."
    if ! pgrep -x "$CHROME_APP_NAME" > /dev/null 2>&1; then
        info "$CHROME_APP_NAME 未在运行，跳过"
        return 0
    fi

    pkill -x "$CHROME_APP_NAME" 2>/dev/null || true
    local waited=0
    while pgrep -x "$CHROME_APP_NAME" > /dev/null 2>&1; do
        sleep 0.5
        waited=$((waited + 1))
        if [ "$waited" -ge 30 ]; then
            warn "15 秒未退出，强制终止..."
            pkill -9 -x "$CHROME_APP_NAME" 2>/dev/null || true
            sleep 1
            break
        fi
    done
    success "$CHROME_APP_NAME 已关闭"
}

restore_current_run_backups() {
    if [ -f "$LOCAL_STATE.bak.$BACKUP_TS" ]; then
        cp "$LOCAL_STATE.bak.$BACKUP_TS" "$LOCAL_STATE" 2>/dev/null || true
    fi
    if [ -f "$PREFERENCES.bak.$BACKUP_TS" ]; then
        cp "$PREFERENCES.bak.$BACKUP_TS" "$PREFERENCES" 2>/dev/null || true
    fi
}

patch_chrome_json() {
    python3 - "$LOCAL_STATE" "$PREFERENCES" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

TARGET_COUNTRY = "us"
TARGET_LOCALE = "en-US"
TARGET_LANGUAGES = "en-US,en"

local_state_path = Path(sys.argv[1])
preferences_path = Path(sys.argv[2])
modified = 0
messages = []


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data):
    tmp = path.with_name(f"{path.name}.tmp.{os.getpid()}")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    os.replace(tmp, path)


def walk_dicts(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)


def set_key_everywhere(data, key, value):
    seen = 0
    changed = 0
    for obj in walk_dicts(data):
        if key not in obj:
            continue
        seen += 1
        if obj[key] != value:
            obj[key] = value
            changed += 1
    return seen, changed


def ensure_top_level(data, key, value):
    if data.get(key) == value:
        return 0
    data[key] = value
    return 1


def normalize_country_value(value):
    if isinstance(value, str):
        return (TARGET_COUNTRY, int(value.lower() != TARGET_COUNTRY))

    if not isinstance(value, list):
        return (value, 0)

    changed = 0
    normalized = []
    for item in value:
        if isinstance(item, str) and re.fullmatch(r"[A-Za-z]{2}", item):
            next_item = TARGET_COUNTRY
            changed += int(item.lower() != TARGET_COUNTRY)
        else:
            next_item = item
        normalized.append(next_item)
    return normalized, changed


def patch_local_state(path: Path):
    global modified
    data = load_json(path)

    seen, changed = set_key_everywhere(data, "is_glic_eligible", True)
    modified += changed
    if seen:
        messages.append(f"is_glic_eligible: true ({changed}/{seen})")
    else:
        messages.append("is_glic_eligible: not found")

    changed = ensure_top_level(data, "variations_country", TARGET_COUNTRY)
    modified += changed
    messages.append(f"variations_country: {TARGET_COUNTRY} ({changed})")

    seen = 0
    changed = 0
    for obj in walk_dicts(data):
        if "variations_permanent_consistency_country" not in obj:
            continue
        seen += 1
        next_value, item_changes = normalize_country_value(
            obj["variations_permanent_consistency_country"]
        )
        if item_changes:
            obj["variations_permanent_consistency_country"] = next_value
            changed += item_changes
    modified += changed
    if seen:
        messages.append(
            f"variations_permanent_consistency_country: {TARGET_COUNTRY} ({changed}/{seen})"
        )
    else:
        messages.append("variations_permanent_consistency_country: not found")

    seen, changed = set_key_everywhere(data, "app_locale", TARGET_LOCALE)
    if not seen:
        changed = ensure_top_level(data, "app_locale", TARGET_LOCALE)
        seen = 1
    modified += changed
    messages.append(f"app_locale: {TARGET_LOCALE} ({changed}/{seen})")

    save_json(path, data)


def ensure_path(data, path):
    current = data
    for key in path:
        next_value = current.get(key)
        if not isinstance(next_value, dict):
            next_value = {}
            current[key] = next_value
        current = next_value
    return current


def set_language_section(section):
    changed = 0
    for key in ("accept_languages", "selected_languages"):
        if section.get(key) != TARGET_LANGUAGES:
            section[key] = TARGET_LANGUAGES
            changed += 1
    return changed


def patch_preferences(path: Path):
    global modified
    if not path.exists():
        messages.append("Preferences intl: not found")
        return

    data = load_json(path)
    changed = set_language_section(ensure_path(data, ["intl"]))

    if isinstance(data.get("account_values"), dict):
        changed += set_language_section(ensure_path(data, ["account_values", "intl"]))

    modified += changed
    messages.append(f"Preferences intl languages: {TARGET_LANGUAGES} ({changed})")
    save_json(path, data)


patch_local_state(local_state_path)
patch_preferences(preferences_path)

print(f"modified={modified}")
for message in messages:
    print(message)
PY
}

validate_json() {
    local path="$1"
    local label="$2"

    if [ -f "$path" ] && ! python3 -m json.tool "$path" > /dev/null 2>&1; then
        error "$label JSON 结构损坏，正在自动恢复本次备份..."
        restore_current_run_backups
        error "已恢复至本次运行前备份"
        exit 1
    fi
}

apply_defaults() {
    defaults write "$CHROME_BUNDLE_ID" VariationsRestrictParameter -string "us" 2>/dev/null \
        || warn "VariationsRestrictParameter 写入失败（非致命）"
    defaults delete "$CHROME_BUNDLE_ID" AppleLanguages 2>/dev/null || true
    success "macOS 系统级设置已写入，并已清除 Chrome 单应用语言覆盖"
}

if $RESTORE_MODE; then
    restore_latest_backup
    exit 0
fi

require_local_state
require_python

echo ""
echo "============================================"
echo "  Chrome GLIC 区域解锁   [$CHROME_APP_NAME]"
echo "============================================"
echo ""

close_chrome

backup_one "$LOCAL_STATE" "Local State"
backup_one "$PREFERENCES" "Preferences"

info "正在应用目标配置..."
if ! PATCH_OUTPUT="$(patch_chrome_json)"; then
    error "JSON 修改失败，正在自动恢复本次备份..."
    restore_current_run_backups
    error "已恢复至本次运行前备份"
    exit 1
fi

MODIFIED="$(printf '%s\n' "$PATCH_OUTPUT" | sed -n 's/^modified=//p')"
printf '%s\n' "$PATCH_OUTPUT" | sed '/^modified=/d' | sed 's/^/  - /'

validate_json "$LOCAL_STATE" "Local State"
validate_json "$PREFERENCES" "Preferences"
success "JSON 结构校验通过"

apply_defaults

echo ""
echo "============================================"
success "完成！共修改 $MODIFIED 处"
echo "============================================"
echo ""
echo -e "${YELLOW}后续步骤:${NC}"
echo "  1. 确保 VPN 已连接到美国节点"
echo "  2. 重新启动 $CHROME_APP_NAME"
echo "  3. Chrome 界面语言会跟随 macOS 系统语言；如需英文界面，可在系统设置中单独配置 $CHROME_APP_NAME"
echo "  4. 网页可见语言偏好已改为 en-US,en；系统时区和 Emoji 渲染不会被本脚本修改"
echo ""
echo -e "${YELLOW}若 Gemini 侧边栏仍未出现，依次检查:${NC}"
echo -e "  ${CYAN}①${NC} chrome://flags → 搜索 Glic，将 Glic / Glic Actor / Glic Pre-Warming 设为 Enabled"
echo -e "  ${CYAN}②${NC} chrome://settings/languages → English (United States) 可用，但无需作为界面语言"
echo -e "  ${CYAN}③${NC} 打开 Gemini 侧边栏，完成 Personal Intelligence 初始化"
echo -e "  ${CYAN}④${NC} 确认 Google 账号为美区账号"
echo ""
echo -e "${BLUE}如需回滚:${NC} $0 --restore"
echo ""
