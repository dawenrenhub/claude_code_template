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

rel_path() {
  local target="$1"
  if command -v realpath &>/dev/null; then
    realpath --relative-to="$PWD" "$target"
  else
    echo "$target"
  fi
}

render_prompt() {
  local template="$1"
  template=${template//__PROJECT_DIR__/$PROJECT_DIR}
  template=${template//__LATEST_DESIGN_FILE__/$LATEST_DESIGN_FILE}
  template=${template//__REQ_FILE__/$REQ_FILE}
  echo "$template"
}

if ! command -v claude &> /dev/null; then
  echo -e "${RED}❌ 未找到 claude CLI，请先运行 install.sh 安装依赖${NC}"
  exit 1
fi

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

REQ_FILE="$PROJECT_DIR/$DEFAULT_REQ_FILE"
mkdir -p "$(dirname "$REQ_FILE")"

echo -e "${CYAN}项目目录: $PROJECT_DIR${NC}"

if [ -f "$REQ_FILE" ]; then
  echo -e "${YELLOW}⚠️ 检测到 $REQ_FILE 已存在${NC}"
  read -p "是否备份旧文件? [Y/n]: " BACKUP
  if [[ ! "$BACKUP" =~ ^[Nn]$ ]]; then
    TS=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="${REQ_FILE%.*}_backup_${TS}.${REQ_FILE##*.}"
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

if prompt_yes_no "是否生成项目文档 Finished.md?" "n"; then
  FINISHED_FILE="$PROJECT_DIR/Finished.md"
  MAX_ITERATIONS=20
  ITERATION=0

  # 如果文件不存在，创建空文件
  if [ ! -f "$FINISHED_FILE" ]; then
    touch "$FINISHED_FILE"
    echo -e "${GREEN}✓ 已创建 $FINISHED_FILE${NC}"
  fi

  echo -e "${CYAN}🔄 启动 Claude Code（headless）生成项目文档...${NC}"
  echo -e "${YELLOW}提示：Claude 将自动遍历项目并生成文档，最多 $MAX_ITERATIONS 次迭代。${NC}"

  while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    ITERATION=$((ITERATION + 1))
    echo -e "${CYAN}📝 迭代 $ITERATION/$MAX_ITERATIONS...${NC}"

    if ! (cd "$PROJECT_DIR" && claude --print "$(cat <<'EOF'
你是一个项目文档生成专家。你的任务是逐步完善 Finished.md 文件，直到项目文档完成。

首先读取 Finished.md 的当前内容。

然后根据以下规则决定你的行动：

## 规则 1：如果 Finished.md 为空或没有目录结构
遍历项目目录，识别出项目的核心部分（忽略以下非项目内容）：
- 配置文件目录：.git, .ralph, .vscode, .idea, node_modules, __pycache__, .cache
- 构建输出：dist, build, out, target, .next
- 依赖锁文件：package-lock.json, pnpm-lock.yaml, poetry.lock, Cargo.lock
- 环境文件：.env*, *.log

生成一个清晰的目录结构，格式如下：
\`\`\`
# 项目文档：[项目名称]

## 目录

1. [ ] 项目概述
2. [ ] 核心架构
3. [ ] [根据实际项目内容动态生成章节...]
4. [ ] API/接口说明（如果有）
5. [ ] 数据模型（如果有）
6. [ ] 部署与运维
7. [ ] 项目总结
\`\`\`

将这个目录写入 Finished.md，然后停止（不要继续写内容）。

## 规则 2：如果 Finished.md 已有目录，但有未完成的章节
找到第一个标记为 \`[ ]\` 的章节（未完成），然后：
1. 深入阅读项目中与该章节相关的源代码、配置文件、文档
2. 在该章节标题下写出详细内容（300-800字），包括：
   - 相关文件路径
   - 核心逻辑/功能说明
   - 代码片段示例（如果有意义）
   - 注意事项
3. 将该章节的 \`[ ]\` 改为 \`[x]\`，表示已完成
4. 只完成这一个章节，然后停止

## 规则 3：如果所有章节都已标记为 \`[x]\`
在文档末尾添加：
1. 一个"项目总结"段落（200-400字），概括整个项目的核心价值和技术亮点
2. 最后一行单独写：

FINISHED!!!

## 输出要求
- 直接修改 Finished.md 文件
- 每次只完成一个章节的内容
- 保持 Markdown 格式整洁
- 如果遇到空项目或无实际代码，在项目概述中说明，然后直接完成所有章节并输出 FINISHED!!!
EOF
)" ); then
      echo -e "${RED}❌ Claude CLI 执行失败${NC}"
      break
    fi

    # 检查是否已完成
    if grep -q "FINISHED!!!" "$FINISHED_FILE" 2>/dev/null; then
      echo -e "${GREEN}✅ 项目文档生成完成！${NC}"
      echo -e "${CYAN}📄 文档位置: $FINISHED_FILE${NC}"
      break
    fi

    # 短暂暂停避免频繁调用
    sleep 2
  done

  if [ $ITERATION -ge $MAX_ITERATIONS ] && ! grep -q "FINISHED!!!" "$FINISHED_FILE" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ 已达到最大迭代次数 ($MAX_ITERATIONS)，文档可能未完全生成${NC}"
    echo -e "${YELLOW}   你可以手动检查 $FINISHED_FILE 并继续编辑${NC}"
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Finished.md 生成${NC}"
fi

if prompt_yes_no "是否执行 Step 1: /brainstorm 需求澄清?" "y"; then
  echo -e "${CYAN}🚀 启动 Claude Code（交互式）...${NC}"
  echo -e "${YELLOW}提示：完成 /brainstorm 后请退出 Claude，脚本会进入下一步。${NC}"

  BRAINSTORM_PROMPT=$(cat <<'EOF'
项目路径：__PROJECT_DIR__

  请先判断这是不是一个新项目，并按以下步骤执行：

  1) 先与我确认：这是新项目还是已有项目？
  2) 如果不是新项目：
    - 先检查是否存在 Finished.md；如果没有，则检查 README.md；
    - 如果 README.md 也不足以判断项目状况，请浏览整个项目目录结构（只需目录/文件名级别）以大致了解项目现状；
    - 基于你能获取的信息，简要总结当前项目状态与已完成度。
  3) 然后再进入需求澄清与计划输出流程。

  你将与我进行交互式需求澄清，并最终输出项目计划。

  要求：
  1) 请调用 MCP 工具 superpowers 的 /brainstorm 功能来组织你的计划。
  2) 你需要先向我提问，直到你认为信息足够完整。
  3) 计划必须包含：目标、范围、用户故事、功能清单、非功能需求、边界条件、依赖、风险、里程碑、验收标准、未决问题。
  4) 输出简洁但不遗漏关键细节。

  现在开始向我提问以收集需求。
EOF
)
  BRAINSTORM_PROMPT=$(render_prompt "$BRAINSTORM_PROMPT")
  if ! (cd "$PROJECT_DIR" && claude "$BRAINSTORM_PROMPT" ); then
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
  WRITE_PLAN_PROMPT=$(cat <<'EOF'
请使用 superpowers 的 /write-plan 功能调取最新生成的design.md生成待办清单。
设计文档路径：__LATEST_DESIGN_FILE__
EOF
)
  WRITE_PLAN_PROMPT=$(render_prompt "$WRITE_PLAN_PROMPT")
  if ! (cd "$PROJECT_DIR" && claude "$WRITE_PLAN_PROMPT" ); then
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
      REQ_FILE="$PROJECT_DIR/docs/my_requirements_${TS}.md"
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

  # 取与最新 design 文件同一前缀（第四段）的一组 plan 文件（按生成顺序），排除 design
  LATEST_BASE=$(basename "$LATEST_DESIGN_FILE")
  IFS='-' read -r _ _ _ PREFIX4 _ <<< "$LATEST_BASE"
  if [ -n "$PREFIX4" ]; then
    RECENT_PLAN_FILES=$(find "$PLAN_DIR" -type f -name "*-${PREFIX4}-*.md" -print0 | xargs -0 -r ls -tr 2>/dev/null || true)
  else
    RECENT_PLAN_FILES=""
  fi

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
  echo -e "${GREEN}✓ 已完成整理并输出到 $REQ_FILE${NC}"
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 4${NC}"
fi

# ==========================================
# Step 5: 可选 ralph-import 导入需求
# ==========================================

if prompt_yes_no "是否执行 ralph-import 导入需求?" "y"; then
  if [ ! -f "$REQ_FILE" ]; then
    echo -e "${RED}❌ 未找到需求文件：$REQ_FILE${NC}"
    exit 1
  fi
  REL_REQ_FILE=$(rel_path "$REQ_FILE")
  REL_PROJECT_DIR=$(rel_path "$PROJECT_DIR")
  echo -e "${YELLOW}▶ 执行: ralph-import $REL_REQ_FILE $REL_PROJECT_DIR${NC}"
  ralph-import "$REL_REQ_FILE" "$REL_PROJECT_DIR"
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 5${NC}"
fi

# ==========================================
# Step 6: 检查 ralph-import 结果
# ==========================================

if prompt_yes_no "是否检查 ralph-import 结果?" "y"; then
  echo -e "${CYAN}🔍 检查 ralph-import 结果...${NC}"
  
  IMPORT_PROJECT_DIR="$PROJECT_DIR"
  CHECK_PASSED=true
  
  # 检查 1: .ralph 文件夹及其必要内容
  echo -e "${CYAN}  检查 .ralph 文件夹...${NC}"
  RALPH_DIR="$IMPORT_PROJECT_DIR/.ralph"
  if [ -d "$RALPH_DIR" ]; then
    echo -e "${GREEN}    ✓ .ralph 目录存在${NC}"
    
    # 检查必要文件
    REQUIRED_FILES=("AGENT.md" "PROMPT.md" "fix_plan.md")
    for f in "${REQUIRED_FILES[@]}"; do
      if [ -f "$RALPH_DIR/$f" ]; then
        echo -e "${GREEN}    ✓ $f${NC}"
      else
        echo -e "${RED}    ✗ 缺少 $f${NC}"
        CHECK_PASSED=false
      fi
    done
    
    # 检查必要目录
    REQUIRED_DIRS=("docs" "examples" "logs" "specs")
    for d in "${REQUIRED_DIRS[@]}"; do
      if [ -d "$RALPH_DIR/$d" ]; then
        echo -e "${GREEN}    ✓ $d/${NC}"
      else
        echo -e "${RED}    ✗ 缺少 $d/${NC}"
        CHECK_PASSED=false
      fi
    done
  else
    echo -e "${RED}    ✗ .ralph 目录不存在${NC}"
    CHECK_PASSED=false
  fi
  
  # 检查 2: .ralphrc 文件
  echo -e "${CYAN}  检查 .ralphrc 文件...${NC}"
  if [ -f "$IMPORT_PROJECT_DIR/.ralphrc" ]; then
    echo -e "${GREEN}    ✓ .ralphrc 存在${NC}"
  else
    echo -e "${RED}    ✗ .ralphrc 不存在${NC}"
    CHECK_PASSED=false
  fi
  
  # 检查 3: src 文件夹
  echo -e "${CYAN}  检查 src 文件夹...${NC}"
  if [ -d "$IMPORT_PROJECT_DIR/src" ]; then
    echo -e "${GREEN}    ✓ src 目录存在${NC}"
  else
    echo -e "${RED}    ✗ src 目录不存在${NC}"
    CHECK_PASSED=false
  fi
  
  # 汇总结果
  echo ""
  if $CHECK_PASSED; then
    echo -e "${GREEN}✓ 所有检查通过${NC}"
  else
    echo -e "${RED}✗ 部分检查未通过，请检查 ralph-import 是否正确执行${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 6${NC}"
fi

# ==========================================
# Step 7: 审计 .ralph/PROMPT.md
# ==========================================

if prompt_yes_no "是否审计 .ralph/PROMPT.md?" "y"; then
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  if [ ! -f "$PROMPT_FILE" ]; then
   echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
   exit 1
  fi

  echo -e "${CYAN}🧾 启动 Claude Code（交互式）审计 PROMPT.md...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务分为两步：
1. 审查 .ralph/PROMPT.md，输出审计报告
2. 等待我的指示，再决定是否执行修改

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

读取 .ralph/PROMPT.md 的完整内容，同时读取 .ralph/AGENT.md 作为测试命令对照，按以下 9 项检查标准逐一评估。每项评为 ✅ PASS 或 ❌ FAIL。FAIL 项必须附带具体的修改建议——给出建议添加或替换的实际文本内容，而不是笼统的描述。

检查项：

1. **阶段化结构 (Phase Structure)**
  PROMPT.md 必须包含明确的阶段划分：
  - Phase 0: 定向阅读（读取 fix_plan.md、specs/、AGENT.md、现有代码）
  - Phase 1: 任务选择与实现
  - Phase 2: 验证（运行测试/lint/build）
  - Phase 3: 进度更新（标记完成、commit）
  - Phase 999: 护栏规则
  如果文件是扁平结构、没有分阶段，判定 FAIL。

2. **单任务约束 (One Task Per Iteration)**
  PROMPT.md 必须包含明确指令：每次迭代只从 fix_plan.md 选择并完成一个任务。
  如果存在"尽可能多完成"、"批量处理"等表述，或完全没提及任务数量限制，判定 FAIL。

3. **反压机制 (Backpressure)**
  PROMPT.md 必须要求在每次实现后运行验证命令（测试、lint、类型检查、构建），且必须明确声明"验证不通过不能标记任务完成、不能提交"。
  如果只笼统提及"写测试"但没有要求运行验证，或没有"验证通过才能标记完成"的硬约束，判定 FAIL。

3b. **硬性门禁与例外机制 (Hard Gate + Escape Hatch)**
  PROMPT.md 必须明确：
  - 测试未通过 → 禁止更新 fix_plan.md 为完成、禁止提交
  - 若因环境/依赖导致无法通过测试 → 允许标记为 [BLOCKED] 并记录原因
  如果只强调“测试必须通过”但没有失败兜底，判定 FAIL。

4. **文件引用完整性 (File References)**
  PROMPT.md 必须引用以下文件：
  - @fix_plan.md 或 fix_plan.md（任务列表）
  - @specs/ 或 specs/ 目录（需求规格）
  - @AGENT.md 或 AGENT.md（构建/测试命令）
  缺少任何一个引用，判定 FAIL。

5. **防假设护栏 (Anti-Assumption Guard)**
  PROMPT.md 必须包含类似"不要假设功能缺失，先搜索现有代码确认"的指令。
  如果没有任何防止 Claude 重复实现已有功能的指令，判定 FAIL。

6. **卡住处理策略 (Stuck Handling)**
  PROMPT.md 必须包含当任务无法完成时的处理策略，例如：
  - 同一任务尝试 N 次后跳过
  - 记录阻塞原因到 fix_plan.md
  - 尝试替代方案
  如果完全没有卡住时的 fallback 策略，判定 FAIL。

7. **Commit 规范 (Commit Convention)**
  PROMPT.md 必须要求每完成一个任务执行 git commit，且 commit message 需描述 what 和 why。
  如果没有提及 commit 行为，判定 FAIL。

8. **无主观/开放式指令 (No Subjective Instructions)**
  PROMPT.md 不应包含无法自动验证的主观指令，例如：
  - "写出优雅的代码"
  - "确保良好的代码质量"
  - "优化性能"（无具体指标）
  如果存在此类指令，判定 FAIL 并建议替换为可衡量的标准。

9. **测试指令覆盖与一致性 (Testing Coverage & Consistency)**
  PROMPT.md 必须明确说明测试策略与调用来源，并与 AGENT.md 中的验证命令一致：
  - 如果 AGENT.md 定义了 test:unit/test:e2e/pytest 等命令，PROMPT.md 需明确要求运行对应测试类别
  - 如果 PROMPT.md 提到具体测试命令（如 pnpm test:unit），必须与 AGENT.md 中命令一致
  - 若项目包含前后端，PROMPT.md 需明确分别验证前端与后端
  若存在缺失或不一致，判定 FAIL。

输出要求：

先输出一张汇总表，格式如下：

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | 阶段化结构 | ✅/❌ | 一句话说明 |
| ... | ... | ... | ... |

总评: X/9 通过

然后针对每个 FAIL 项，在表格下方逐项给出具体修改建议。修改建议必须是可以直接插入或替换到 PROMPT.md 中的实际文本，不要只写"建议添加阶段结构"这种笼统描述。

所有修改建议必须给出"建议插入位置"和"可直接粘贴的文本"。

⚠️ 格式保持规则：所有修改建议必须延续 PROMPT.md 现有的格式风格（标题层级、列表风格、缩进方式、语言等）。如果原文用 `##` 做标题就用 `##`，如果原文用 `-` 做列表就用 `-`，如果原文是英文就写英文。不要引入原文中没有的格式元素。

输出审计报告后，问我：

> 以上是审计结果。你可以：
> 1. 输入 **"执行全部"** — 我将按上述建议修改 PROMPT.md
> 2. 输入 **"执行 1,3,5"** — 只执行指定编号的修改建议
> 3. 告诉我你想怎么改 — 我会根据你的要求调整建议后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要做任何文件修改。
EOF
)" ); then
   echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
   exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 7${NC}"
fi

# ==========================================
# Step 8: 审计 .ralph/fix_plan.md
# ==========================================

if prompt_yes_no "是否审计 .ralph/fix_plan.md?" "y"; then
  FIX_PLAN_FILE="$PROJECT_DIR/.ralph/fix_plan.md"
  SPECS_DIR="$PROJECT_DIR/.ralph/specs"

  if [ ! -f "$FIX_PLAN_FILE" ]; then
   echo -e "${RED}❌ 未找到 $FIX_PLAN_FILE${NC}"
   exit 1
  fi
  if [ ! -d "$SPECS_DIR" ]; then
   echo -e "${RED}❌ 未找到 $SPECS_DIR${NC}"
   exit 1
  fi

  echo -e "${CYAN}🧾 启动 Claude Code（交互式）审计 fix_plan.md...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务分为两步：
1. 审查 .ralph/fix_plan.md，输出审计报告
2. 等待我的指示，再决定是否执行修改

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

读取 .ralph/fix_plan.md 的完整内容，同时读取 .ralph/specs/ 目录下的所有文件作为上下文参考（用于判断任务是否覆盖了需求）。按以下 9 项检查标准逐一评估，每项评为 ✅ PASS 或 ❌ FAIL。FAIL 项必须附带具体的修改建议。

检查项：

1. **Checkbox 格式 (Checkbox Format)**
  仅检查任务行（以 `-` 开头的条目）。所有任务必须使用 `- [ ]` 格式。Ralph 通过 grep 检测 `[x]` 来判断任务完成状态，其他格式（数字编号、纯文本列表、`TODO:`标记等）会导致 Ralph 无法追踪进度。
  如果存在不使用 `- [ ]` 格式的任务项，判定 FAIL。

2. **任务原子性 (Task Atomicity)**
  每个任务必须可在单次 Claude Code 迭代中完成（约 15-60 分钟工作量）。判断标准：
  - 一个任务只做一件事，用一句话能描述清楚且不需要用"和"连接多个动作
  - 如果一个任务包含"实现用户注册和登录"这类复合描述，它应该被拆成多个任务
  - 如果一个任务描述的是一个完整功能模块（如"实现认证系统"），它的粒度太大
  逐条检查每个任务，列出所有粒度过大的任务，判定 FAIL。

3. **任务排序 (Task Ordering)**
  任务必须按依赖关系排序，推荐顺序为：
  基础设施/项目结构 → 数据层/模型 → 核心业务逻辑 → API/接口层 → 测试补全 → 文档收尾
  如果存在明显的依赖倒挂（如 API 端点排在数据模型之前、UI 排在业务逻辑之前），判定 FAIL。

4. **可验证的完成标准 (Verifiable Completion Criteria)**
  每个任务应当具备隐含或显式的完成判定方式——即完成后能通过运行测试、构建或查看输出来确认。
  如果存在无法自动验证的任务（如"研究最佳实践"、"设计架构方案"、"选择合适的库"），判定 FAIL。

5. **无外部依赖任务 (No External Dependency Tasks)**
  所有任务必须可在当前开发环境中独立完成，不依赖：
  - 需要人工申请的 API key 或第三方服务凭证
  - 需要人工决策的架构选型或 UI/UX 审美判断
  - 需要访问外部数据库或远程服务
  如果存在此类任务，判定 FAIL，建议将其标注为 `[MANUAL]` 或移除并记录到单独的 backlog 文件。

6. **无重复/冗余任务 (No Duplicate/Redundant Tasks)**
  检查是否存在实质相同但措辞不同的重复任务，或被更大范围任务已覆盖的冗余子任务。
  如果存在，判定 FAIL，列出重复项。

7. **无开放式任务 (No Open-Ended Tasks)**
  不应包含会导致无限循环的开放式任务，例如：
  - "确保所有测试通过"（测试运行属于 PROMPT.md 的验证阶段，不是任务）
  - "优化代码质量"（无明确终止条件）
  - "重构以提高可维护性"（主观判断，无法自动验证完成）
  如果存在此类任务，判定 FAIL。

8. **需求覆盖度 (Requirements Coverage)**
  将 fix_plan.md 中的任务与 specs/ 目录下的需求文件进行交叉对比。找出：
  - specs 中定义了但 fix_plan.md 中没有对应任务的需求
  - fix_plan.md 中出现但 specs 中没有依据的任务（可能是幻觉任务）
  如果存在明显的遗漏或无依据任务，判定 FAIL，列出具体差异。

9. **任务总量合理性 (Total Task Count)**
  任务总数应与项目规模匹配。经验参考：
  - 小型项目（<5 个源文件）：10-25 个任务
  - 中型项目（5-20 个源文件）：25-60 个任务
  - 大型项目（20+ 个源文件）：60-120 个任务
  如果当前项目尚无源码或为空仓，忽略该项或改为基于“预期规模”的估计，并说明依据。若任务太少（可能粒度过大）或太多（可能过度拆分导致上下文碎片化），给出警告。此项不判定硬性 FAIL，但需在说明中标注风险。

输出要求：

先输出一张汇总表：

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | Checkbox 格式 | ✅/❌ | 一句话说明 |
| ... | ... | ... | ... |

总评: X/9 通过

然后针对每个 FAIL 项，在表格下方逐项给出具体修改建议。修改建议必须是可以直接插入或替换到 fix_plan.md 中的实际文本（例如拆分后的具体任务列表、重新排序后的任务顺序），不要只写"建议拆分任务"这种笼统描述。

⚠️ 格式保持规则：所有修改建议必须延续 fix_plan.md 现有的格式风格（标题层级、列表风格、缩进方式、语言等）。如果原文用 `##` 做标题就用 `##`，如果原文用 `-` 做列表就用 `-`，如果原文是英文就写英文。不要引入原文中没有的格式元素。除非我明确要求，否则尽量不要改动原文件格式。

输出审计报告后，问我：

> 以上是审计结果。你可以：
> 1. 输入 **"执行全部"** — 我将按上述建议修改 fix_plan.md
> 2. 输入 **"执行 1,3,5"** — 只执行指定编号的修改建议
> 3. 告诉我你想怎么改 — 我会根据你的要求调整建议后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要做任何文件修改。
EOF
)" ); then
   echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
   exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 8${NC}"
fi

# ==========================================
# Step 9: 审查与补全 .ralph/specs/
# ==========================================

if prompt_yes_no "是否审查与补全 .ralph/specs/?" "y"; then
  SPECS_DIR="$PROJECT_DIR/.ralph/specs"
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  FIX_PLAN_FILE="$PROJECT_DIR/.ralph/fix_plan.md"

  if [ ! -d "$SPECS_DIR" ]; then
    echo -e "${RED}❌ 未找到 $SPECS_DIR${NC}"
    exit 1
  fi
  if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$FIX_PLAN_FILE" ]; then
    echo -e "${RED}❌ 未找到 $FIX_PLAN_FILE${NC}"
    exit 1
  fi

  echo -e "${CYAN}🧾 启动 Claude Code（交互式）审查 specs...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务是审查并补全 .ralph/specs/ 目录。整个过程分为三个阶段，严格按顺序执行。

⚠️ 在我明确说"执行"之前，禁止修改或创建任何文件。

---

## 阶段一：现状评估

读取以下内容：
- .ralph/specs/ 目录下的所有文件（完整读取内容）
- .ralph/fix_plan.md（完整读取内容）
- .ralph/PROMPT.md（完整读取内容）
- 项目根目录下的源代码结构（ls -R 或 tree，只看目录和文件名，不读内容；若目录很大，仅列出前 2-3 层或关键目录）

然后回答以下问题：

1. specs/ 目录下目前有哪些文件？逐个列出文件名和一句话内容摘要。
2. 除了 requirements.md 之外，是否存在其他 spec 文件？
3. 根据 requirements.md 和 fix_plan.md 的内容，这个项目需要哪些额外的 spec 文件？

从以下候选列表中评估哪些适用于当前项目（不适用的标注 N/A 并说明原因）：
- data_models.md — 数据模型定义：实体、字段、类型、约束、关系
- api_spec.md — API 端点契约：路径、方法、请求/响应格式、错误响应
- auth_spec.md — 认证授权：流程、token 格式、权限模型
- error_handling.md — 错误处理：错误码、消息格式、重试策略
- test_strategy.md — 测试策略：覆盖目标、测试类型、关键测试场景

如果项目需要上述列表之外的 spec 文件，也一并提出。

输出评估结果后，问我：

> 以上是我评估出的需要补充的 spec 文件列表。你可以：
> 1. 输入 **"继续"** — 我将按顺序逐个生成这些文件
> 2. 告诉我要增减哪些文件 — 我会调整列表
> 3. 输入 **"跳过"** — 不补充任何文件，直接跳到阶段三

等待我的回复后再进入阶段二。

---

## 阶段二：逐个生成 spec 文件

按阶段一确认的文件列表，每次只生成一个文件。对于每个文件：

### 信息收集
在撰写文件内容之前，先检查以下信息源：
- .ralph/specs/requirements.md 中与该主题相关的内容
- .ralph/fix_plan.md 中与该主题相关的任务
- 项目现有源代码中与该主题相关的实现（如已有部分代码）

### 不确定时的处理规则
- 如果能从上述信息源中推导出答案，直接使用
- 如果信息源中找不到答案，**禁止猜测**，必须向我提问，列出你不确定的具体问题，等我回答后再继续
- 问题要具体，例如"用户表是否需要 email 字段？"而不是"请描述数据模型"

### 输出格式
生成完文件内容后，输出：
1. 文件完整内容（可直接写入的版本）
2. 不确定/需要确认的地方用 `[待确认: ...]` 标记

在我明确说“执行”之前，不要修改或创建任何文件。

然后问我：

> 以上是 specs/{文件名} 的内容。你可以：
> 1. 输入 **"执行"** — 我将创建这个文件
> 2. 告诉我要修改的地方 — 我会调整后重新展示
> 3. 输入 **"跳过"** — 不创建这个文件

⚠️ 格式保持规则：新建文件的格式应与 specs/requirements.md 保持一致（标题层级、列表风格、缩进方式、语言）。除非我明确要求，否则尽量不要改动原文件格式。

每个文件我确认"执行"后，创建该文件，然后说"Done 后我继续生成下一个文件"。等我输入 Done 后再开始下一个文件。

重复此流程直到列表中所有文件处理完毕，然后自动进入阶段三。

---

## 阶段三：在 PROMPT.md 中添加 specs 索引

所有 spec 文件处理完毕后，执行以下操作：

读取 .ralph/PROMPT.md，找到 Phase 0（定向阅读阶段）的位置。specs 索引应插入到 Phase 0 中，具体位置规则：
- 如果 Phase 0 中已有读取 fix_plan.md 的指令，将 specs 索引插入到该指令之后、Phase 1 之前
- 如果 Phase 0 中没有 fix_plan.md，但有其他阅读清单，将 specs 索引插入到该阅读清单之后、Phase 1 之前
- 如果 Phase 0 中没有明确的子步骤编号，将 specs 索引作为 Phase 0 的最后一个子步骤
- 如果 PROMPT.md 中没有 Phase 0 结构，将 specs 索引插入到文件最前面的指令部分

原因：Phase 0 是每次迭代的起点，Claude 需要先了解全局需求再选择任务。specs 索引放在读取 fix_plan.md 之后，是因为 Claude 应先知道"要做什么任务"，再根据任务去查阅"对应的需求细节"。放在 Phase 1 之前，确保 Claude 在开始实现之前已经有完整的上下文。

索引格式示例（根据实际生成的文件调整）：
读取 specs/ 目录中与当前任务相关的文件：

specs/requirements.md — 高层需求概述
specs/data_models.md — 数据模型：实体、字段、关系
specs/api_spec.md — API 端点：路径、方法、请求/响应格式
specs/auth_spec.md — 认证授权：流程、token、权限
specs/error_handling.md — 错误处理：错误码、消息格式
specs/test_strategy.md — 测试策略：覆盖目标、关键场景
根据当前任务选择相关的 spec 文件阅读，不需要每次全部读取。
展示你计划插入的内容和插入位置（显示上下文前后各几行），然后问我：

> 以上是我计划在 PROMPT.md 中插入的 specs 索引。你可以：
> 1. 输入 **"执行"** — 我将修改 PROMPT.md
> 2. 告诉我要调整的地方 — 我会修改后重新展示
> 3. 输入 **"跳过"** — 不修改 PROMPT.md

在收到我的回复前，不要修改 PROMPT.md。
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 9${NC}"
fi

# ==========================================
# Step 10: 审计 .ralph/AGENT.md
# ==========================================

if prompt_yes_no "是否审计 AGENT.md?" "y"; then
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  AGENT_FILE="$PROJECT_DIR/.ralph/AGENT.md"

  if [ ! -f "$PROMPT_FILE" ]; then
   echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
   exit 1
  fi

  if [ ! -f "$AGENT_FILE" ]; then
   echo -e "${RED}❌ 未找到 $AGENT_FILE${NC}"
   exit 1
  fi

  echo -e "${CYAN}🧾 启动 Claude Code（交互式）审计 AGENT.md...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务分为两步：
1. 审查 .ralph/AGENT.md，输出审计报告
2. 等待我的指示，再决定是否执行修改

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

读取 .ralph/AGENT.md 的完整内容。同时读取 .ralph/PROMPT.md 作为交叉参考。

按以下 8 项检查标准逐一评估，每项评为 ✅ PASS 或 ❌ FAIL。FAIL 项必须附带具体的修改建议。

检查项：

1. **文件存在性 (File Exists)**
  项目中必须存在 .ralph/AGENT.md，且 PROMPT.md 中引用的文件名必须与实际文件名一致。
  例如 PROMPT.md 写了"读取 @AGENT.md"但实际文件在其他位置，判定 FAIL。
  如果文件完全不存在，判定 FAIL，后续检查项全部标记为"无法评估，依赖检查项 1"。

2. **验证命令完整性 (Validation Commands)**
  AGENT.md 必须包含项目所需的全部验证命令。首先检测项目结构：

  **2a. 包管理器一致性检查**：
  - 检查是否存在 pnpm-lock.yaml → 必须使用 pnpm 命令（不是 npm/yarn）
  - 检查是否存在 yarn.lock → 必须使用 yarn 命令（不是 npm/pnpm）
  - 检查是否存在 package-lock.json → 使用 npm 命令
  - 如果 AGENT.md 中的命令与实际包管理器不匹配（如项目用 pnpm 但写了 npm test），判定 FAIL

  **2b. 前后端分离项目检查**：
  如果项目包含 frontend/ 和 backend/ 目录（或类似结构），必须分别检查：
  - **前端**：测试命令（pnpm test:unit, pnpm test:e2e）、Lint、类型检查、构建、开发服务器启动命令（pnpm dev）
  - **后端**：测试命令（pytest）、Lint（ruff）、类型检查（mypy）、启动命令（uvicorn 或 python -m）
  - **数据库迁移**：如果存在 alembic/ 目录或 alembic.ini，必须包含迁移命令（如 cd backend && alembic upgrade head）

  **2c. 验证命令类型**：
  视项目类型可能包括：
  - 单元测试命令（如 pnpm test:unit, pytest 等）
  - E2E 测试命令（如 pnpm test:e2e）
  - Lint 命令（如 pnpm lint, ruff 等）
  - 类型检查命令（如 pnpm typecheck, mypy 等）
  - 构建命令（如 pnpm build 等）
  - 开发服务器启动命令（如 pnpm dev, uvicorn 等）

  通过查看项目的 package.json、pyproject.toml、Makefile、Cargo.toml、alembic.ini 等配置文件来判断项目实际使用了哪些工具。
  如果项目尚未配置任何验证工具或为空仓，标注为 N/A，并给出"最小可行验证命令"建议。
  如果 AGENT.md 中缺少项目已配置的验证工具的对应命令，或包管理器不匹配，判定 FAIL。

  **2d. Lint/Typecheck 覆盖 (Lint & Typecheck Coverage)**
  AGENT.md 必须包含：
  - 前端：pnpm lint、pnpm type-check
  - 后端：ruff check .、mypy app
  缺失任一项判定 FAIL。

3. **命令可执行性 (Commands Executable)**
  AGENT.md 中的每条命令都应在当前项目环境中可直接执行。检查：
  - 命令中引用的脚本是否存在（如 package.json 中是否定义了对应的 npm script）
  - 命令中引用的工具是否已安装（检查 node_modules/.bin/ 或全局命令）
  - 路径是否正确（相对路径是否从项目根目录出发）
  如果存在引用了不存在的脚本或工具的命令，判定 FAIL。
  注意：只做静态检查（查看配置文件和目录），不要实际运行命令。

4. **长度控制 (Length Control)**
  AGENT.md 应尽量精简，推荐不超过 200 行。内容应只包含：
  - 验证命令及其说明
  - 环境特殊配置（如环境变量、特殊路径）
  - 项目特有的约束（如"测试前需启动 docker compose"）
  不应包含的内容：
  - 项目目标或需求描述（属于 PROMPT.md 或 specs/）
  - 编码规范或风格指南（属于 specs/coding_conventions.md）
  - 任务列表或进度追踪（属于 fix_plan.md）
  统计实际行数。如果超过 200 行，给出精简建议（列出应移除或迁移的具体段落/内容）并标记为 FAIL。

5. **与 PROMPT.md 的一致性 (Consistency with PROMPT.md)**
  检查 PROMPT.md 中 Phase 2（验证阶段）引用的命令来源是否与 AGENT.md 一致：
  - PROMPT.md 中如果写了"运行 AGENT.md 中定义的验证命令"，确认 AGENT.md 确实包含这些命令
  - PROMPT.md 中如果直接硬编码了验证命令（如"运行 npm test"），确认与 AGENT.md 中的命令一致，没有版本分歧
  如果存在不一致，判定 FAIL。

6. **无遗漏环境前置条件 (No Missing Prerequisites)**
  如果项目运行验证命令前需要前置步骤，AGENT.md 中应有说明。检查：

  **6a. 依赖安装**：
  - 是否需要先 pnpm install / npm install / pip install 但未提及
  - 如果是前后端分离项目，是否分别说明了前端和后端的依赖安装命令及路径

  **6b. E2E 测试前置依赖**：
  - 如果项目有 E2E 测试（如 Playwright），检查是否说明了运行 E2E 前需要先启动开发服务器（如 pnpm dev）
  - 如果 E2E 测试依赖后端 API，是否说明了需要先启动后端服务
  - 检查 playwright.config.ts 中的 baseURL，确认 AGENT.md 中有对应的服务启动说明

  **6c. 数据库与迁移**：
  - 如果项目使用数据库（存在 alembic/、migrations/、prisma/ 等），是否说明了数据库初始化/迁移命令
  - 如果测试需要数据库连接，是否说明了测试数据库的配置方式

  **6d. 环境变量与配置**：
  - 是否需要 .env 文件但未提及
  - 是否需要先执行某个 setup 脚本但未提及

  **6e. 服务依赖顺序**（针对全栈项目）：
  - 是否清晰说明了服务启动顺序（如：先启动后端 → 再启动前端 → 然后运行 E2E）
  - 是否说明了各服务运行的端口

  **6f. E2E 测试框架配置**（针对需要数据验证的项目）：
  - 如果项目需要在 E2E 测试中验证数据库写入，检查是否存在 tests/e2e/helpers/db.ts 或类似的数据库辅助文件
  - 如果项目需要验证 OSS/文件上传，检查是否存在 tests/e2e/helpers/oss.ts 或类似的 OSS 辅助文件
  - 如果存在这些辅助文件，AGENT.md 中是否说明了如何配置测试环境变量（.env.test）
  - 检查 playwright.config.ts 中是否配置了 globalSetup 和 globalTeardown（用于测试数据清理）

  如果存在明显的遗漏前置条件，判定 FAIL。

7. **职责边界清晰 (Clear Responsibility Boundary)**
  AGENT.md 的职责是"How to validate"——告诉 Claude 怎么运行验证。它不应越界包含：
  - "What to build"的内容（属于 PROMPT.md + specs/）
  - "What tasks to do"的内容（属于 fix_plan.md）
  - 编码风格、架构决策等指导性内容（属于 specs/）
  如果 AGENT.md 中混入了超出验证命令范围的内容，判定 FAIL，建议将越界内容移到对应文件。

8. **测试命令覆盖与脚手架可用性 (Test Command Coverage & Scaffold Readiness)**
  AGENT.md 必须覆盖项目需要的测试命令，并确保测试脚手架可用：
  - 前端存在 tests/e2e 时，应包含 E2E 命令（如 pnpm test:e2e / npx playwright test）
  - 若 E2E 命令存在，但 tests/e2e/ 或 playwright.config.ts 缺失，需在 AGENT.md 中说明如何生成（例如运行 install.sh 的对应步骤）
  - 后端测试命令（pytest/go test/cargo test）如在项目中存在，应覆盖
  缺失或不可达时判定 FAIL。

输出要求：

先输出一张汇总表：

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | 文件存在性 | ✅/❌ | 一句话说明 |
| ... | ... | ... | ... |

总评: X/8 通过

然后针对每个 FAIL 项，在表格下方逐项给出具体修改建议。修改建议必须是可以直接插入或替换到 AGENT.md 中的实际文本，不要只写"建议添加测试命令"这种笼统描述。

所有修改建议必须给出"建议插入位置"和"可直接粘贴的文本"，并提供可直接执行的 bash 修复命令。

如果检查项 1 判定 FAIL（文件不存在），则在修改建议中给出一份完整的 AGENT.md 初始内容草稿，基于项目的 package.json / pyproject.toml 等配置文件推导出正确的命令。

⚠️ 格式保持规则：如果 AGENT.md 已存在，所有修改建议必须延续其现有格式风格。如果是新建文件，采用简洁的 Markdown 格式：一级标题用 `#`，命令用代码块包裹。

输出审计报告后，问我：

> 以上是审计结果。你可以：
> 1. 输入 **"执行全部"** — 我将按上述建议修改 AGENT.md
> 2. 输入 **"执行 1,3,5"** — 只执行指定编号的修改建议
> 3. 告诉我你想怎么改 — 我会根据你的要求调整建议后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要做任何文件修改或创建。
EOF
)" ); then
   echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
   exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 10${NC}"
fi

# ==========================================
# Step 11: 审计 .ralph/.ralphrc
# ==========================================

if prompt_yes_no "是否审计 .ralphrc?" "y"; then
  RALPHRC_FILE="$PROJECT_DIR/.ralphrc"
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  AGENT_FILE="$PROJECT_DIR/.ralph/AGENT.md"
  FIX_PLAN_FILE="$PROJECT_DIR/.ralph/fix_plan.md"

  if [ ! -f "$RALPHRC_FILE" ]; then
    echo -e "${RED}❌ 未找到 $RALPHRC_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$AGENT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $AGENT_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$FIX_PLAN_FILE" ]; then
    echo -e "${RED}❌ 未找到 $FIX_PLAN_FILE${NC}"
    exit 1
  fi

  echo -e "${CYAN}🧾 启动 Claude Code（交互式）审计 .ralphrc...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务分为两步：
