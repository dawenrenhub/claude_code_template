#!/bin/bash

# ==========================================
# 模板卸载脚本 - uninstall.sh
# ==========================================
# 功能:
# 1. 交互式删除模板安装的文件
# 2. 可选备份功能
# 3. 支持无 manifest 的兼容模式
# 4. 保护项目源代码和依赖
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
MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"

# 参数默认值
DRY_RUN=false
FORCE_YES=false
DO_BACKUP=""  # 空表示询问
ONLY_CATEGORY=""
PURGE_EMPTY_DIRS=true
PROJECT_DIR_OVERRIDE=""

# 删除统计
DELETED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0
BACKUP_DIR=""

# 受保护的路径（绝不删除）
PROTECTED_PATHS=(
    "src"
    "lib"
    "app"
    "pages"
    "components"
    "node_modules"
    "venv"
    ".venv"
    "vendor"
    ".git"
    ".gitignore"
    ".env"
    ".env.local"
    ".env.production"
    "install.sh"
    "uninstall.sh"
    "restore.sh"
    "package.json"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
)

# 兼容模式的默认文件列表
FALLBACK_FILES=(
    ".mcp.json"
    "playwright.config.ts"
    "tests/e2e/example.spec.ts"
    ".eslintrc.json"
    ".prettierrc"
    "vitest.config.ts"
    "jest.config.cjs"
    "pytest.ini"
    "ruff.toml"
    "mypy.ini"
    ".github/workflows/ci.yml"
    "Makefile"
)

FALLBACK_DIRS=(
    "logs"
    "docs"
    "playwright"
    "tests/unit"
    "tests/e2e"
    "tests"
    "src"
    ".github/workflows"
    ".github"
)

