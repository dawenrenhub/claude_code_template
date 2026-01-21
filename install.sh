#!/bin/bash

# ==========================================
# Ralph Loop V7.1: 修复 Gemini/GPT 指出的问题
# ==========================================
# 修复内容:
# 1. 加回 Browser-use MCP
# 2. Stop Hook 只检查最后一条 assistant 消息，避免误触发
# 3. Gate 失败信息落盘，解决"从头开始"无记忆问题
# 4. 更精确的 Token 匹配
# 5. 更智能的端口检测
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Ralph Loop V7.1: 问题修复版${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"

# ==========================================
# 系统检查: 仅支持 Linux
# ==========================================
if [[ "$(uname)" != "Linux" ]]; then
    echo -e "${RED}❌ 此脚本仅支持 Linux 系统${NC}"
    echo -e "${YELLOW}   检测到: $(uname)${NC}"
    echo -e "${YELLOW}   macOS 用户请注意: sed -i 等命令语法不兼容${NC}"
    exit 1
fi

# ==========================================
# 0. 依赖检查
# ==========================================
echo -e "\n${YELLOW}[Step 0] 检查依赖...${NC}"

detect_os() {
    if command -v brew &> /dev/null; then
        echo "brew"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    else
        echo "unknown"
    fi
}

install_with_apt() {
    local pkg="$1"
    if command -v sudo &> /dev/null; then
        sudo apt-get update -y
        sudo apt-get install -y "$pkg"
    else
        apt-get update -y
        apt-get install -y "$pkg"
    fi
}

install_with_brew() {
    local pkg="$1"
    brew install "$pkg"
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}⚠️ 缺少依赖: $1，尝试自动安装...${NC}"
        local os_manager
        os_manager=$(detect_os)
        case "$1" in
            jq)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew jq
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt jq
                else
                    echo -e "${RED}❌ 无法自动安装 jq，请手动安装${NC}"
                    echo "   安装方式: $2"
                    exit 1
                fi
                ;;
            python3)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew python
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt python3
                    install_with_apt python3-pip
                else
                    echo -e "${RED}❌ 无法自动安装 python3，请手动安装${NC}"
                    echo "   安装方式: $2"
                    exit 1
                fi
                ;;
            npx)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew node
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt nodejs
                    install_with_apt npm
                else
                    echo -e "${RED}❌ 无法自动安装 npx，请手动安装${NC}"
                    echo "   安装方式: $2"
                    exit 1
                fi
                # 二次校验 npx，若仍缺失则回退安装
                if ! command -v npx &> /dev/null; then
                    echo -e "${YELLOW}⚠️ npx 仍未找到，尝试 npm install -g npx...${NC}"
                    npm install -g npx
                fi
                ;;
            claude)
                if ! command -v npm &> /dev/null; then
                    echo -e "${YELLOW}⚠️ 未检测到 npm，尝试安装 Node.js...${NC}"
                    if [ "$os_manager" = "brew" ]; then
                        install_with_brew node
                    elif [ "$os_manager" = "apt" ]; then
                        install_with_apt nodejs
                        install_with_apt npm
                    else
                        echo -e "${RED}❌ 无法自动安装 npm，请手动安装${NC}"
                        exit 1
                    fi
                fi
                # 检查 Node 版本 (需要 >= 18)
                if command -v node &> /dev/null; then
                    NODE_MAJOR=$(node -v | sed 's/^v//' | cut -d. -f1)
                    if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 18 ]; then
                        echo -e "${YELLOW}⚠️ Node.js 版本过低 (当前: $(node -v)). 尝试自动升级到 >= 18...${NC}"
                        if [ "$os_manager" = "brew" ]; then
                            brew upgrade node || install_with_brew node
                        elif [ "$os_manager" = "apt" ]; then
                            install_with_apt nodejs
                            install_with_apt npm
                        else
                            echo -e "${RED}❌ 无法自动升级 Node.js，请手动升级到 >= 18${NC}"
                            exit 1
                        fi
                        NODE_MAJOR=$(node -v | sed 's/^v//' | cut -d. -f1)
                        if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 18 ]; then
                            echo -e "${RED}❌ Node.js 升级后仍不足 18 (当前: $(node -v))${NC}"
                            echo "   请手动升级 Node.js 后再继续。"
                            exit 1
                        fi
                    fi
                else
                    echo -e "${RED}❌ 未找到 node 命令，请手动安装 Node.js >= 18${NC}"
                    exit 1
                fi
                # 安装/降级 Claude CLI 到指定版本 (<= 2.076)
                npm install -g @anthropic-ai/claude-code@2.076
                ;;
            uvx)
                # 优先使用 pipx 安装 uv (符合 PEP 668 规范)
                if command -v pipx &> /dev/null; then
                    pipx install uv
                elif command -v apt-get &> /dev/null; then
                    # 先安装 pipx
                    echo -e "${YELLOW}⚠️ 安装 pipx...${NC}"
                    if command -v sudo &> /dev/null; then
                        sudo apt-get update -y
                        sudo apt-get install -y pipx
                    else
                        apt-get update -y
                        apt-get install -y pipx
                    fi
                    # 确保 pipx 路径可用
                    pipx ensurepath 2>/dev/null || true
                    export PATH="$HOME/.local/bin:$PATH"
                    # 用 pipx 安装 uv
                    pipx install uv
                else
                    # 回退方案：使用 --break-system-packages
                    echo -e "${YELLOW}⚠️ 尝试使用 pip 安装 (带 --break-system-packages)...${NC}"
                    if command -v pip3 &> /dev/null; then
                        pip3 install --break-system-packages uv
                    elif command -v pip &> /dev/null; then
                        pip install --break-system-packages uv
                    else
                        echo -e "${RED}❌ 无法安装 uv，请手动安装: pipx install uv${NC}"
                        exit 1
                    fi
                fi
                # 确保 uvx 在 PATH 中
                export PATH="$HOME/.local/bin:$PATH"
                ;;
            *)
                echo -e "${RED}❌ 未知依赖: $1，无法自动安装${NC}"
                exit 1
                ;;
        esac
        if ! command -v "$1" &> /dev/null; then
            echo -e "${RED}❌ 自动安装失败: $1${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓ $1${NC}"
}

