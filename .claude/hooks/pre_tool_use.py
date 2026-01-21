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