# ==========================================
# 帮助信息
# ==========================================
show_help() {
    cat << EOF
${BOLD}模板卸载脚本${NC}

${CYAN}用法:${NC}
    ./uninstall.sh [选项]

${CYAN}选项:${NC}
    -h, --help          显示帮助信息
    -y, --yes           跳过所有确认，删除全部
    --dry-run           仅显示将删除的文件，不实际删除
    --backup            强制创建备份
    --no-backup         跳过备份
        --category=<name>   仅删除指定类别
                        可选: mcp-config,
                            tooling-config, test-examples, meta-files
    --purge-empty-dirs  额外清理所有空目录
    --project-dir=<dir> 指定要卸载的项目目录

${CYAN}示例:${NC}
    ./uninstall.sh                    # 交互式卸载
    ./uninstall.sh --dry-run          # 预览将删除的文件
    ./uninstall.sh -y --backup        # 备份后删除全部
    ./uninstall.sh --category=tooling-config # 仅删除工具链/测试配置
    ./uninstall.sh --purge-empty-dirs # 清理空目录
    ./uninstall.sh --project-dir=foo  # 指定项目目录

${CYAN}注意:${NC}
    - 此脚本不会删除项目源代码、依赖目录
    - 备份保存在 .template-backup/ 目录
    - 使用 ./restore.sh 可恢复已备份的文件

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

log_skip() {
    echo -e "${CYAN}⏭${NC} $1"
}

# ==========================================
# 根目录模块删除
# ==========================================
resolve_abs_path() {
    local p="$1"
    if [[ "$p" = /* ]]; then
        readlink -f "$p"
    else
        readlink -f "$SCRIPT_DIR/$p"
    fi
}

remove_root_item() {
    local item="$1"
    local abs
    abs="$(resolve_abs_path "$item")"

    if [ -z "$abs" ] || [[ "$abs" != "$SCRIPT_DIR/"* ]]; then
        log_error "路径不在模板根目录内，跳过: $item"
        return 1
    fi

    if [ "$abs" = "$SCRIPT_DIR" ]; then
        log_error "禁止删除模板根目录: $item"
        return 1
    fi

    if [ ! -e "$abs" ]; then
        log_skip "不存在: $item"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 将删除: $item"
        return 0
    fi

    rm -rf "$abs" && log_success "已删除: $item" || log_error "删除失败: $item"
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
            -y|--yes)
                FORCE_YES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                DO_BACKUP=true
                shift
                ;;
            --no-backup)
                DO_BACKUP=false
                shift
                ;;
            --category=*)
                ONLY_CATEGORY="${1#*=}"
                shift
                ;;
            --purge-empty-dirs)
                PURGE_EMPTY_DIRS=true
                shift
                ;;
            --project-dir=*)
                PROJECT_DIR_OVERRIDE="${1#*=}"
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
# 解析项目目录
# ==========================================
resolve_project_dir() {
    if [ -n "$PROJECT_DIR_OVERRIDE" ]; then
        if [ -d "$PROJECT_DIR_OVERRIDE" ]; then
            PROJECT_DIR="$(cd "$PROJECT_DIR_OVERRIDE" && pwd)"
            MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
            BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
            return 0
        else
            log_error "指定的项目目录不存在: $PROJECT_DIR_OVERRIDE"
            exit 1
        fi
    fi

    if [ -f "$PROJECT_DIR/.template-manifest.json" ]; then
        return 0
    fi

    # 自动检测 manifest
    mapfile -t manifest_paths < <(find "$SCRIPT_DIR" -maxdepth 3 -type f -name ".template-manifest.json" 2>/dev/null)
    if [ ${#manifest_paths[@]} -eq 1 ]; then
        PROJECT_DIR="$(dirname "${manifest_paths[0]}")"
        MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
        BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
        log_info "自动定位项目目录: $PROJECT_DIR"
        return 0
    elif [ ${#manifest_paths[@]} -gt 1 ]; then
        if [ "$FORCE_YES" = true ]; then
            PROJECT_DIR="$(dirname "${manifest_paths[0]}")"
            MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
            BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
            log_warning "检测到多个项目，已默认选择: $PROJECT_DIR"
            return 0
        fi

        echo -e "\n${CYAN}检测到多个安装项目，请选择要卸载的目录:${NC}"
        local i=1
        for p in "${manifest_paths[@]}"; do
            echo "  $i) $(dirname "$p")"
            ((i++))
        done
        read -p "请输入序号: " SELECT_IDX
        if [[ "$SELECT_IDX" =~ ^[0-9]+$ ]] && [ "$SELECT_IDX" -ge 1 ] && [ "$SELECT_IDX" -le ${#manifest_paths[@]} ]; then
            PROJECT_DIR="$(dirname "${manifest_paths[$((SELECT_IDX-1))]}")"
            MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
            BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
            return 0
        fi
        log_error "无效选择"
        exit 1
    fi

    # 兼容模式：尝试通过标记文件/目录定位
    marker_to_root() {
        local p="$1"
        if [[ "$p" == */logs/* || "$p" == */logs ]]; then
            echo "$(cd "$(dirname "$(dirname "$p")")" && pwd)"
        elif [[ "$p" == */docs/* || "$p" == */docs ]]; then
            echo "$(cd "$(dirname "$(dirname "$p")")" && pwd)"
        elif [[ "$p" == */playwright/* || "$p" == */playwright ]]; then
            echo "$(cd "$(dirname "$(dirname "$p")")" && pwd)"
        elif [[ "$p" == */tests/* || "$p" == */tests ]]; then
            echo "$(cd "$(dirname "$(dirname "$p")")" && pwd)"
        else
            echo "$(cd "$(dirname "$p")" && pwd)"
        fi
    }

    mapfile -t marker_paths < <(find "$SCRIPT_DIR" -maxdepth 4 \( -type f -o -type d \) \( \
        -name ".mcp.json" -o -name ".eslintrc.json" -o -name "vitest.config.ts" -o -name "jest.config.cjs" \
        -o -path "*/tests/e2e/example.spec.ts" \
        -o -path "*/logs" -o -path "*/docs" -o -path "*/playwright" -o -path "*/tests" -o -path "*/src" \
        -o -path "*/.github" \
    \) 2>/dev/null)

    if [ ${#marker_paths[@]} -ge 1 ]; then
        local unique_dirs=()
        local seen=""
        for mp in "${marker_paths[@]}"; do
            local d
            d="$(marker_to_root "$mp")"

            # 向上收敛到含有 uninstall.sh / install.sh / manifest 的目录
            local candidate="$d"
            while [ "$candidate" != "/" ] && [ "$candidate" != "$SCRIPT_DIR" ]; do
                if [ -f "$candidate/uninstall.sh" ] || [ -f "$candidate/install.sh" ] || [ -f "$candidate/.template-manifest.json" ]; then
                    break
                fi
                candidate="$(dirname "$candidate")"
            done

            if [ -f "$candidate/uninstall.sh" ] || [ -f "$candidate/install.sh" ] || [ -f "$candidate/.template-manifest.json" ]; then
                if [[ " $seen " != *" $candidate "* ]]; then
                    unique_dirs+=("$candidate")
                    seen="$seen $candidate"
                fi
            fi
        done

        if [ ${#unique_dirs[@]} -eq 1 ] || [ "$FORCE_YES" = true ]; then
            PROJECT_DIR="${unique_dirs[0]}"
            MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
            BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
            log_info "自动定位项目目录: $PROJECT_DIR"
            return 0
        fi

        echo -e "\n${CYAN}检测到多个可能的项目目录，请选择要卸载的目录:${NC}"
        local i=1
        for d in "${unique_dirs[@]}"; do
            echo "  $i) $d"
            ((i++))
        done
        read -p "请输入序号: " SELECT_IDX
        if [[ "$SELECT_IDX" =~ ^[0-9]+$ ]] && [ "$SELECT_IDX" -ge 1 ] && [ "$SELECT_IDX" -le ${#unique_dirs[@]} ]; then
            PROJECT_DIR="${unique_dirs[$((SELECT_IDX-1))]}"
            MANIFEST_FILE="$PROJECT_DIR/.template-manifest.json"
            BACKUP_BASE_DIR="$PROJECT_DIR/.template-backup"
            return 0
        fi
        log_error "无效选择"
        exit 1
    fi

    log_warning "未检测到安装清单，默认使用当前目录: $PROJECT_DIR"
}

# ==========================================
# 确认函数
# ==========================================
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$FORCE_YES" = true ]; then
        return 0
    fi
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " response
        response="${response:-y}"
    else
        read -p "$prompt [y/N]: " response
        response="${response:-n}"
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# ==========================================
# 路径保护检查
# ==========================================
is_protected() {
    local path="$1"
    local basename=$(basename "$path")
    
    for protected in "${PROTECTED_PATHS[@]}"; do
        if [[ "$path" == "$protected" ]] || [[ "$path" == "$protected/"* ]] || [[ "$basename" == "$protected" ]]; then
            return 0  # 受保护
        fi
    done
    return 1  # 不受保护
}

# ==========================================
# 备份文件
# ==========================================
backup_file() {
    local file="$1"
    local full_path="$PROJECT_DIR/$file"
    
    if [ ! -e "$full_path" ]; then
        return 0
    fi
    
    local backup_path="$BACKUP_DIR/$file"
    local backup_parent=$(dirname "$backup_path")
    
    mkdir -p "$backup_parent"
    
    if [ -d "$full_path" ]; then
        cp -r "$full_path" "$backup_path"
    else
        cp "$full_path" "$backup_path"
    fi
}

# ==========================================
# 删除文件
# ==========================================
remove_file() {
    local file="$1"
    local full_path="$PROJECT_DIR/$file"
    
    # 检查是否受保护
    if is_protected "$file"; then
        log_warning "跳过受保护文件: $file"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi
    
    # 检查文件是否存在
    if [ ! -e "$full_path" ]; then
        log_skip "文件不存在: $file"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi
    
    # Dry run 模式
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 将删除: $file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
        return 0
    fi
    
    # 备份
    if [ -n "$BACKUP_DIR" ]; then
        backup_file "$file"
    fi
    
    # 执行删除
    if rm -f "$full_path" 2>/dev/null; then
        log_success "已删除: $file"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        log_error "删除失败: $file"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
}

# ==========================================
# 删除空目录
# ==========================================
remove_empty_dir() {
    local dir="$1"
    local full_path="$PROJECT_DIR/$dir"
    
    # 检查是否受保护
    if is_protected "$dir"; then
        return 0
    fi
    
    # 检查目录是否存在
    if [ ! -d "$full_path" ]; then
        return 0
    fi
    
    # 检查目录是否为空
    if [ -z "$(ls -A "$full_path" 2>/dev/null)" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} 将删除空目录: $dir"
        else
            if rmdir "$full_path" 2>/dev/null; then
                log_success "已删除空目录: $dir"
            fi
        fi
    else
        log_skip "目录非空，保留: $dir"
    fi
}

# ==========================================
# 读取 Manifest
# ==========================================
read_manifest() {
    if [ -f "$MANIFEST_FILE" ]; then
        return 0
    else
        return 1
    fi
}

# ==========================================
# 从 Manifest 获取类别信息
# ==========================================
get_categories() {
    if [ -f "$MANIFEST_FILE" ]; then
        jq -r '.categories | keys[]' "$MANIFEST_FILE" 2>/dev/null
    else
        echo "mcp-config"
        echo "tooling-config"
        echo "test-examples"
        echo "meta-files"
    fi
}

get_category_name() {
    local category="$1"
    if [ -f "$MANIFEST_FILE" ]; then
        jq -r ".categories[\"$category\"].name // \"$category\"" "$MANIFEST_FILE" 2>/dev/null
    else
        case "$category" in
            mcp-config) echo "MCP 配置" ;;
            backend-init) echo "后端初始化" ;;
            tooling-config) echo "工具链与测试配置" ;;
            test-examples) echo "测试示例" ;;
            meta-files) echo "项目元文件" ;;
            *) echo "$category" ;;
        esac
    fi
}