1. 审查 .ralph/.ralphrc 配置文件，输出审计报告
2. 等待我的指示，再决定是否执行修改

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

读取 .ralph/.ralphrc 的完整内容。同时读取以下文件作为交叉参考：
- 项目的 package.json / pyproject.toml / Cargo.toml 等（判断项目类型和工具链）
- .ralph/AGENT.md（获取已定义的验证命令列表）
- .ralph/fix_plan.md（估算任务总量和复杂度）
- 项目源代码目录结构（估算项目规模）

按以下 8 项检查标准逐一评估，每项评为 ✅ PASS 或 ❌ FAIL。FAIL 项必须附带具体的修改建议。

检查项：

1. **基础标识 (Project Identity)**
   .ralphrc 必须包含：
   - PROJECT_NAME：与实际项目名称一致（优先检查 package.json 的 name 字段；如果没有 package.json 等配置文件，允许以目录名为准，并在说明中标注依据来源）
   - PROJECT_TYPE：与实际技术栈一致（如 typescript、python、rust、go 等）
   如果缺失或与实际不符，判定 FAIL。

2. **超时配置 (Timeout Configuration)**
   CLAUDE_TIMEOUT_MINUTES 应与项目任务复杂度匹配：
   - 简单任务（单文件修改、添加测试）：10-15 分钟
   - 中等任务（实现一个端点、添加一个功能模块）：15-30 分钟
   - 复杂任务（涉及多文件联动的重构）：30-60 分钟
   根据 fix_plan.md 中任务的平均复杂度评估当前值是否合理。
   如果明显与任务复杂度不匹配（如复杂项目只设了 5 分钟），判定 FAIL。

