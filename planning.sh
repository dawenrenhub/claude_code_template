#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DEFAULT_REQ_FILE="my_requirement.md"

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

if ! command -v claude &> /dev/null; then
  echo -e "${RED}❌ 未找到 claude CLI，请先运行 install.sh 安装依赖${NC}"
  exit 1
fi

PROJECT_DIR=""
while [ -z "$PROJECT_DIR" ]; do
  read -p "请输入项目目录(相对或绝对路径): " INPUT_DIR
  if [ -z "$INPUT_DIR" ]; then
    echo -e "${RED}❌ 目录不能为空，请重新输入${NC}"
    continue
  fi
  if [ ! -d "$INPUT_DIR" ]; then
    echo -e "${RED}❌ 目录不存在：$INPUT_DIR${NC}"
    continue
  fi
  PROJECT_DIR=$(cd "$INPUT_DIR" && pwd)
done

REQ_FILE="$PROJECT_DIR/$DEFAULT_REQ_FILE"

echo -e "${CYAN}项目目录: $PROJECT_DIR${NC}"

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
    echo -e "${YELLOW}⚠️ 将保留旧文件并继续${NC}"
    OVERWRITE_ALLOWED=false
  else
    OVERWRITE_ALLOWED=true
  fi
else
  OVERWRITE_ALLOWED=true
fi

if prompt_yes_no "是否执行 Step 1: /brainstorm 需求澄清?" "y"; then
  echo -e "${CYAN}🚀 启动 Claude Code（交互式）...${NC}"
  echo -e "${YELLOW}提示：完成 /brainstorm 后请退出 Claude，脚本会进入下一步。${NC}"

  if ! (cd "$PROJECT_DIR" && claude "$(cat <<EOF
项目路径：$PROJECT_DIR

请基于该目录自行判断是否已有项目内容；如果内容很少或几乎为空，请按新项目流程处理。

你将与我进行交互式需求澄清，并最终输出项目计划。

要求：
1) 请调用 MCP 工具 superpowers 的 /brainstorm 功能来组织你的计划。
2) 你需要先向我提问，直到你认为信息足够完整。
3) 计划必须包含：目标、范围、用户故事、功能清单、非功能需求、边界条件、依赖、风险、里程碑、验收标准、未决问题。
4) 输出简洁但不遗漏关键细节。

现在开始向我提问以收集需求。
EOF
 )" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi

  read -p "是否已完成 /brainstorm 并生成 design 文档? [y/N]: " BRAINSTORM_DONE
  if [[ ! "$BRAINSTORM_DONE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️ 未完成 /brainstorm，已退出。请完成后重新运行脚本。${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 1${NC}"
fi

prepare_design_context() {
  PLAN_DIR="$PROJECT_DIR/docs/plans"
  mkdir -p "$PLAN_DIR"

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
}

RUN_STEP2=false
RUN_STEP3=false
RUN_STEP4=false

if prompt_yes_no "是否执行 Step 2: /write-plan 生成待办清单?" "y"; then
  RUN_STEP2=true
fi
if prompt_yes_no "是否执行 Step 3: 汇总 design + todo?" "y"; then
  RUN_STEP3=true
fi
if prompt_yes_no "是否执行 Step 4: Headless 整理需求文件?" "y"; then
  RUN_STEP4=true
fi

if $RUN_STEP2 || $RUN_STEP3 || $RUN_STEP4; then
  prepare_design_context
fi

if $RUN_STEP2; then
  echo -e "${CYAN}🚀 启动 Claude Code(交互式)生成待办清单...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<EOF
请使用 superpowers 的 /write-plan 功能调取最新生成的design.md生成待办清单。
设计文档路径：$LATEST_DESIGN_FILE
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 2${NC}"
fi

# ==========================================
# Step 3: 汇总 design + todo 清单到 my_requirement.txt
# ==========================================

if $RUN_STEP3; then
  echo -e "${CYAN}🧾 汇总 plan 文档到 $REQ_FILE...${NC}"

  if [ -f "$REQ_FILE" ] && [ "${OVERWRITE_ALLOWED:-true}" != "true" ]; then
    if prompt_yes_no "检测到 $REQ_FILE 已存在，是否追加内容?" "y"; then
      :
    else
      TS=$(date +"%Y%m%d_%H%M%S")
      REQ_FILE="$PROJECT_DIR/my_requirement_${TS}.txt"
      echo -e "${YELLOW}将写入新文件: $REQ_FILE${NC}"
    fi
  else
    : > "$REQ_FILE"
  fi
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
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 3${NC}"
fi

# ==========================================
# Step 4: Headless 整理 my_requirement.txt
# ==========================================

if $RUN_STEP4; then
  if [ ! -f "$REQ_FILE" ]; then
    echo -e "${RED}❌ 未找到 $REQ_FILE，无法整理。请先执行 Step 3 或手动准备该文件${NC}"
    exit 1
  fi

  if [ "${OVERWRITE_ALLOWED:-true}" != "true" ]; then
    if ! prompt_yes_no "Step 4 将覆盖 $REQ_FILE 的内容，是否继续?" "n"; then
      echo -e "${YELLOW}⏭️ 已跳过 Step 4${NC}"
      exit 0
    fi
  fi

  CLEANUP_PROMPT=$(cat <<EOF
请读取并整理 $REQ_FILE：
1) 以 $LATEST_DESIGN_FILE 为准核对内容。
2) 删除不正确或不一致的条目。
3) 修正明显错误的计划表述。
4) 保持结构清晰、层级分明。

请输出整理后的完整内容（不要包含额外解释）。
EOF
)

  echo -e "${CYAN}🧹 使用 Claude (headless)整理 $REQ_FILE...${NC}"
  claude -p "$CLEANUP_PROMPT" > "$REQ_FILE"
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 4${NC}"
fi