check_dependency "jq" "apt install jq"
check_dependency "python3" "apt install python3"
check_dependency "npx" "npm install -g npx"
check_dependency "claude" "npm install -g @anthropic-ai/claude-code"

# 检查 uvx (browser-use 需要)
check_dependency "uvx" "pip install uv"

# 检查 Python 版本 (需要 >= 3.9，因为使用了 tuple[bool, str] 语法)
echo -e "${YELLOW}检查 Python 版本...${NC}"
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
    echo -e "${YELLOW}⚠️ Python 版本过低: $PYTHON_VERSION，需要 >= 3.9${NC}"
    echo -e "${YELLOW}   尝试自动升级 Python...${NC}"
    
    if command -v apt-get &> /dev/null; then
        # 添加 deadsnakes PPA 获取新版 Python
        if command -v sudo &> /dev/null; then
            sudo apt-get update -y
            sudo apt-get install -y software-properties-common
            sudo add-apt-repository -y ppa:deadsnakes/ppa
            sudo apt-get update -y
            sudo apt-get install -y python3.11 python3.11-venv python3.11-distutils
            # 设置 python3.11 为默认
            sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
        else
            apt-get update -y
            apt-get install -y software-properties-common
            add-apt-repository -y ppa:deadsnakes/ppa
            apt-get update -y
            apt-get install -y python3.11 python3.11-venv python3.11-distutils
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
        fi
    else
        echo -e "${RED}❌ 无法自动升级 Python，请手动安装 Python >= 3.9${NC}"
        exit 1
    fi
    
    # 重新检查版本
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)
    
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
        echo -e "${RED}❌ Python 升级失败，当前版本: $PYTHON_VERSION${NC}"
        echo -e "${YELLOW}   请手动安装 Python >= 3.9 后重试${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Python 已升级到 $PYTHON_VERSION${NC}"
