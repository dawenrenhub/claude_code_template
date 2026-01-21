#!/bin/bash
# ==========================================
# Ralph Loop V7.1
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
export CLAUDE_PROJECT_DIR="$PROJECT_DIR"

MAX_LOOPS="${RALPH_MAX_LOOPS:-50}"
PROMPT_FILE="${RALPH_PROMPT_FILE:-$PROJECT_DIR/PROMPT.md}"
LOG_DIR="$PROJECT_DIR/logs"
SLEEP_BETWEEN="${RALPH_SLEEP:-2}"

EXIT_TOKEN="__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

check_deps() {
    local missing=0
    
    for cmd in jq claude; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}❌ 缺少 $cmd${NC}"
            missing=1
        fi
    done
    
    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}❌ Prompt 文件不存在: $PROMPT_FILE${NC}"
        missing=1
    fi
    
    [ "$missing" -eq 1 ] && exit 1
}

main() {
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}🚀 Ralph Loop V7.1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    
    check_deps
    mkdir -p "$LOG_DIR"
    mkdir -p "$PROJECT_DIR/.ralph"
    
    # 清理超过 7 天的旧日志
    find "$LOG_DIR" -name "loop_*.json" -mtime +7 -delete 2>/dev/null || true
    find "$LOG_DIR" -name "loop_*.log" -mtime +7 -delete 2>/dev/null || true
    
    for ((i=1; i<=MAX_LOOPS; i++)); do
        echo ""
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "${BLUE}🔄 Loop #$i / $MAX_LOOPS${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        
        STDOUT_LOG="$LOG_DIR/loop_${i}_stdout.json"
        STDERR_LOG="$LOG_DIR/loop_${i}_stderr.log"
        
        # 构建 prompt (包含失败记录，如果存在)
        FULL_PROMPT=$(cat "$PROMPT_FILE")
        
        if [ -f "$PROJECT_DIR/.ralph/last_failure.md" ]; then
            echo -e "${YELLOW}📋 发现上次失败记录，将包含在 prompt 中${NC}"
            FULL_PROMPT="$FULL_PROMPT

---

# ⚠️ 上次失败记录

$(cat $PROJECT_DIR/.ralph/last_failure.md)

请优先修复上述问题！"
        fi
        
        echo -e "${YELLOW}执行 Claude...${NC}"
        
        CLAUDE_EXIT=0
        claude -p "$FULL_PROMPT" \
            --output-format json \
            > "$STDOUT_LOG" \
            2> "$STDERR_LOG" \
            || CLAUDE_EXIT=$?
        
        echo -e "  Exit Code: $CLAUDE_EXIT"
        
        # 检查是否有阻断
        if grep -q '"decision".*:.*"block"' "$STDERR_LOG" 2>/dev/null; then
            echo -e "${RED}⚠️  Stop Hook 阻断了退出${NC}"
            echo -e "${YELLOW}   查看 .ralph/last_failure.md 了解详情${NC}"
        elif grep -qF "$EXIT_TOKEN" "$STDOUT_LOG" 2>/dev/null; then
            # Token 在输出中且没有被阻断 = 成功
            echo ""
            echo -e "${GREEN}══════════════════════════════════════════${NC}"
            echo -e "${GREEN}🎉 Ralph 完成任务！${NC}"
            echo -e "${GREEN}══════════════════════════════════════════${NC}"
            exit 0
        else
            echo -e "${YELLOW}⏳ 继续...${NC}"
        fi
        
        [ "$i" -lt "$MAX_LOOPS" ] && sleep "$SLEEP_BETWEEN"
    done
    
    echo -e "${RED}⚠️  达到最大循环次数${NC}"
    exit 1
}

main "$@"
