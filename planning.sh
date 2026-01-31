#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

REQ_FILE="my_requirement.md"

if ! command -v claude &> /dev/null; then
  echo -e "${RED}❌ 未找到 claude CLI，请先运行 install.sh 安装依赖${NC}"
  exit 1
fi

if [ -f "$REQ_FILE" ]; then
  echo -e "${YELLOW}⚠️ 检测到 $REQ_FILE 已存在${NC}"
  read -p "是否备份旧文件? [Y/n]: " BACKUP
  if [[ ! "$BACKUP" =~ ^[Nn]$ ]]; then
    TS=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="${REQ_FILE%.txt}_backup_${TS}.txt"
    cp "$REQ_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ 已备份到 $BACKUP_FILE${NC}"
  fi

  read -p "是否覆盖? [y/N]: " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ 已取消${NC}"
    exit 1
  fi
fi

# 初始化/清空需求文件
: > "$REQ_FILE"

echo -e "${CYAN}🚀 启动 Claude Code（交互式）...${NC}"
echo -e "${YELLOW}提示：完成 /brainstorm 后请退出 Claude，脚本会进入下一步。${NC}"

read -r -d '' INITIAL_PROMPT << 'EOF'
你将与我进行交互式需求澄清，并最终输出项目计划。

要求：
1) 请调用 MCP 工具 superpowers 的 /brainstorm 功能来组织你的计划。
2) 你需要先向我提问，直到你认为信息足够完整。
3) 计划必须包含：目标、范围、用户故事、功能清单、非功能需求、边界条件、依赖、风险、里程碑、验收标准、未决问题。
4) 输出简洁但不遗漏关键细节。

现在开始向我提问以收集需求。
EOF

claude "$INITIAL_PROMPT"

# ==========================================
# Step 2: 使用 /write-plan 基于最新 design.md 生成待办清单
# ==========================================

PLAN_DIR="docs/plans"

if [ ! -d "$PLAN_DIR" ]; then
  echo -e "${RED}❌ 未找到 $PLAN_DIR，请先确保 superpowers 已生成 design 文档${NC}"
  exit 1
fi

LATEST_DESIGN_FILE=$(ls -1t "$PLAN_DIR"/*-design.md 2>/dev/null | head -n 1)

if [ -z "$LATEST_DESIGN_FILE" ]; then
  echo -e "${RED}❌ 未找到 design 文档（$PLAN_DIR/*-design.md）${NC}"
  exit 1
fi

echo -e "${GREEN}✓ 最新 design 文件: $LATEST_DESIGN_FILE${NC}"

read -r -d '' WRITE_PLAN_PROMPT << EOF
请使用 superpowers 的 /write-plan 功能调取最新生成的design.md生成待办清单。
设计文档路径：$LATEST_DESIGN_FILE
EOF

echo -e "${CYAN}🚀 启动 Claude Code(交互式)生成待办清单...${NC}"
claude "$WRITE_PLAN_PROMPT"

# ==========================================
# Step 3: 汇总 design + todo 清单到 my_requirement.md
# ==========================================

echo -e "${CYAN}🧾 汇总 plan 文档到 $REQ_FILE...${NC}"

: > "$REQ_FILE"
{
  echo "# Requirements (Aggregated)"
  echo ""
  echo "## Design"
  cat "$LATEST_DESIGN_FILE"
  echo ""
  echo "## Todos (Generated)"
} >> "$REQ_FILE"

# 取最近 1 小时生成的 plan 文件（按生成顺序），排除 design
RECENT_PLAN_FILES=$(find "$PLAN_DIR" -type f -mmin -60 -print0 | xargs -0 ls -tr 2>/dev/null || true)

if [ -n "$RECENT_PLAN_FILES" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ "$f" = "$LATEST_DESIGN_FILE" ]; then
      continue
    fi
    echo "" >> "$REQ_FILE"
    echo "### $(basename "$f")" >> "$REQ_FILE"
    cat "$f" >> "$REQ_FILE"
  done <<< "$RECENT_PLAN_FILES"
fi

# ==========================================
# Step 4: Headless 整理 my_requirement.md
# ==========================================

read -r -d '' CLEANUP_PROMPT << EOF
请读取并整理 $REQ_FILE：
1) 以 $LATEST_DESIGN_FILE 为准核对内容。
2) 删除不正确或不一致的条目。
3) 修正明显错误的计划表述。
4) 保持结构清晰、层级分明。

请输出整理后的完整内容（不要包含额外解释）。
EOF

echo -e "${CYAN}🧹 使用 Claude (headless)整理 $REQ_FILE...${NC}"
claude -p "$CLEANUP_PROMPT" > "$REQ_FILE"