else
    echo -e "${GREEN}✓ Python $PYTHON_VERSION${NC}"
fi

# ==========================================
# 1. 创建目录结构
# ==========================================
echo -e "\n${YELLOW}[Step 1] 创建目录结构...${NC}"

mkdir -p .claude/hooks
mkdir -p scripts
mkdir -p specs
mkdir -p tests/e2e
mkdir -p logs
mkdir -p .ralph  # 新增: Ralph 状态目录

echo -e "${GREEN}✓ 目录结构已创建${NC}"

# ==========================================
# 2. 创建 .mcp.json (修复: 加回 Browser-use)
# ==========================================
echo -e "\n${YELLOW}[Step 2] 创建 .mcp.json (含 Browser-use)...${NC}"

# 备份现有配置
if [ -f ".mcp.json" ]; then
    cp .mcp.json .mcp.json.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${YELLOW}  已备份现有 .mcp.json${NC}"
fi

cat << 'EOF' > .mcp.json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-playwright"]
    },
    "browser-use": {
      "command": "uvx",
      "args": ["browser-use-mcp"]
    }
  }
}
EOF

echo -e "${GREEN}✓ .mcp.json (Playwright + Browser-use)${NC}"

# ==========================================
# 3. 创建 .claude/settings.json
# ==========================================
echo -e "\n${YELLOW}[Step 3] 创建 .claude/settings.json...${NC}"

# 备份现有配置
if [ -f ".claude/settings.json" ]; then
    cp .claude/settings.json .claude/settings.json.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${YELLOW}  已备份现有 .claude/settings.json${NC}"
fi

cat << 'EOF' > .claude/settings.json
{
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(grep:*)",
      "Bash(find:*)",
      "Bash(head:*)",
      "Bash(tail:*)",
      "Bash(wc:*)",
      "Bash(echo:*)",
      "Bash(pwd:*)",
      "Bash(cd:*)",
      "Bash(mkdir:*)",
      "Bash(touch:*)",
      "Bash(cp:*)",
      "Bash(mv:*)",
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)",
      "Bash(python3:*)",
      "Bash(python:*)",
      "Bash(pip:*)",
      "Bash(lsof:*)",
      "Bash(ps:*)",
      "Bash(kill:*)",
      "Bash(which:*)",
      "Bash(env:*)",
      "Bash(export:*)",
      "Bash(uvx:*)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(rm -r:*)",
      "Bash(sudo:*)",
      "Bash(shutdown:*)",
      "Bash(reboot:*)",
      "Bash(mkfs:*)",
      "Bash(dd:*)",
      "Bash(chmod 777:*)",
      "Bash(chmod -R 777:*)",
      "Bash(chown -R:*)",
      "Bash(curl:*)|sh",
      "Bash(curl:*)|bash",
      "Bash(wget:*)|sh",
      "Bash(wget:*)|bash",
      "Bash(eval:*)",
      "Read(/etc/passwd)",
      "Read(/etc/shadow)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)",
      "Read(./.git/config)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(git commit:*)",
      "Bash(npm publish:*)",
      "Bash(rm:*)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/pre_tool_use.py\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/stop_hook.py\""
          }
        ]
      }
    ]
  }
}
EOF

echo -e "${GREEN}✓ .claude/settings.json${NC}"

# ==========================================
# 4. Hook: PreToolUse (安全拦截)
# ==========================================
echo -e "\n${YELLOW}[Step 4] 创建 PreToolUse Hook...${NC}"

cat << 'PYTHON_EOF' > .claude/hooks/pre_tool_use.py
#!/usr/bin/env python3
"""
PreToolUse Hook - 在工具执行前进行安全检查
"""

