#!/bin/bash

# ==========================================
# 备份恢复脚本 - restore.sh
# ==========================================
# 功能:
# 1. 列出可用备份
# 2. 交互式选择恢复
# 3. 逐文件验证恢复结果
# 4. 验证通过后自动删除备份
# ==========================================

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 当前脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# 配置
BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"

# 参数默认值
FROM_BACKUP=""
LIST_ONLY=false
NO_CLEANUP=false
FORCE_OVERWRITE=false

# 统计
RESTORED_COUNT=0
VERIFIED_COUNT=0
FAILED_COUNT=0

# ==========================================
# 帮助信息
# ==========================================
show_help() {
    cat << EOF
${BOLD}备份恢复脚本${NC}

${CYAN}用法:${NC}
    ./restore.sh [选项]

${CYAN}选项:${NC}
    -h, --help          显示帮助信息
    --from=<dir>        指定备份目录（完整路径或备份名称）
    --list              仅列出可用备份
    --no-cleanup        恢复后不删除备份
    --force             覆盖已存在的文件

${CYAN}示例:${NC}
    ./restore.sh                           # 交互式选择备份并恢复
    ./restore.sh --list                    # 列出所有可用备份
    ./restore.sh --from=2026-01-31_100000  # 恢复指定备份
    ./restore.sh --no-cleanup              # 恢复后保留备份

${CYAN}注意:${NC}
    - 恢复成功并验证通过后，备份将被自动删除
    - 使用 --no-cleanup 可保留备份

EOF
    exit 0
}

# ==========================================
# 日志函数
# ==========================================
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# ==========================================
# 参数解析
# ==========================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                ;;
            --from=*)
                FROM_BACKUP="${1#*=}"
                shift
                ;;
            --list)
                LIST_ONLY=true
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                shift
                ;;
            --force)
                FORCE_OVERWRITE=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                echo "使用 --help 查看帮助"
                exit 1
                ;;
        esac
    done
}