3. **调用频率限制 (Call Rate Limit)**
   MAX_CALLS_PER_HOUR 应根据使用场景设置：
   - API 用户：根据 API 计划配额调整
   - Max 订阅用户：建议 50 以避免触发 5 小时用量限制
   - Pro 订阅用户：建议 30-50
   - 默认值 100 适用于大多数情况
   如果未显式设置，判定 FAIL（即使默认值合理，也应显式声明以便调试可见）。

4. **输出格式 (Output Format)**
   CLAUDE_OUTPUT_FORMAT 推荐设为 "json"。JSON 格式使 Ralph 能更精确地解析 Claude 的响应，特别是退出信号检测。
   如果设为 "text" 或未设置，判定 FAIL。
   注意：JSON 输出格式需要 Claude Code CLI ≥ 2.0.76。在说明中标注此前提条件。

5. **工具权限 (Allowed Tools)**
   ALLOWED_TOOLS 必须覆盖项目实际需要的所有操作。检查方法：
   - 读取 AGENT.md 中的所有验证命令，将每条命令映射到对应的 ALLOWED_TOOLS 权限项：
     - make test / make lint → Bash(make *)
     - pnpm test / pnpm lint → Bash(pnpm *)
     - npm run test → Bash(npm *)
     - pytest / ruff → Bash(pytest), Bash(ruff)
     - cargo test → Bash(cargo *)
   - 逐一确认每条命令都在 ALLOWED_TOOLS 的白名单内
   - 确认基础权限存在：Write, Read, Edit
   - 确认 git 操作权限存在：Bash(git *)
   如果 ALLOWED_TOOLS 缺少 AGENT.md 中命令所需的权限，判定 FAIL，并在修改建议中列出需要补充的具体权限项。
   如果 ALLOWED_TOOLS 过于宽泛（如 Bash(*)），给出警告但不判定 FAIL。