import sys
import json
import re
import os

DANGEROUS_PATTERNS = [
    (r"rm\s+-[rR]*f\s+/", "禁止删除根目录"),
    (r"rm\s+-[rR]*f\s+~", "禁止删除用户目录"),
    (r"rm\s+-[rR]*f\s+\*", "禁止通配符强制删除"),
    (r">\s*/dev/sd[a-z]", "禁止写入磁盘设备"),
    (r"mkfs\.", "禁止格式化磁盘"),
    (r"dd\s+if=.*of=/dev", "禁止 dd 写入设备"),
    (r"chmod\s+-R\s+777\s+/", "禁止递归 777 根目录"),
    (r"curl\s+.*\|\s*sudo", "禁止 curl 管道到 sudo"),
    (r"wget\s+.*\|\s*sh", "禁止 wget 管道到 sh"),
    (r"curl\s+.*\|\s*sh", "禁止 curl 管道到 sh"),
    (r":\(\)\{\s*:\|:&\s*\};:", "禁止 fork bomb"),
]

LOG_FILE = os.path.join(
    os.environ.get("CLAUDE_PROJECT_DIR", "."),
    "logs", "pre_tool_use.log"
)

def log(message: str):
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a") as f:
            f.write(f"{message}\n")
    except:
        pass

def block(reason: str):
    output = {"decision": "block", "reason": reason}
    print(json.dumps(output))
    sys.exit(0)

def allow():
    sys.exit(0)

def main():
    try:
        input_str = sys.stdin.read()
        if not input_str.strip():
            allow()
        
        payload = json.loads(input_str)
        tool_name = payload.get("tool_name", "")
        tool_input = payload.get("tool_input", {}) or {}
        
        log(f"[PreToolUse] tool={tool_name}, input={json.dumps(tool_input)[:200]}")
        
        if tool_name != "Bash":
            allow()
        
        command = tool_input.get("command", "")
        if not command:
            allow()
        
        for pattern, reason in DANGEROUS_PATTERNS:
            if re.search(pattern, command, re.IGNORECASE):
                log(f"[BLOCKED] pattern={pattern}, command={command[:100]}")
                block(f"{reason}: 命令包含危险模式 '{pattern}'")
        
        allow()
        
    except Exception as e:
        log(f"[ERROR] {e}")
        allow()

if __name__ == "__main__":
    main()
PYTHON_EOF

chmod +x .claude/hooks/pre_tool_use.py
echo -e "${GREEN}✓ .claude/hooks/pre_tool_use.py${NC}"

# ==========================================
# 5. Hook: Stop (修复: 只检查最后一条 assistant 消息)
# ==========================================
echo -e "\n${YELLOW}[Step 5] 创建 Stop Hook (修复版)...${NC}"

cat << 'PYTHON_EOF' > .claude/hooks/stop_hook.py
#!/usr/bin/env python3
"""
Stop Hook V7.1 - 修复版

修复内容:
1. 只检查最后一条 assistant 消息，避免历史消息误触发
2. Gate 失败信息落盘到 .ralph/last_failure.md
3. 更精确的 Token 匹配（必须单独一行）
"""

import sys
import json
import subprocess
import os
import re
from datetime import datetime

# 退出 Token (必须单独一行才算数)
EXIT_TOKEN = "__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__"

# 文件路径
PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR", ".")
QUALITY_GATE_SCRIPT = os.path.join(PROJECT_DIR, "scripts/quality_gate.sh")
LOG_FILE = os.path.join(PROJECT_DIR, "logs/stop_hook.log")
FAILURE_FILE = os.path.join(PROJECT_DIR, ".ralph/last_failure.md")  # 新增: 失败信息落盘


