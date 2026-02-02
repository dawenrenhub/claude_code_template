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
