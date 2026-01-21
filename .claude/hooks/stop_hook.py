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
