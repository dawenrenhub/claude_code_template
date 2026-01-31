#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

read -p "请输入要 Ralph Loop 的项目目录名: " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo -e "${RED}❌ 项目目录名不能为空${NC}"
  exit 1
fi

if [ ! -d "$PROJECT_NAME" ]; then
  echo -e "${RED}❌ 目录不存在：$PROJECT_NAME${NC}"
  exit 1
fi

REQ_FILE="$PROJECT_NAME/my-requirements.md"
if [ ! -f "$REQ_FILE" ]; then
  echo -e "${RED}❌ 未找到需求文件：$REQ_FILE${NC}"
  exit 1
fi

echo -e "${YELLOW}▶ 执行: ralph-import $REQ_FILE $PROJECT_NAME${NC}"
ralph-import "$REQ_FILE" "$PROJECT_NAME"

cd "$PROJECT_NAME"

echo -e "${GREEN}✓ 已进入项目目录：$PROJECT_NAME${NC}"

# 启动自动开发
ralph --monitor