# ==========================================
# 列出可用备份
# ==========================================
list_backups() {
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        return 1
    fi
    
    local backups=()
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        backups+=("$(basename "$dir")")
    done < <(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r)
    
    if [ ${#backups[@]} -eq 0 ]; then
        return 1
    fi
    
    echo "${backups[@]}"
}

# ==========================================
# 获取备份信息
# ==========================================
get_backup_info() {
    local backup_dir="$1"
    local file_count=0
    
    # 统计文件数量
    file_count=$(find "$backup_dir" -type f ! -name "manifest.json" 2>/dev/null | wc -l | tr -d ' ')
    
    # 获取时间戳
    local backup_name=$(basename "$backup_dir")
    local formatted_time=""
    
    if [[ "$backup_name" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
        formatted_time="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
    else
        formatted_time="$backup_name"
    fi
    
    echo "$file_count|$formatted_time"
}

# ==========================================
# 计算相对时间
# ==========================================
get_relative_time() {
    local backup_name="$1"
    
    if [[ "$backup_name" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
        local backup_timestamp="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
        local backup_epoch=$(date -d "$backup_timestamp" +%s 2>/dev/null || echo "0")
        local now_epoch=$(date +%s)
        local diff=$((now_epoch - backup_epoch))
        
        if [ $diff -lt 60 ]; then
            echo "刚刚"
        elif [ $diff -lt 3600 ]; then
            echo "$((diff / 60)) 分钟前"
        elif [ $diff -lt 86400 ]; then
            echo "$((diff / 3600)) 小时前"
        else
            echo "$((diff / 86400)) 天前"
        fi
    else
        echo ""
    fi
}

# ==========================================
# 显示备份列表
# ==========================================
show_backup_list() {
    local backups_str=$(list_backups)
    
    if [ -z "$backups_str" ]; then
        echo -e "\n${YELLOW}没有检测到可用备份${NC}"
        echo -e "备份目录: $BACKUP_BASE_DIR"
        return 1
    fi
    
    local backups=($backups_str)
    
    echo -e "\n${CYAN}📂 可用备份:${NC}\n"
    
    local index=1
    for backup in "${backups[@]}"; do
        local backup_dir="$BACKUP_BASE_DIR/$backup"
        local info=$(get_backup_info "$backup_dir")
        local file_count=$(echo "$info" | cut -d'|' -f1)
        local formatted_time=$(echo "$info" | cut -d'|' -f2)
        local relative_time=$(get_relative_time "$backup")
        
        echo -e "${BOLD}[$index]${NC} $backup"
        echo -e "    时间: $formatted_time ${CYAN}($relative_time)${NC}"
        echo -e "    文件: $file_count 个"
        echo ""
        
        ((index++))
    done
    
    return 0
}

# ==========================================
# 恢复单个文件
# ==========================================
restore_file() {
    local src="$1"  # 备份中的文件
    local dst="$2"  # 目标位置
    
    # 创建目标目录
    local dst_dir=$(dirname "$dst")
    mkdir -p "$dst_dir"
    
    # 检查目标是否已存在
    if [ -e "$dst" ] && [ "$FORCE_OVERWRITE" = false ]; then
        read -p "  文件已存在: $(basename "$dst")，是否覆盖? [y/N]: " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_warning "跳过: $dst"
            return 1
        fi
    fi
    
    # 执行复制
    if cp "$src" "$dst" 2>/dev/null; then
        log_success "恢复: $dst"
        ((RESTORED_COUNT++))
        return 0
    else
        log_error "恢复失败: $dst"
        ((FAILED_COUNT++))
        return 1
    fi
}

# ==========================================
# 验证文件
# ==========================================
verify_file() {
    local src="$1"  # 备份文件
    local dst="$2"  # 目标文件
    
    if [ ! -f "$dst" ]; then
        log_error "验证失败 (文件不存在): $dst"
        return 1
    fi
    
    # 比较 MD5
    local src_md5=$(md5sum "$src" 2>/dev/null | cut -d' ' -f1)
    local dst_md5=$(md5sum "$dst" 2>/dev/null | cut -d' ' -f1)
    
    if [ "$src_md5" = "$dst_md5" ]; then
        log_success "验证通过: $(basename "$dst")"
        ((VERIFIED_COUNT++))
        return 0
    else
        log_error "验证失败 (内容不匹配): $dst"
        return 1
    fi
}

# ==========================================
# 执行恢复
# ==========================================
do_restore() {
    local backup_dir="$1"
    
    echo -e "\n${YELLOW}恢复中...${NC}\n"
    
    # 获取备份中的所有文件（排除 manifest.json）
    local files=()
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        files+=("$file")
    done < <(find "$backup_dir" -type f ! -name "manifest.json" 2>/dev/null)
    
    if [ ${#files[@]} -eq 0 ]; then
        log_warning "备份中没有文件"
        return 1
    fi
    
    # 恢复每个文件
    for src_file in "${files[@]}"; do
        # 计算相对路径
        local rel_path="${src_file#$backup_dir/}"
        local dst_file="$PROJECT_DIR/$rel_path"
        
        restore_file "$src_file" "$dst_file"
    done
    
    # 验证
    echo -e "\n${YELLOW}验证中...${NC}\n"
    
    local verify_failed=false
    for src_file in "${files[@]}"; do
        local rel_path="${src_file#$backup_dir/}"
        local dst_file="$PROJECT_DIR/$rel_path"
        
        if [ -f "$dst_file" ]; then
            if ! verify_file "$src_file" "$dst_file"; then
                verify_failed=true
            fi
        fi
    done
    
    if [ "$verify_failed" = true ]; then
        return 1
    fi
    
    return 0
}

# ==========================================
# 清理备份
# ==========================================
cleanup_backup() {
    local backup_dir="$1"
    
    echo -e "\n${YELLOW}🗑️  正在删除备份...${NC}"
    
    if rm -rf "$backup_dir" 2>/dev/null; then
        log_success "备份已清理: $(basename "$backup_dir")"
        
        # 如果备份根目录为空，也删除它
        if [ -d "$BACKUP_BASE_DIR" ] && [ -z "$(ls -A "$BACKUP_BASE_DIR" 2>/dev/null)" ]; then
            rmdir "$BACKUP_BASE_DIR" 2>/dev/null || true
        fi
        
        return 0
    else
        log_error "清理备份失败"
        return 1
    fi
}

# ==========================================
# 主函数
# ==========================================
main() {
    parse_args "$@"
    
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔄 模板恢复工具${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    
    # 仅列出备份
    if [ "$LIST_ONLY" = true ]; then
        show_backup_list
        exit $?
    fi
    
    # 检查备份目录
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        echo -e "\n${YELLOW}没有检测到备份目录${NC}"
        echo -e "备份目录: $BACKUP_BASE_DIR"
        exit 1
    fi
    
    # 确定要恢复的备份
    local backup_dir=""
    
    if [ -n "$FROM_BACKUP" ]; then
        # 指定了备份
        if [ -d "$FROM_BACKUP" ]; then
            backup_dir="$FROM_BACKUP"
        elif [ -d "$BACKUP_BASE_DIR/$FROM_BACKUP" ]; then
            backup_dir="$BACKUP_BASE_DIR/$FROM_BACKUP"
        else
            log_error "备份不存在: $FROM_BACKUP"
            exit 1
        fi
    else
        # 交互式选择
        if ! show_backup_list; then
            exit 1
        fi
        
        local backups_str=$(list_backups)
        local backups=($backups_str)
        
        echo ""
        read -p "选择要恢复的备份 [1-${#backups[@]}]: " choice
        
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
            log_error "无效选择"
            exit 1
        fi
        
        backup_dir="$BACKUP_BASE_DIR/${backups[$((choice-1))]}"
    fi
    
    log_info "选择的备份: $(basename "$backup_dir")"
    
    # 显示将恢复的文件
    echo -e "\n${CYAN}📋 将恢复以下文件:${NC}\n"
    
    local file_list=()
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local rel_path="${file#$backup_dir/}"
        echo -e "  • $rel_path"
        file_list+=("$rel_path")
    done < <(find "$backup_dir" -type f ! -name "manifest.json" 2>/dev/null)
    
    if [ ${#file_list[@]} -eq 0 ]; then
        log_warning "备份中没有文件"
        exit 1
    fi
    
    # 确认恢复
    echo ""
    read -p "确认恢复这 ${#file_list[@]} 个文件? [y/N]: " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "\n${YELLOW}操作已取消${NC}"
        exit 0
    fi
    
    # 执行恢复
    if do_restore "$backup_dir"; then
        # 显示报告
        echo ""
        echo -e "${BLUE}══════════════════════════════════════════${NC}"
        echo -e "${GREEN}✅ 恢复完成！${NC}"
        echo -e "${BLUE}══════════════════════════════════════════${NC}"
        echo -e "  已恢复: ${GREEN}$RESTORED_COUNT${NC} 个文件"
        echo -e "  已验证: ${GREEN}$VERIFIED_COUNT${NC} 个文件"
        
        if [ $FAILED_COUNT -gt 0 ]; then
            echo -e "  失败: ${RED}$FAILED_COUNT${NC} 个文件"
        fi
        
        # 清理备份
        if [ "$NO_CLEANUP" = false ]; then
            cleanup_backup "$backup_dir"
        else
            echo -e "\n${CYAN}备份已保留: $(basename "$backup_dir")${NC}"
        fi
    else
        echo ""
        echo -e "${BLUE}══════════════════════════════════════════${NC}"
        echo -e "${RED}⚠️  恢复过程中出现错误${NC}"
        echo -e "${BLUE}══════════════════════════════════════════${NC}"
        echo -e "  已恢复: ${GREEN}$RESTORED_COUNT${NC} 个文件"
        echo -e "  已验证: ${GREEN}$VERIFIED_COUNT${NC} 个文件"
        echo -e "  失败: ${RED}$FAILED_COUNT${NC} 个文件"
        echo ""
        echo -e "${YELLOW}备份未删除，请检查后手动处理${NC}"
        echo -e "备份位置: $backup_dir"
        exit 1
    fi
    
    echo ""
}

main "$@"