get_category_files() {
    local category="$1"
    if [ -f "$MANIFEST_FILE" ]; then
        jq -r ".categories[\"$category\"].files[]? // empty" "$MANIFEST_FILE" 2>/dev/null
    else
        case "$category" in
            mcp-config)
                echo ".mcp.json"
                ;;
            tooling-config)
                echo ".eslintrc.json"
                echo ".prettierrc"
                echo "vitest.config.ts"
                echo "jest.config.cjs"
                echo "pytest.ini"
                echo "ruff.toml"
                echo "mypy.ini"
                echo ".github/workflows/ci.yml"
                echo "Makefile"
                ;;
            test-examples)
                echo "tests/e2e/example.spec.ts"
                echo "playwright.config.ts"
                ;;
            meta-files)
                # .gitignore 是受保护文件，不删除
                ;;
        esac
    fi
}

get_category_dirs() {
    local category="$1"
    if [ -f "$MANIFEST_FILE" ]; then
        jq -r ".categories[\"$category\"].directories[]? // empty" "$MANIFEST_FILE" 2>/dev/null
    else
        case "$category" in
            mcp-config)
                ;;
            tooling-config)
                echo ".github/workflows"
                echo ".github"
                ;;
            test-examples)
                echo "tests/unit"
                echo "tests/e2e"
                echo "tests"
                ;;
            meta-files)
                echo "logs"
                echo "docs"
                echo "src"
                ;;
        esac
    fi
}