6. **Circuit Breaker 配置 (Circuit Breaker Thresholds)**
   检查以下 Circuit Breaker 阈值是否已设置且合理：
   - CB_NO_PROGRESS_THRESHOLD：连续 N 次无文件变更则停机（推荐 3）
   - CB_SAME_ERROR_THRESHOLD：连续 N 次相同错误则停机（推荐 5）
   - CB_OUTPUT_DECLINE_THRESHOLD：输出量下降超 N% 则停机（推荐 70）
   - CB_PERMISSION_DENIAL_THRESHOLD：连续 N 次权限拒绝则停机（推荐 2）
   如果所有阈值都未显式设置（依赖隐含默认值），判定 FAIL——应显式声明以便调试时可见。
   如果某个阈值明显不合理（如 CB_NO_PROGRESS_THRESHOLD=20），判定 FAIL。

7. **Session 配置 (Session Management)**
   检查：
   - SESSION_CONTINUITY：推荐设为 true，使 Claude 跨迭代保持会话上下文
   - SESSION_EXPIRY_HOURS：推荐 24，避免会话过早过期
   如果 SESSION_CONTINUITY 未设置或设为 false，判定 FAIL。

8. **配置项无冲突 (No Conflicting Settings)**
   检查配置项之间是否存在逻辑冲突，例如：
   - CLAUDE_TIMEOUT_MINUTES 设得很大（如 60）但 MAX_CALLS_PER_HOUR 也很大（如 100），可能导致短时间内消耗大量 API 配额
   - ALLOWED_TOOLS 中没有 git 权限但 PROMPT.md 要求每任务 commit
   - CB_NO_PROGRESS_THRESHOLD 设得比 CB_SAME_ERROR_THRESHOLD 大（无进度通常应比相同错误更早触发停机）
   如果存在潜在冲突，提示冲突关系并说明理由，但不强制判定 FAIL——用户可能有特殊使用场景。仅当冲突会导致 Ralph 无法正常运行时才判定 FAIL。

