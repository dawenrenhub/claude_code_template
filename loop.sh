#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

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

PROJECT_NAME="${PROJECT_DIRS[$((SELECT_IDX-1))]}"

cd "$PROJECT_NAME"

echo -e "${GREEN}✓ 已进入项目目录：$PROJECT_NAME${NC}"

# 启动自动开发
ralph --monitor