def log(message: str):
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        timestamp = datetime.now().isoformat()
        with open(LOG_FILE, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
    except:
        pass


def save_failure(reason: str, details: str):
    """
    保存失败信息到文件，让 Claude 下次能读取
    解决"从头开始"无记忆的问题
    """
    try:
        os.makedirs(os.path.dirname(FAILURE_FILE), exist_ok=True)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        content = f"""# 上次 Quality Gate 失败记录

**时间**: {timestamp}

## 失败原因
{reason}

## 详细信息
```
{details[-2000:] if len(details) > 2000 else details}
```

## 下一步
请根据上述错误信息修复问题，然后重新运行测试。
"""
        with open(FAILURE_FILE, "w") as f:
            f.write(content)
        log(f"[INFO] Failure saved to {FAILURE_FILE}")
    except Exception as e:
        log(f"[ERROR] Failed to save failure: {e}")


def clear_failure():
    """清除失败记录"""
    try:
        if os.path.exists(FAILURE_FILE):
            os.remove(FAILURE_FILE)
    except:
        pass


def block_exit(reason: str):
    output = {"decision": "block", "reason": reason}
    print(json.dumps(output))
    log(f"[BLOCKED] {reason[:200]}")
    sys.exit(0)


def allow_exit():
    log("[ALLOWED] Exit permitted")
    clear_failure()  # 成功时清除失败记录
    sys.exit(0)


def extract_last_assistant_message(transcript_path: str) -> str:
    """
    从 transcript 中提取最后一条 assistant 消息
    
    支持两种格式:
    1. JSONL: 每行一个 JSON 对象
    2. 单个 JSON 数组
    
    只返回最后一条 assistant 的内容，避免历史消息误触发
    """
    try:
        with open(transcript_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # 尝试解析为 JSONL
        lines = content.strip().split('\n')
        messages = []
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                messages.append(entry)
            except:
                continue
        
        # 如果 JSONL 解析失败，尝试整体 JSON
        if not messages:
            try:
                data = json.loads(content)
                if isinstance(data, list):
                    messages = data
                elif isinstance(data, dict) and "messages" in data:
                    messages = data["messages"]
            except:
                pass
        
        # 倒序查找最后一条 assistant 消息
        for entry in reversed(messages):
            role = entry.get("role") or entry.get("type") or ""
            if role.lower() == "assistant":
                content_raw = entry.get("content", "")
                
                # content 可能是字符串或数组
                if isinstance(content_raw, str):
                    return content_raw
                elif isinstance(content_raw, list):
                    text_parts = []
                    for block in content_raw:
                        if isinstance(block, dict) and block.get("type") == "text":
                            text_parts.append(block.get("text", ""))
                        elif isinstance(block, str):
                            text_parts.append(block)
                    return "\n".join(text_parts)
        
        return ""
        
    except Exception as e:
        log(f"[WARNING] Failed to extract assistant message: {e}")
        return ""


def check_token_in_message(message: str) -> bool:
    """
    检查 Token 是否单独成行
    
    有效: 
      ...测试通过\n__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__\n
      __RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__
    
    无效 (引用/讨论):
      我现在不能输出 `__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__` 因为...
      Token 是 __RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__ 这个字符串
    """
    # 按行检查
    for line in message.split('\n'):
        line = line.strip()
        # 精确匹配: 整行就是 Token
        if line == EXIT_TOKEN:
            return True
    
    return False


def run_quality_gate() -> tuple[bool, str]:
    if not os.path.exists(QUALITY_GATE_SCRIPT):
        return False, f"Quality Gate 脚本不存在: {QUALITY_GATE_SCRIPT}"
    
    try:
        result = subprocess.run(
            [QUALITY_GATE_SCRIPT],
            capture_output=True,
            text=True,
            timeout=300,
            cwd=PROJECT_DIR
        )
        
        output = result.stdout + result.stderr
        return (result.returncode == 0, output)
        
    except subprocess.TimeoutExpired:
        return False, "Quality Gate 执行超时 (>5分钟)"
    except Exception as e:
        return False, f"Quality Gate 执行失败: {e}"


def main():
    try:
        input_str = sys.stdin.read()
        if not input_str.strip():
            allow_exit()
        
        payload = json.loads(input_str)
        log(f"[INPUT] keys={list(payload.keys())}")
        
        transcript_path = payload.get("transcript_path", "")
        
        if not transcript_path or not os.path.exists(transcript_path):
            log("[INFO] No transcript, allowing exit")
            allow_exit()
        
        # 关键修复: 只提取最后一条 assistant 消息
        last_message = extract_last_assistant_message(transcript_path)
        log(f"[DEBUG] Last assistant message length: {len(last_message)}")
        
        if not last_message:
            log("[INFO] No assistant message found, allowing exit")
            allow_exit()
        
        # 关键修复: 检查 Token 是否单独成行
        if not check_token_in_message(last_message):
            log("[INFO] No valid exit token in last message, allowing normal stop")
            allow_exit()
        
        # 发现有效的退出请求，运行 Quality Gate
        log("[INFO] Valid exit token detected, running Quality Gate...")
        
        passed, output = run_quality_gate()
        
        if passed:
            log("[SUCCESS] Quality Gate passed")
            print("✅ Quality Gate 通过", file=sys.stderr)
            allow_exit()
        else:
            # 关键修复: 保存失败信息到文件
            save_failure("Quality Gate 测试失败", output)
            
            error_summary = output[-1000:] if len(output) > 1000 else output
            block_exit(
                f"Quality Gate 失败！你不能退出。\n\n"
                f"错误摘要:\n{error_summary}\n\n"
                f"详细信息已保存到 .ralph/last_failure.md\n"
                f"请阅读该文件了解失败原因，修复后重试。"
            )
    
    except Exception as e:
        log(f"[ERROR] Unexpected: {e}")
        allow_exit()


if __name__ == "__main__":
    main()
PYTHON_EOF

chmod +x .claude/hooks/stop_hook.py
echo -e "${GREEN}✓ .claude/hooks/stop_hook.py (修复版)${NC}"

# ==========================================
# 6. Script: Quality Gate (修复: 智能端口检测)
# ==========================================
echo -e "\n${YELLOW}[Step 6] 创建 Quality Gate 脚本 (智能端口)...${NC}"

cat << 'BASH_EOF' > scripts/quality_gate.sh
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
BASH_EOF

chmod +x scripts/quality_gate.sh
echo -e "${GREEN}✓ scripts/quality_gate.sh (智能端口检测)${NC}"

# ==========================================
# 7. Script: Ralph Loop
# ==========================================
echo -e "\n${YELLOW}[Step 7] 创建 Ralph Loop...${NC}"

cat << 'BASH_EOF' > scripts/ralph_loop.sh
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
BASH_EOF

chmod +x scripts/ralph_loop.sh
echo -e "${GREEN}✓ scripts/ralph_loop.sh${NC}"

# ==========================================
# 8. PROMPT.md (修复: 加入工具箱说明 + Token 规则)
# ==========================================
echo -e "\n${YELLOW}[Step 8] 创建 PROMPT.md...${NC}"

cat << 'MD_EOF' > PROMPT.md
# Role: Ralph - 自治测试工程师

你是 Ralph，一个基于 MCP 的自治测试工程师。

---

## 工具箱

你有两个强大的武器：

1. **Playwright MCP (`playwright`)**: 主力工具
   - 用于编写 `.spec.ts` 测试文件
   - 执行自动化测试

2. **Browser-use MCP (`browser-use`)**: 视觉调试工具
   - 当测试失败时，**必须**使用此工具打开网页查看
   - 可以截图、检查 DOM 结构
   - 帮助你理解页面实际状态

---

## 工作流程

### 1. 检查状态
- 首先检查 `.ralph/last_failure.md` 是否存在
- 如果存在，**优先修复**上次失败的问题

### 2. 分析任务
- 阅读 `specs/` 目录下的需求文档
- 如果存在 `fix_plan.md`，处理其中的任务

### 3. 编写代码
- 实现所需功能
- 遵循项目代码规范

### 4. 编写测试 (必须!)
- 在 `tests/e2e/` 目录下编写 Playwright E2E 测试
- 测试文件命名: `*.spec.ts` 或 `*.spec.js`
- 覆盖主要功能路径

### 5. 自测验证
- 运行 `./scripts/quality_gate.sh`
- 如果失败:
  1. 使用 **browser-use** 打开页面查看实际状态
  2. 分析错误原因
  3. 修复代码或测试
  4. 重复直到通过

---

## 安全规则

### 禁止
- `rm -rf` 危险删除
- 访问系统敏感文件
- `curl | sh` 等危险管道

### 需确认
- `git push/commit`
- `npm publish`
- `rm` 删除文件

---

## 退出条件

**全部满足才能退出:**

1. ✅ 需求已实现
2. ✅ 有对应的 E2E 测试
3. ✅ `./scripts/quality_gate.sh` 通过
4. ✅ 无已知 Bug

---

## 退出请求格式

⚠️ **重要规则**:

当你确认可以退出时，在回复的**最后**，**单独一行**输出:

__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__

**必须遵守**:
- Token 必须单独占一行
- 前后不能有其他文字
- 不要放在代码块或引号里
- 不要在讨论中提及这个 Token

**正确示例**:
```
我已完成所有任务，测试全部通过。

__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__
```

**错误示例** (会被忽略):
```
Token 是 `__RALPH_QUALITY_GATE_EXIT_REQUEST_7f3a9b2c__`
```

如果 Gate 失败，你会收到阻断信息，请阅读 `.ralph/last_failure.md` 了解原因。
MD_EOF

echo -e "${GREEN}✓ PROMPT.md${NC}"

# ==========================================
# 9-12: 其余文件 (测试、配置等)
# ==========================================
echo -e "\n${YELLOW}[Step 9-12] 创建辅助文件...${NC}"

# 示例测试
cat << 'TS_EOF' > tests/e2e/example.spec.ts
import { test, expect } from '@playwright/test';

test.describe('示例测试', () => {
  test('首页加载', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.*/);
  });
});
TS_EOF