输出要求：

先输出一张汇总表：

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | 基础标识 | ✅/❌ | 一句话说明 |
| ... | ... | ... | ... |

总评: X/8 通过

然后针对每个 FAIL 项，在表格下方逐项给出具体修改建议。修改建议必须是可以直接替换到 .ralphrc 中的具体配置行，包含注释说明取值理由。

⚠️ 格式保持规则：.ralphrc 是 bash 配置文件格式（KEY=VALUE），注释用 #。延续文件中已有的分组注释风格。

输出审计报告后，问我：

> 以上是审计结果。你可以：
> 1. 输入 **"执行全部"** — 我将按上述建议修改 .ralphrc
> 2. 输入 **"执行 1,3,5"** — 只执行指定编号的修改建议
> 3. 告诉我你想怎么改 — 我会根据你的要求调整建议后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要做任何文件修改。
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 11${NC}"
fi

# ==========================================
# Step 12: 环境预检（启动 Ralph 前的最终检查）
# ==========================================

if prompt_yes_no "是否执行环境预检?" "y"; then
  RALPHRC_FILE="$PROJECT_DIR/.ralphrc"
  AGENT_FILE="$PROJECT_DIR/.ralph/AGENT.md"
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  FIX_PLAN_FILE="$PROJECT_DIR/.ralph/fix_plan.md"
  SPECS_DIR="$PROJECT_DIR/.ralph/specs"

  if [ ! -f "$RALPHRC_FILE" ]; then
    echo -e "${RED}❌ 未找到 $RALPHRC_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$AGENT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $AGENT_FILE${NC}"
    exit 1
  fi

  echo -e "${CYAN}🔍 启动 Claude Code（交互式）执行环境预检...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<EOF
