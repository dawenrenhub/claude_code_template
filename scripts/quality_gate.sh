#!/bin/bash
# ==========================================
# Quality Gate V7.1 - 智能端口检测
# ==========================================

set -e

LOG_DIR="logs"
mkdir -p "$LOG_DIR"

SERVER_PID=""
TIMEOUT="${QUALITY_GATE_TIMEOUT:-30}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo -e "${YELLOW}🧹 停止测试服务器 (PID $SERVER_PID)...${NC}"
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

echo "══════════════════════════════════════════"
echo "🧪 Quality Gate V7.1"
echo "══════════════════════════════════════════"

# ----------------------------------------
# 1. 智能检测端口
# ----------------------------------------
echo -e "\n${YELLOW}[1/4] 检测项目配置...${NC}"

detect_port() {
    # 优先使用环境变量
    if [ -n "$QUALITY_GATE_PORT" ]; then
        echo "$QUALITY_GATE_PORT"
        return
    fi
    
    # 检查 vite.config.ts/js
    if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
        echo "5173"  # Vite 默认端口
        return
    fi
    
    # 检查 package.json 中的端口配置
    if [ -f "package.json" ]; then
        # 检查是否有 vite
        if grep -q '"vite"' package.json; then
            echo "5173"
            return
        fi
        # 检查是否有 next
        if grep -q '"next"' package.json; then
            echo "3000"
            return
        fi
        # 检查是否有 nuxt
        if grep -q '"nuxt"' package.json; then
            echo "3000"
            return
        fi
    fi
    
    # 检查 .env 文件
    if [ -f ".env" ]; then
        PORT_FROM_ENV=$(grep -E "^PORT=" .env 2>/dev/null | cut -d'=' -f2)
        if [ -n "$PORT_FROM_ENV" ]; then
            echo "$PORT_FROM_ENV"
            return
        fi
    fi
    
    # 默认端口
    echo "3000"
}

detect_start_command() {
    if [ -f "package.json" ]; then
        if grep -q '"dev"' package.json; then
            echo "npm run dev"
        elif grep -q '"start"' package.json; then
            echo "npm start"
        else
            echo "npm start"
        fi
    elif [ -f "requirements.txt" ]; then
        echo "python -m http.server $PORT"
    else
        echo ""
    fi
}

PORT=$(detect_port)
START_CMD=$(detect_start_command)

echo -e "  检测到端口: ${GREEN}$PORT${NC}"
echo -e "  启动命令: ${GREEN}$START_CMD${NC}"

# ----------------------------------------
# 2. 检查测试文件
# ----------------------------------------
echo -e "\n${YELLOW}[2/4] 检查测试文件...${NC}"

if [ ! -d "tests/e2e" ]; then
    echo -e "${RED}❌ tests/e2e 目录不存在${NC}"
    exit 1
fi

TEST_COUNT=$(find tests/e2e -name "*.spec.ts" -o -name "*.spec.js" -o -name "*.test.ts" -o -name "*.test.js" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TEST_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ 没有找到测试文件${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 $TEST_COUNT 个测试文件${NC}"

# ----------------------------------------
# 3. 检查/启动服务器
# ----------------------------------------
echo -e "\n${YELLOW}[3/4] 检查服务器状态...${NC}"

check_port() {
    if command -v lsof &> /dev/null; then
        lsof -Pi :"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1
    elif command -v ss &> /dev/null; then
        ss -tuln | grep -q ":$PORT "
    else
        (echo > /dev/tcp/localhost/"$PORT") 2>/dev/null
    fi
}

if check_port; then
    echo -e "${GREEN}✓ 服务器已在 :$PORT 运行${NC}"
    # 警告: 检查是否为预期服务
    if command -v lsof &> /dev/null; then
        PROC_NAME=$(lsof -Pi :"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -1 | xargs -I{} ps -p {} -o comm= 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}  进程: $PROC_NAME${NC}"
    fi
else
    if [ -z "$START_CMD" ]; then
        echo -e "${RED}❌ 无法检测启动命令，请手动启动服务器或设置 QUALITY_GATE_PORT${NC}"
        exit 1
    fi
    
    echo -e "  启动服务器: $START_CMD"
    $START_CMD > "$LOG_DIR/server.log" 2>&1 &
    SERVER_PID=$!
    
    echo -e "  等待端口 $PORT..."
    for i in $(seq 1 "$TIMEOUT"); do
        if check_port; then
            echo -e "${GREEN}✓ 服务器已启动 (${i}s)${NC}"
            break
        fi
        
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            echo -e "${RED}❌ 服务器启动失败${NC}"
            cat "$LOG_DIR/server.log" | tail -20
            exit 1
        fi
        
        sleep 1
        
        if [ "$i" -eq "$TIMEOUT" ]; then
            echo -e "${RED}❌ 服务器启动超时 (${TIMEOUT}s)${NC}"
            exit 1
        fi
    done
fi

# ----------------------------------------
# 4. 运行测试
# ----------------------------------------
echo -e "\n${YELLOW}[4/4] 运行 Playwright 测试...${NC}"

# 检查 package.json 是否存在，不存在则初始化
if [ ! -f "package.json" ]; then
    echo -e "${YELLOW}  初始化 package.json...${NC}"
    npm init -y
fi

if ! npx playwright --version > /dev/null 2>&1; then
    echo -e "${YELLOW}  安装 Playwright...${NC}"
    npm install -D @playwright/test
    npx playwright install --with-deps chromium
fi

TEST_OUTPUT="$LOG_DIR/playwright_$(date +%Y%m%d_%H%M%S).log"

# 关键修复: 将检测到的端口传递给 Playwright
export PLAYWRIGHT_BASE_URL="http://localhost:$PORT"
echo -e "  测试目标: ${BLUE}$PLAYWRIGHT_BASE_URL${NC}"

if npx playwright test --reporter=list 2>&1 | tee "$TEST_OUTPUT"; then
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Quality Gate 通过！${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}══════════════════════════════════════════${NC}"
    echo -e "${RED}❌ Quality Gate 失败！${NC}"
    echo -e "${RED}══════════════════════════════════════════${NC}"
    echo -e "${YELLOW}日志: $TEST_OUTPUT${NC}"
    exit 1
fi
