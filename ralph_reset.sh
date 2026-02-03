#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DEFAULT_REQ_FILE="docs/my_requirements.md"

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local hint="[y/N]"
  if [[ "$default" =~ ^[Yy]$ ]]; then
    hint="[Y/n]"
  fi
  read -p "$prompt $hint: " REPLY
  if [ -z "$REPLY" ]; then
    REPLY="$default"
  fi
  [[ "$REPLY" =~ ^[Yy]$ ]]
}

echo -e "${YELLOW}🔎 正在检索可用项目目录...${NC}"
mapfile -t PROJECT_DIRS < <(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | grep -vE '^(ralph-claude-code|\.claude|\.git)$' | sort)

if [ ${#PROJECT_DIRS[@]} -eq 0 ]; then
  echo -e "${RED}❌ 未找到可用项目目录${NC}"
  exit 1
fi

echo -e "${CYAN}请选择项目目录:${NC}"
for i in "${!PROJECT_DIRS[@]}"; do
  echo "  $((i+1))) ${PROJECT_DIRS[$i]}"
 done

read -p "请输入序号: " SELECT_IDX
if ! [[ "$SELECT_IDX" =~ ^[0-9]+$ ]] || [ "$SELECT_IDX" -lt 1 ] || [ "$SELECT_IDX" -gt ${#PROJECT_DIRS[@]} ]; then
  echo -e "${RED}❌ 无效选择${NC}"
  exit 1
fi

PROJECT_DIR="${PROJECT_DIRS[$((SELECT_IDX-1))]}"
PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)

RALPH_DIR="$PROJECT_DIR/.ralph"
RALPH_RC="$PROJECT_DIR/.ralphrc"
REQ_FILE="$PROJECT_DIR/$DEFAULT_REQ_FILE"
PLAN_DIR="$PROJECT_DIR/docs/plans"
LOGS_DIR="$PROJECT_DIR/logs"
SRC_DIR="$PROJECT_DIR/src"
TESTS_DIR="$PROJECT_DIR/tests"
TEST_DEBUG_DIR="$PROJECT_DIR/test-debug"
GIT_DIR="$PROJECT_DIR/.git"

echo -e "${CYAN}项目目录: $PROJECT_DIR${NC}"

# Part 1: .ralph and .ralphrc
if prompt_yes_no "是否删除 .ralph 文件夹和 .ralphrc?" "n"; then
  if [ -d "$RALPH_DIR" ]; then
    rm -rf "$RALPH_DIR"
    echo -e "${GREEN}✓ 已删除 $RALPH_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $RALPH_DIR${NC}"
  fi

  if [ -f "$RALPH_RC" ]; then
    rm -f "$RALPH_RC"
    echo -e "${GREEN}✓ 已删除 $RALPH_RC${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $RALPH_RC${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Part 1${NC}"
fi

# Part 2: my_requirements.md
ROOT_REQ_FILE="$PROJECT_DIR/my_requirements.md"
if prompt_yes_no "是否删除根目录的 my_requirements.md?" "n"; then
  if [ -f "$ROOT_REQ_FILE" ]; then
    rm -f "$ROOT_REQ_FILE"
    echo -e "${GREEN}✓ 已删除 $ROOT_REQ_FILE${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $ROOT_REQ_FILE${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过根目录 my_requirements.md${NC}"
fi

if prompt_yes_no "是否删除 $DEFAULT_REQ_FILE?" "n"; then
  if [ -f "$REQ_FILE" ]; then
    rm -f "$REQ_FILE"
    echo -e "${GREEN}✓ 已删除 $REQ_FILE${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $REQ_FILE${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Part 2${NC}"
fi

# Part 3: docs/plans
if prompt_yes_no "是否删除 docs/plans 目录?" "n"; then
  if [ -d "$PLAN_DIR" ]; then
    rm -rf "$PLAN_DIR"
    echo -e "${GREEN}✓ 已删除 $PLAN_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $PLAN_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Part 3${NC}"
fi

# Part 4: logs
if prompt_yes_no "是否删除 logs 目录?" "n"; then
  if [ -d "$LOGS_DIR" ]; then
    rm -rf "$LOGS_DIR"
    echo -e "${GREEN}✓ 已删除 $LOGS_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $LOGS_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 logs${NC}"
fi

# Part 5: src
if prompt_yes_no "是否删除 src 目录?" "n"; then
  if [ -d "$SRC_DIR" ]; then
    rm -rf "$SRC_DIR"
    echo -e "${GREEN}✓ 已删除 $SRC_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $SRC_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 src${NC}"
fi

# Part 6: tests
if prompt_yes_no "是否删除 tests 目录?" "n"; then
  if [ -d "$TESTS_DIR" ]; then
    rm -rf "$TESTS_DIR"
    echo -e "${GREEN}✓ 已删除 $TESTS_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $TESTS_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 tests${NC}"
fi

# Part 7: test-debug
if prompt_yes_no "是否删除 test-debug 目录?" "n"; then
  if [ -d "$TEST_DEBUG_DIR" ]; then
    rm -rf "$TEST_DEBUG_DIR"
    echo -e "${GREEN}✓ 已删除 $TEST_DEBUG_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $TEST_DEBUG_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 test-debug${NC}"
fi

# Part 8: .git
if prompt_yes_no "是否删除 .git 目录?" "n"; then
  if [ -d "$GIT_DIR" ]; then
    rm -rf "$GIT_DIR"
    echo -e "${GREEN}✓ 已删除 $GIT_DIR${NC}"
  else
    echo -e "${YELLOW}⚠️ 未找到 $GIT_DIR${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 .git${NC}"
fi