你是 Ralph 配置审查与修复助手。Ralph 是用于 Claude Code 的项目自动化工作流/脚手架工具，不是业务项目本身；它通过 .ralph/ 目录和 .ralphrc 配置来组织任务与驱动迭代。你的任务分为两步：
1. 执行环境预检，确认项目可以安全启动 Ralph 循环
2. 等待我的指示，再决定是否执行修复

⚠️ 在我明确说"执行"之前，禁止修改任何文件或运行任何会改变项目状态的命令。

依次执行以下 8 项检查。每项检查需要你运行特定的只读命令来获取信息（命令已给出），然后根据输出判定 ✅ PASS 或 ❌ FAIL。

检查项：

1. **Git 仓库状态 (Git Repository Status)**
   运行：\`git status\`
   检查：
   - 项目是否在 git 仓库内（命令是否成功执行）
   - 工作区是否干净（no uncommitted changes）
   如果不在 git 仓库内，判定 FAIL。
   如果有未提交的变更，判定 FAIL，列出未提交的文件清单。

2. **基线 Commit (Baseline Commit)**
   运行：\`git log --oneline -5\`
   检查：最近的 commit 是否可以作为"Ralph 启动前基线"。
   - 如果检查项 1 判定工作区干净（PASS），则当前 HEAD 自动可作为基线，判定 PASS
   - 如果检查项 1 有未提交变更（FAIL），建议先 commit 这些变更作为基线
   不要强求 commit message 包含特定关键词，干净的工作区本身就是有效基线。

3. **依赖安装状态 (Dependencies Installed)**
   首先检测项目类型：
   - 若存在 package.json → Node.js 项目
   - 若存在 pyproject.toml 或 requirements.txt → Python 项目
   - 若存在 Cargo.toml → Rust 项目
   - 若存在 go.mod → Go 项目
   - 若存在多种配置文件（如前后端分离项目）→ 对每个子项目分别检查

   然后根据检测结果运行对应检查：
   - Node.js：检查 node_modules/ 是否存在，运行 \`npm ls --depth=0 2>&1 | tail -5\`
   - Python：运行 \`pip list 2>&1 | head -20\` 或检查虚拟环境
   - Rust：运行 \`cargo check 2>&1 | tail -5\`
   - Go：运行 \`go mod verify 2>&1\`
   如果依赖未安装或有明显缺失，判定 FAIL。

4. **验证命令试运行 (Validation Commands Dry Run)**
   从 .ralph/AGENT.md 中读取所有验证命令，逐条执行并记录结果。
   ⚠️ 这里只运行验证命令（test/lint/build），不运行会修改代码的命令。

   判定逻辑：
   - 命令不存在（command not found）→ FAIL（环境问题）
   - 命令存在但配置错误（如找不到配置文件）→ FAIL（环境问题）
   - 命令能执行但测试用例失败（assertion failed）→ PASS，标注"命令可执行，N 个测试失败（预期行为，代码待实现）"
   - 命令能执行且全部通过 → PASS

   如果任何验证命令因环境问题无法执行，判定 FAIL 并记录错误信息的前 10 行。

5. **Claude Code CLI 版本 (Claude Code CLI Version)**
   运行：\`claude --version 2>&1\`
   检查：
   - 如果 .ralphrc 中 CLAUDE_OUTPUT_FORMAT="json"，版本号需 ≥ 2.0.76
   - 如果 CLAUDE_OUTPUT_FORMAT="text" 或未设置，版本要求可降低
   如果 claude 命令不存在，判定 FAIL。
   如果需要 JSON 格式但版本低于 2.0.76，判定 FAIL。

6. **Ralph 安装状态 (Ralph Installation)**
   运行：\`ralph --version 2>&1\` 或 \`which ralph 2>&1\`
   检查：ralph 命令是否可用。
   如果不可用，判定 FAIL，给出安装命令。

7. **.ralphrc 与 ALLOWED_TOOLS 权限匹配 (Permission Consistency)**
   读取 .ralphrc 中的 ALLOWED_TOOLS 配置，然后对照 AGENT.md 中的每条验证命令，模拟权限匹配：
   - 例如 AGENT.md 中有 \`npm test\`，ALLOWED_TOOLS 中需要有 \`Bash(npm *)\` 或 \`Bash(npm test)\`
   - 例如 PROMPT.md 要求 git commit，ALLOWED_TOOLS 中需要有 \`Bash(git *)\` 或 \`Bash(git commit *)\`
   逐条列出匹配结果表格：
   | 命令 | 需要权限 | ALLOWED_TOOLS 中是否存在 |
   如果有命令无法匹配到任何 ALLOWED_TOOLS 规则，判定 FAIL。

8. **跨文件一致性总检 (Cross-File Consistency)**
   这是文件引用完整性的最终检查：
   - PROMPT.md 中引用的文件是否都实际存在（@fix_plan.md、@AGENT.md、specs/ 下的文件）
   - PROMPT.md 中的 specs 索引列表是否与 specs/ 目录下的实际文件一致
   - fix_plan.md 中引用的 spec 文件路径是否都实际存在
   如果存在任何引用断裂（引用了不存在的文件），判定 FAIL 并列出断裂的引用。

输出一张汇总表：

| # | 检查项 | 结果 | 说明 |
|---|--------|------|------|
| 1 | Git 仓库状态 | ✅/❌ | 一句话说明 |
| ... | ... | ... | ... |

总评: X/8 通过

然后针对每个 FAIL 项给出具体的修复命令或修复步骤。
修复建议必须是可以直接执行的命令。
对高风险操作（如 git commit、npm install、pip install）标注 ⚠️ 提醒用户确认。

输出预检报告后，问我：

> 以上是环境预检结果。你可以：
> 1. 输入 **"修复全部"** — 我将执行上述修复命令
> 2. 输入 **"修复 1,3"** — 只修复指定编号的问题
> 3. 告诉我你想怎么处理 — 我会根据你的要求调整
> 4. 输入 **"跳过"** — 不做任何修复
>
> ⚠️ 注意：如果存在 FAIL 项但选择跳过，Ralph 循环启动后可能遇到权限拒绝、命令执行失败或引用找不到等问题。

在收到我的回复前，不要执行任何修复操作。
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 12${NC}"
fi

# ==========================================
# Step 13: 交互式测试配置核查与测试生成
# ==========================================

if prompt_yes_no "是否执行测试配置核查与测试生成?" "y"; then
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"
  AGENT_FILE="$PROJECT_DIR/.ralph/AGENT.md"

  if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
    exit 1
  fi
  if [ ! -f "$AGENT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $AGENT_FILE${NC}"
    exit 1
  fi

  echo -e "${CYAN}🧪 启动 Claude Code（交互式）核查测试配置与测试可用性...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<EOF
你是 Ralph 测试配置审查与测试可用性验证助手。你的任务分为两步：
1) 检查 PROMPT.md、AGENT.md 以及项目内所有测试配置，验证这些配置是否完整且可用
2) 生成或调用对应测试，验证每个配置的测试是否能生效，并输出问题与修复计划

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

请执行以下流程：

## 阶段一：测试配置清单与一致性检查
读取以下内容：
- .ralph/PROMPT.md
- .ralph/AGENT.md
- 项目内所有测试配置文件（例如：playwright.config.ts、vitest.config.*、jest.config.*、pytest.ini、pytest.toml、pyproject.toml 的 [tool.pytest]、ruff.toml、mypy.ini、package.json scripts、frontend/tests/e2e、backend/tests 等）

输出一个"测试配置清单"，逐项列出：
- 配置文件路径
- 相关命令来源（PROMPT.md / AGENT.md / package.json scripts / 其他）
- 是否可直接执行

并检查：
- PROMPT.md 与 AGENT.md 中的测试命令是否一致
- 是否缺失必要的测试命令（unit/e2e/lint/typecheck/build）
- 前后端分离项目是否分别覆盖测试命令

## 阶段二：生成/调用测试以验证可用性
对"测试配置清单"中的每一项：
1) 如果已有测试范例（例如 frontend/tests/e2e/example.spec.ts），直接调用它的测试命令进行验证
2) 如果没有测试范例，请基于现有配置生成最小可运行测试（一个即可）
3) 运行对应测试命令，记录结果

结果判定：
- 测试命令不存在/无法执行 → FAIL
- 测试运行但失败 → FAIL（列出错误摘要）
- 测试运行并通过 → PASS

## 常见问题快速修补（如命中则必须给出可执行命令）
1) Vitest 误收集 Playwright 测试：
  - 目标文件：frontend/vitest.config.ts
  - 需要包含 include: ['src/**/*.{test,spec}.{ts,tsx}']
  - 需要排除 exclude: ['**/tests/e2e/**', '**/node_modules/**']
2) ESLint 解析 TypeScript 失败：
  - 如果是 Next.js 项目：.eslintrc.json 使用 extends ["next/core-web-vitals", "plugin:prettier/recommended"]
  - 如果不是 Next.js：安装 @typescript-eslint/parser 和 @typescript-eslint/eslint-plugin，并配置 parser/extends
3) mypy 模块名冲突：
  - 目标文件：backend/mypy.ini
  - 需要添加 explicit_package_bases = true 与 namespace_packages = true

## 输出要求
1) 输出一张汇总表：

| 配置/命令 | 来源 | 结果 | 说明 |
|---|---|---|---|

2) 对每个 FAIL 项，列出：
   - 失败原因摘要
  - 建议的修改方案（具体到要修改的文件和内容）
  - 必须提供可直接执行的 bash 修复命令（如 cat <<'EOF' > file ...）

3) 给出"修改计划"（按步骤编号），然后问我：

> 以上是测试配置核查与测试验证结果。你可以：
> 1. 输入 **"执行全部"** — 我将按修改计划修复
> 2. 输入 **"执行 1,3"** — 只执行指定编号
> 3. 告诉我你想怎么改 — 我会调整计划后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要修改任何文件。
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 13${NC}"
fi

# ==========================================
# Step 14: .gitignore 与 Git 提交流程规范核查
# ==========================================

if prompt_yes_no "是否执行 .gitignore 与 Git 提交流程规范核查?" "y"; then
  PROMPT_FILE="$PROJECT_DIR/.ralph/PROMPT.md"

  if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}❌ 未找到 $PROMPT_FILE${NC}"
    exit 1
  fi

  echo -e "${CYAN}🧹 启动 Claude Code（交互式）检查 .gitignore 与 Git 提交流程规范...${NC}"
  if ! (cd "$PROJECT_DIR" && claude "$(cat <<'EOF'
你是 Ralph 的 Git 规范核查助手。你的任务：
1) 检查项目的 .gitignore 是否完整，尤其是 .ralph 运行态文件的忽略规则
2) 检查 .ralph/PROMPT.md 是否明确包含 Git 提交与上传要求，并在必要时补充

⚠️ 在我明确说"执行"之前，禁止修改任何文件。

请按以下流程执行：

## Part A: .gitignore 检查
读取 .gitignore，判断是否已忽略以下运行态文件（仅忽略这些，不要忽略整个 .ralph 目录）：
- .ralph/.call_count
- .ralph/.circuit_breaker_*
- .ralph/.exit_signals
- .ralph/.last_reset
- .ralph/.ralph_session*
- .ralph/*.json
- .ralph/live.log
- .ralph/logs/

如果缺失，请给出需要追加的具体规则文本，并提供可直接执行的 bash 命令（例如 cat <<'EOF' >> .gitignore ...）。

## Part B: PROMPT.md Git 提交流程核查
读取 .ralph/PROMPT.md，确认是否明确包含以下内容：
1) 提交指令有哪些（至少包含 git add / git commit / git push 的示例）
2) 什么时候必须执行一次提交到本地当前分支（每个模块测试通过后就需要提交）
3) 你认为还需要补充的 Git 相关约束（例如：禁止未通过测试提交、保持分支干净、提交信息格式等）

如果缺失，请给出需要插入或替换的具体文本（明确插入位置），并提供可直接执行的 bash 命令。

## 输出要求
1) 输出检查结论（PASS/FAIL）
2) 如果 FAIL，提供“修改计划”并编号
3) 给出可直接执行的 bash 修复命令
4) 最后问我：

> 以上是 .gitignore 与 Git 规范核查结果。你可以：
> 1. 输入 **"执行全部"** — 我将按修改计划修复
> 2. 输入 **"执行 1,3"** — 只执行指定编号
> 3. 告诉我你想怎么改 — 我会调整计划后再执行
> 4. 输入 **"跳过"** — 不做任何修改

在收到我的回复前，不要修改任何文件。
EOF
)" ); then
    echo -e "${RED}❌ Claude CLI 启动失败或已退出，请检查登录状态或网络${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}⏭️ 已跳过 Step 14${NC}"
fi