# ==========================================
# 显示类别内容
# ==========================================
show_category_content() {
    local category="$1"
    local name=$(get_category_name "$category")
    local files=$(get_category_files "$category")
    local file_count=0
    local existing_files=()
    
    # 统计存在的文件
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if [ -e "$PROJECT_DIR/$file" ]; then
            existing_files+=("$file")
            ((file_count++))
        fi
    done <<< "$files"
    
    if [ $file_count -eq 0 ]; then
        return 1  # 没有可删除的文件
    fi
    
    echo -e "\n${BOLD}[$category] $name${NC} ($file_count 个文件)"
    
    for file in "${existing_files[@]}"; do
        echo -e "    ├── $file"
    done
    
    return 0
}

# ==========================================
# 处理单个类别
# ==========================================
process_category() {
    local category="$1"
    local name=$(get_category_name "$category")
    local files=$(get_category_files "$category")
    local dirs=$(get_category_dirs "$category")
    
    echo -e "\n${BLUE}处理: $name${NC}"
    
    # 删除文件
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        remove_file "$file"
    done <<< "$files"
    
    # 删除空目录（从深到浅）
    local dir_array=()
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        dir_array+=("$dir")
    done <<< "$dirs"
    
    # 反向处理目录（先删除子目录）
    for ((i=${#dir_array[@]}-1; i>=0; i--)); do
        remove_empty_dir "${dir_array[i]}"
    done
}

# ==========================================
# 主函数
# ==========================================
main() {
    parse_args "$@"
    resolve_project_dir
    
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}🗑️  模板卸载工具${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    
    # 根目录模块删除
    local root_modules=("ralph-claude-code" ".claude" ".mcp.json" ".template-backup")
    if confirm "是否删除模板根目录模块?" "n"; then
        echo -e "\n${CYAN}可删除的根目录模块:${NC}"
        for m in "${root_modules[@]}"; do
            echo -e "  - $m"
        done
        for m in "${root_modules[@]}"; do
            if [ "$FORCE_YES" = true ] || confirm "删除 $m?" "n"; then
                if [ "$m" = "ralph-claude-code" ]; then
                    if [ -d "$SCRIPT_DIR/$m" ]; then
                        if confirm "是否在 ralph-claude-code 内执行 ./uninstall.sh 删除系统内组件?" "n"; then
                            if [ "$DRY_RUN" = true ]; then
                                echo -e "  ${YELLOW}[DRY-RUN]${NC} 将执行: $m/./uninstall.sh"
                            else
                                (cd "$SCRIPT_DIR/$m" && ( [ -x ./uninstall.sh ] && ./uninstall.sh || bash ./uninstall.sh )) || log_error "执行 ralph-claude-code/uninstall.sh 失败"
                            fi
                        fi
                    else
                        log_skip "未找到 ralph-claude-code，跳过内部卸载"
                    fi
                fi
                remove_root_item "$m"
            else
                log_skip "跳过: $m"
            fi
        done
    fi

    # 选择删除子项目（循环）
    if confirm "是否删除子项目目录?" "n"; then
        while true; do
            read -p "请输入子项目文件夹名(留空结束): " SUBPROJECT_NAME
            if [ -z "$SUBPROJECT_NAME" ]; then
                break
            fi
            remove_root_item "$SUBPROJECT_NAME"
            if ! confirm "继续删除下一个子项目?" "n"; then
                break
            fi
        done
    fi

    # 检查 jq
    if ! command -v jq &> /dev/null; then
        log_warning "未安装 jq，将使用兼容模式"
    fi
    
    # 检查 manifest
    if [ -f "$MANIFEST_FILE" ]; then
        log_info "检测到安装清单: .template-manifest.json"
    else
        log_warning "未检测到安装清单，使用默认文件列表"
    fi
    
    # Dry run 提示
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${YELLOW}${BOLD}[DRY-RUN 模式] 仅预览，不实际删除${NC}\n"
    fi
    
    # 获取所有类别
    local categories=$(get_categories)
    local selected_categories=()
    
    # 显示所有类别内容
    echo -e "\n${CYAN}📋 检测到以下模板安装的内容:${NC}"
    
    local has_content=false
    while IFS= read -r category; do
        [ -z "$category" ] && continue
        
        # 如果指定了类别，只显示该类别
        if [ -n "$ONLY_CATEGORY" ] && [ "$category" != "$ONLY_CATEGORY" ]; then
            continue
        fi
        
        if show_category_content "$category"; then
            has_content=true
            selected_categories+=("$category")
        fi
    done <<< "$categories"
    
    if [ "$has_content" = false ]; then
        echo -e "\n${GREEN}没有检测到可删除的模板文件${NC}"
        if [ "$PURGE_EMPTY_DIRS" = true ]; then
            log_info "将继续清理空目录..."
        else
            exit 0
        fi
    fi
    
    # 询问备份（仅在有可删除文件时）
    if [ "$DRY_RUN" = false ] && [ "$has_content" = true ]; then
        echo ""
        if [ -z "$DO_BACKUP" ]; then
            if confirm "是否需要备份这些文件?" "y"; then
                DO_BACKUP=true
            else
                DO_BACKUP=false
            fi
        fi
        
        if [ "$DO_BACKUP" = true ]; then
            BACKUP_DIR="$BACKUP_BASE_DIR/$(date +%Y-%m-%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            log_info "备份目录: $BACKUP_DIR"
            
            # 复制 manifest 到备份目录
            if [ -f "$MANIFEST_FILE" ]; then
                cp "$MANIFEST_FILE" "$BACKUP_DIR/manifest.json"
            fi
        fi
    fi
    
    # 逐类别确认
    local categories_to_delete=()
    if [ "$has_content" = true ]; then
        echo ""
        for category in "${selected_categories[@]}"; do
            local name=$(get_category_name "$category")
            
            if [ "$FORCE_YES" = true ]; then
                categories_to_delete+=("$category")
            else
                if confirm "删除 [$category] $name?"; then
                    categories_to_delete+=("$category")
                else
                    log_skip "跳过: $name"
                fi
            fi
        done
    fi

    if [ ${#categories_to_delete[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}没有选择任何类别${NC}"
        if [ "$PURGE_EMPTY_DIRS" = false ]; then
            exit 0
        fi
    fi
    
    # 最终确认
    if [ "$DRY_RUN" = false ] && [ "$FORCE_YES" = false ] && [ ${#categories_to_delete[@]} -gt 0 ]; then
        echo ""
        if ! confirm "确认删除选中的 ${#categories_to_delete[@]} 个类别?" "n"; then
            echo -e "\n${YELLOW}操作已取消${NC}"
            exit 0
        fi
    fi
    
    # 执行删除
    echo -e "\n${YELLOW}开始处理...${NC}"
    
    for category in "${categories_to_delete[@]}"; do
        process_category "$category"
    done

    # 兜底清理常见空目录（无论是否有清单）
    local cleanup_dirs=(
        "logs"
        "docs"
        "playwright"
        "tests/unit"
        "tests/e2e"
        "tests"
        "src"
        ".github/workflows"
        ".github"
    )
    for ((i=${#cleanup_dirs[@]}-1; i>=0; i--)); do
        remove_empty_dir "${cleanup_dirs[i]}"
    done
    
    # 删除 manifest 文件（如果删除了所有类别）
    if [ ${#categories_to_delete[@]} -gt 0 ] && [ ${#categories_to_delete[@]} -eq ${#selected_categories[@]} ] && [ -f "$MANIFEST_FILE" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo -e "  ${YELLOW}[DRY-RUN]${NC} 将删除: .template-manifest.json"
        else
            rm -f "$MANIFEST_FILE"
            log_success "已删除: .template-manifest.json"
        fi
    fi
    
    # 额外清理空目录
    if [ "$PURGE_EMPTY_DIRS" = true ]; then
        log_info "清理空目录..."
        while IFS= read -r -d '' dir; do
            [ -z "$dir" ] && continue
            if [ "$dir" = "$PROJECT_DIR" ]; then
                continue
            fi
            rel_dir="${dir#"$PROJECT_DIR/"}"
            remove_empty_dir "$rel_dir"
        done < <(find "$PROJECT_DIR" -type d -empty -print0 2>/dev/null)
    fi

    # 显示报告
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}📊 卸载报告${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY-RUN]${NC} 将删除: $DELETED_COUNT 个文件"
    else
        echo -e "  已删除: ${GREEN}$DELETED_COUNT${NC} 个文件"
    fi
    echo -e "  已跳过: ${CYAN}$SKIPPED_COUNT${NC} 个"
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "  失败: ${RED}$ERROR_COUNT${NC} 个"
    fi
    
    if [ -n "$BACKUP_DIR" ] && [ "$DRY_RUN" = false ]; then
        echo -e "  备份位置: ${CYAN}$BACKUP_DIR${NC}"
        echo ""
        echo -e "${CYAN}💡 提示: 使用 ./restore.sh 可恢复已备份的文件${NC}"
    fi
    
    echo ""
}

main "$@"