# Playwright 配置
cat << 'TS_EOF' > playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  reporter: 'list',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
TS_EOF

# 任务模板
cat << 'MD_EOF' > specs/fix_plan.md
# 任务计划

## 任务列表

### 1. [任务名称]
- **描述**: 
- **验收标准**: 

## 测试要求
- E2E 测试在 `tests/e2e/`
- 运行 `./scripts/quality_gate.sh` 验证
MD_EOF

# .gitignore (备份现有内容，避免重复)
if [ -f ".gitignore" ]; then
    # 移除旧的 Ralph 块（如果存在）
    sed -i.bak '/# Ralph/,/^$/d' .gitignore 2>/dev/null || true
    sed -i.bak '/# Node \/ System/,/^$/d' .gitignore 2>/dev/null || true
    rm -f .gitignore.bak
fi

cat << 'EOF' >> .gitignore

# Ralph
logs/
.ralph/
.claude/settings.local.json
test-results/
playwright-report/

# Node / System
node_modules/
.env
.env.*
.DS_Store
dist/
build/
EOF

echo -e "${GREEN}✓ 辅助文件已创建${NC}"

# ==========================================
# 完成
# ==========================================
echo ""
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Ralph Loop V7.1 安装完成！${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo ""
echo -e "修复内容:"
echo -e "  ✓ 加回 Browser-use MCP"
echo -e "  ✓ Stop Hook 只检查最后一条消息"
echo -e "  ✓ 失败信息落盘到 .ralph/last_failure.md"
echo -e "  ✓ 智能端口检测 (Vite/Next/Nuxt)"
echo -e "  ✓ 更精确的 Token 匹配"
echo ""
echo -e "运行: ${GREEN}./scripts/ralph_loop.sh${NC}"