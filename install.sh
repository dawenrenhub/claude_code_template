#!/bin/bash

# ==========================================
# Ralph Loop V7.2: 项目初始化版
# ==========================================
# 新功能:
# 1. 自动下载 ralph-claude-code 模板
# 2. 检测并安装 Superpowers
# 3. 支持新项目/已有项目 clone
# 4. 项目类型选择和配置
# ==========================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 当前脚本所在目录 (模板根目录)
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${BLUE}🔧 Ralph Loop V7.2: 项目初始化版${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"

# ==========================================
# 系统检查: 仅支持 Linux
# ==========================================
if [[ "$(uname)" != "Linux" ]]; then
    echo -e "${RED}❌ 此脚本仅支持 Linux 系统${NC}"
    echo -e "${YELLOW}   检测到: $(uname)${NC}"
    exit 1
fi

# ==========================================
# Step 0: 依赖检查
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
                    exit 1
                fi
                ;;
            git)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew git
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt git
                else
                    echo -e "${RED}❌ 无法自动安装 git，请手动安装${NC}"
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
                    exit 1
                fi
                if ! command -v npx &> /dev/null; then
                    npm install -g npx
                fi
                ;;
            npm)
                if [ "$os_manager" = "brew" ]; then
                    install_with_brew node
                elif [ "$os_manager" = "apt" ]; then
                    install_with_apt nodejs
                    install_with_apt npm
                else
                    echo -e "${RED}❌ 无法自动安装 npm，请手动安装${NC}"
                    exit 1
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
                        echo -e "${YELLOW}⚠️ Node.js 版本过低 (当前: $(node -v)). 需要 >= 18${NC}"
                        exit 1
                    fi
                fi
                npm install -g @anthropic-ai/claude-code@2.076
                ;;
            uvx)
                if command -v pipx &> /dev/null; then
                    pipx install uv
                elif command -v apt-get &> /dev/null; then
                    if command -v sudo &> /dev/null; then
                        sudo apt-get update -y
                        sudo apt-get install -y pipx
                    else
                        apt-get update -y
                        apt-get install -y pipx
                    fi
                    pipx ensurepath 2>/dev/null || true
                    export PATH="$HOME/.local/bin:$PATH"
                    pipx install uv
                else
                    if command -v pip3 &> /dev/null; then
                        pip3 install --break-system-packages uv
                    else
                        echo -e "${RED}❌ 无法安装 uv，请手动安装: pipx install uv${NC}"
                        exit 1
                    fi
                fi
                export PATH="$HOME/.local/bin:$PATH"
                ;;
            *)
                echo -e "${RED}❌ 未知依赖: $1${NC}"
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

check_dependency "git" "apt install git"
check_dependency "jq" "apt install jq"
check_dependency "python3" "apt install python3"
check_dependency "npm" "apt install npm"
check_dependency "npx" "npm install -g npx"
check_dependency "claude" "npm install -g @anthropic-ai/claude-code"
check_dependency "uvx" "pip install uv"

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " response
        response="${response:-y}"
    else
        read -p "$prompt [y/N]: " response
        response="${response:-n}"
    fi
    [[ "$response" =~ ^[Yy]$ ]]
}

detect_package_manager() {
    if [ -f "pnpm-lock.yaml" ]; then
        echo "pnpm"
    elif [ -f "yarn.lock" ]; then
        echo "yarn"
    elif [ -f "package-lock.json" ]; then
        echo "npm"
    else
        echo "npm"
    fi
}

ensure_command() {
    local cmd="$1"
    local apt_pkg="$2"
    local brew_pkg="$3"
    if command -v "$cmd" &> /dev/null; then
        return 0
    fi
    echo -e "${YELLOW}⚠️ 未检测到 $cmd${NC}"
    if ! prompt_yes_no "是否尝试安装 $cmd?" "y"; then
        return 1
    fi
    local os_manager
    os_manager=$(detect_os)
    if [ "$os_manager" = "apt" ] && [ -n "$apt_pkg" ]; then
        install_with_apt "$apt_pkg"
    elif [ "$os_manager" = "brew" ] && [ -n "$brew_pkg" ]; then
        install_with_brew "$brew_pkg"
    else
        echo -e "${RED}❌ 无法自动安装 $cmd，请手动安装${NC}"
        return 1
    fi
    command -v "$cmd" &> /dev/null
}

append_line_if_missing() {
    local file="$1"
    local line="$2"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

ensure_dir() {
    local dir="$1"
    [ -z "$dir" ] && return 0
    mkdir -p "$dir"
}

add_pkg_script_if_missing() {
    local key="$1"
    local value="$2"
    if [ ! -f "package.json" ]; then
        return 0
    fi
    jq --arg k "$key" --arg v "$value" \
        '.scripts = (.scripts // {}) | if .scripts[$k] then . else .scripts[$k] = $v end' \
        package.json > package.json.tmp && mv package.json.tmp package.json
}

has_pkg_dep() {
    local name="$1"
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e --arg n "$name" '.dependencies[$n] or .devDependencies[$n]' package.json >/dev/null 2>&1
}

has_python_req() {
    local name="$1"
    if [ -f "requirements.txt" ] && grep -Eq "^${name}([=<>!]|$)" requirements.txt 2>/dev/null; then
        return 0
    fi
    if [ -f "pyproject.toml" ] && grep -Eq "${name}" pyproject.toml 2>/dev/null; then
        return 0
    fi
    return 1
}

set_pkg_field_if_missing() {
    local key="$1"
    local value="$2"
    if [ ! -f "package.json" ]; then
        return 0
    fi
    jq --arg k "$key" --arg v "$value" \
        'if .[$k] then . else .[$k] = $v end' \
        package.json > package.json.tmp && mv package.json.tmp package.json
}

install_node_dependencies() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm install
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn install
            fi
            ;;
        *)
            npm install
            ;;
    esac
}

install_playwright() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm add -D @playwright/test
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn add -D @playwright/test
            fi
            ;;
        *)
            npm install -D @playwright/test
            ;;
    esac
    npx playwright install --with-deps 2>/dev/null || npx playwright install
}

install_eslint_prettier() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
        *)
            npm install -D eslint prettier eslint-config-prettier eslint-plugin-prettier
            ;;
    esac
    if [ ! -f ".eslintrc.json" ] && [ ! -f "eslint.config.js" ]; then
        cat << 'EOF' > .eslintrc.json
{
  "env": { "browser": true, "node": true, "es2021": true },
  "extends": ["eslint:recommended", "plugin:prettier/recommended"],
  "parserOptions": { "ecmaVersion": "latest", "sourceType": "module" }
}
EOF
    fi
    if [ ! -f ".prettierrc" ]; then
        cat << 'EOF' > .prettierrc
{
  "singleQuote": true,
  "trailingComma": "all"
}
EOF
    fi
}

install_vitest() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D vitest
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D vitest
            ;;
        *)
            npm install -D vitest
            ;;
    esac
    if [ ! -f "vitest.config.ts" ] && [ ! -f "vitest.config.js" ]; then
        cat << 'EOF' > vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
  },
});
EOF
    fi
}

install_jest() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            ensure_command "pnpm" "pnpm" "pnpm" && pnpm add -D jest
            ;;
        yarn)
            ensure_command "yarn" "yarn" "yarn" && yarn add -D jest
            ;;
        *)
            npm install -D jest
            ;;
    esac
    if [ ! -f "jest.config.cjs" ]; then
        cat << 'EOF' > jest.config.cjs
module.exports = {
  testEnvironment: 'node',
};
EOF
    fi
}

setup_node_scripts() {
    local unit_runner="$1"
    add_pkg_script_if_missing "lint" "eslint . --fix"
    add_pkg_script_if_missing "format" "prettier --write ."
    if [ -f "tsconfig.json" ] || has_typescript_dep; then
        add_pkg_script_if_missing "type-check" "tsc --noEmit"
    fi
    if [ "$unit_runner" = "vitest" ]; then
        add_pkg_script_if_missing "test:unit" "vitest run"
    elif [ "$unit_runner" = "jest" ]; then
        add_pkg_script_if_missing "test:unit" "jest"
    fi
    add_pkg_script_if_missing "test:e2e" "npx playwright test"
    if [ -n "$unit_runner" ]; then
        add_pkg_script_if_missing "test" "npm run test:unit && npm run test:e2e"
        add_pkg_script_if_missing "check" "npm run type-check && npm run lint && npm run test:unit"
    fi
}

init_frontend_stack() {
    local frontend_path="$1"
    local choice="$2"

    if [ -n "$frontend_path" ]; then
        mkdir -p "$frontend_path"
    fi

    case "$choice" in
        node)
            (cd "$frontend_path" && {
                init_node_stack
                if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
                    if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                        install_eslint_prettier
                    fi
                fi
                echo -e "${BLUE}选择前端单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1)
                            if ! has_pkg_dep "vitest"; then
                                install_vitest
                            fi
                            UNIT_RUNNER="vitest"; break ;;
                        2)
                            if ! has_pkg_dep "jest"; then
                                install_jest
                            fi
                            UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done
                if ! has_playwright_dep; then
                    if prompt_yes_no "是否安装 Playwright (E2E)?" "y"; then
                        install_playwright
                    fi
                fi
                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    setup_node_scripts "$UNIT_RUNNER"
                fi
            })
            ;;
        ts)
            (cd "$frontend_path" && {
                init_typescript_stack
                if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
                    if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                        install_eslint_prettier
                    fi
                fi
                echo -e "${BLUE}选择前端单测框架:${NC}"
                echo -e "  1) Vitest"
                echo -e "  2) Jest"
                echo -e "  3) 跳过"
                UNIT_RUNNER=""
                while true; do
                    read -p "请输入选项 [1-3]: " UNIT_CHOICE
                    case "$UNIT_CHOICE" in
                        1)
                            if ! has_pkg_dep "vitest"; then
                                install_vitest
                            fi
                            UNIT_RUNNER="vitest"; break ;;
                        2)
                            if ! has_pkg_dep "jest"; then
                                install_jest
                            fi
                            UNIT_RUNNER="jest"; break ;;
                        3) break ;;
                        *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                    esac
                done
                if ! has_playwright_dep; then
                    if prompt_yes_no "是否安装 Playwright (E2E)?" "y"; then
                        install_playwright
                    fi
                fi
                if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                    setup_node_scripts "$UNIT_RUNNER"
                fi
            })
            ;;
        custom)
            (cd "$frontend_path" && init_custom_stack)
            ;;
        skip)
            echo -e "${YELLOW}已跳过前端初始化${NC}"
            ;;
    esac
}

init_backend_fastapi() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if [ ! -f "main.py" ]; then
            cat << 'PY_EOF' > main.py
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "ok"}
PY_EOF
        fi
        if prompt_yes_no "是否安装 FastAPI 依赖?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^fastapi' requirements.txt 2>/dev/null || echo "fastapi" >> requirements.txt
            grep -q '^uvicorn' requirements.txt 2>/dev/null || echo "uvicorn" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
            else
                pip3 install -r requirements.txt
            fi
        fi
    })
}

init_backend_flask() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if [ ! -f "app.py" ]; then
            cat << 'PY_EOF' > app.py
from flask import Flask

app = Flask(__name__)

@app.get("/")
def index():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(debug=True)
PY_EOF
        fi
        if prompt_yes_no "是否安装 Flask 依赖?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^flask' requirements.txt 2>/dev/null || echo "flask" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
            else
                pip3 install -r requirements.txt
            fi
        fi
    })
}

init_backend_django() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_python_stack "yes"
        setup_python_tooling
        if prompt_yes_no "是否安装 Django 并创建项目?" "y"; then
            if [ ! -f "requirements.txt" ]; then
                : > requirements.txt
            fi
            grep -q '^django' requirements.txt 2>/dev/null || echo "django" >> requirements.txt
            if [ -d ".venv" ]; then
                ./.venv/bin/pip install -r requirements.txt
                read -p "请输入 Django 项目名: " DJANGO_PROJECT
                if [ -n "$DJANGO_PROJECT" ]; then
                    ./.venv/bin/django-admin startproject "$DJANGO_PROJECT" .
                fi
            else
                pip3 install -r requirements.txt
                read -p "请输入 Django 项目名: " DJANGO_PROJECT
                if [ -n "$DJANGO_PROJECT" ]; then
                    django-admin startproject "$DJANGO_PROJECT" .
                fi
            fi
        fi
    })
}

init_backend_express() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        if [ ! -f "package.json" ]; then
            npm init -y
        fi
        npm install express
        if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
            if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                install_eslint_prettier
            fi
        fi
        echo -e "${BLUE}选择后端单测框架:${NC}"
        echo -e "  1) Vitest"
        echo -e "  2) Jest"
        echo -e "  3) 跳过"
        UNIT_RUNNER=""
        while true; do
            read -p "请输入选项 [1-3]: " UNIT_CHOICE
            case "$UNIT_CHOICE" in
                1)
                    if ! has_pkg_dep "vitest"; then
                        install_vitest
                    fi
                    UNIT_RUNNER="vitest"; break ;;
                2)
                    if ! has_pkg_dep "jest"; then
                        install_jest
                    fi
                    UNIT_RUNNER="jest"; break ;;
                3) break ;;
                *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
            esac
        done
        if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
            setup_node_scripts "$UNIT_RUNNER"
        fi
        if [ ! -f "server.js" ]; then
            cat << 'JS_EOF' > server.js
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ status: 'ok' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server running on ${port}`);
});
JS_EOF
        fi
    })
}

init_backend_nest() {
    local backend_path="$1"
    if ! ensure_command "npx" "npm" "node"; then
        return 1
    fi
    if [ -d "$backend_path" ] && [ -n "$(ls -A "$backend_path" 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠️ 后端目录非空，跳过 Nest 初始化${NC}"
        return 0
    fi
    npx @nestjs/cli new "$backend_path"
    (cd "$backend_path" && {
        if ! has_pkg_dep "eslint" || ! has_pkg_dep "prettier"; then
            if prompt_yes_no "是否安装 ESLint + Prettier?" "y"; then
                install_eslint_prettier
            fi
        fi
        echo -e "${BLUE}选择后端单测框架:${NC}"
        echo -e "  1) Vitest"
        echo -e "  2) Jest"
        echo -e "  3) 跳过"
        UNIT_RUNNER=""
        while true; do
            read -p "请输入选项 [1-3]: " UNIT_CHOICE
            case "$UNIT_CHOICE" in
                1)
                    if ! has_pkg_dep "vitest"; then
                        install_vitest
                    fi
                    UNIT_RUNNER="vitest"; break ;;
                2)
                    if ! has_pkg_dep "jest"; then
                        install_jest
                    fi
                    UNIT_RUNNER="jest"; break ;;
                3) break ;;
                *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
            esac
        done
        if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
            setup_node_scripts "$UNIT_RUNNER"
        fi
    })
}

init_backend_gin() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_go_stack
        if prompt_yes_no "是否生成 Go 测试/覆盖率入口 (Makefile)?" "n"; then
            if [ ! -f "Makefile" ]; then
                cat << 'EOF' > Makefile
test:
	go test ./...

coverage:
	go test ./... -coverprofile=coverage.out
EOF
            fi
        fi
        if prompt_yes_no "是否安装 Gin 并生成示例?" "y"; then
            go get github.com/gin-gonic/gin
            if [ ! -f "main.go" ]; then
                cat << 'GO_EOF' > main.go
package main

import "github.com/gin-gonic/gin"

func main() {
  r := gin.Default()
  r.GET("/", func(c *gin.Context) {
    c.JSON(200, gin.H{"status": "ok"})
  })
  r.Run()
}
GO_EOF
            fi
        fi
    })
}

init_backend_rust_axum() {
    local backend_path="$1"
    mkdir -p "$backend_path"
    (cd "$backend_path" && {
        init_rust_stack
        if prompt_yes_no "是否生成 Rust 测试/覆盖率入口 (Makefile)?" "n"; then
            if [ ! -f "Makefile" ]; then
                cat << 'EOF' > Makefile
test:
	cargo test

coverage:
	@echo "如需覆盖率，建议安装 cargo-tarpaulin"
EOF
            fi
        fi
        if prompt_yes_no "是否安装 Axum 并生成示例?" "y"; then
            cargo add axum tokio --features tokio/full
            if [ ! -f "src/main.rs" ]; then
                cat << 'RS_EOF' > src/main.rs
use axum::{routing::get, Json, Router};
use serde_json::json;

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(|| async { Json(json!({"status": "ok"})) }));
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
RS_EOF
            fi
        fi
    })
}

init_backend_stack() {
    local backend_path="$1"
    local choice="$2"

    BACKEND_INITIALIZED=true
    BACKEND_STACK="$choice"

    case "$choice" in
        fastapi) init_backend_fastapi "$backend_path" ;;
        flask) init_backend_flask "$backend_path" ;;
        django) init_backend_django "$backend_path" ;;
        express) init_backend_express "$backend_path" ;;
        nest) init_backend_nest "$backend_path" ;;
        gin) init_backend_gin "$backend_path" ;;
        axum) init_backend_rust_axum "$backend_path" ;;
        custom) (cd "$backend_path" && init_custom_stack) ;;
        skip) echo -e "${YELLOW}已跳过后端初始化${NC}" ;;
    esac
}

install_typescript_deps() {
    local manager
    manager=$(detect_package_manager)
    case "$manager" in
        pnpm)
            if ensure_command "pnpm" "pnpm" "pnpm"; then
                pnpm add -D typescript ts-node @types/node
            fi
            ;;
        yarn)
            if ensure_command "yarn" "yarn" "yarn"; then
                yarn add -D typescript ts-node @types/node
            fi
            ;;
        *)
            npm install -D typescript ts-node @types/node
            ;;
    esac
    if [ ! -f "tsconfig.json" ]; then
        npx tsc --init
    fi
}

has_playwright_dep() {
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e '.dependencies["@playwright/test"] or .devDependencies["@playwright/test"]' package.json >/dev/null 2>&1
}

has_typescript_dep() {
    if [ ! -f "package.json" ]; then
        return 1
    fi
    jq -e '.dependencies["typescript"] or .devDependencies["typescript"]' package.json >/dev/null 2>&1
}

init_node_stack() {
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}初始化 Node.js 项目...${NC}"
        npm init -y
    fi
    if prompt_yes_no "是否设置 package.json 为 ES Module (type: module)?" "n"; then
        set_pkg_field_if_missing "type" "module"
    fi
}

init_typescript_stack() {
    if [ ! -f "package.json" ]; then
        echo -e "${YELLOW}初始化 TypeScript 项目...${NC}"
        npm init -y
    fi
    install_typescript_deps
    if [ ! -f "tsconfig.json" ]; then
        cat << 'EOF' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noEmit": true
  },
  "include": ["src", "tests"]
}
EOF
    fi
    if prompt_yes_no "是否设置 package.json 为 ES Module (type: module)?" "n"; then
        set_pkg_field_if_missing "type" "module"
    fi
}

init_python_stack() {
    local create_requirements="${1:-yes}"
    if [ ! -f "pyproject.toml" ] && [ ! -f "requirements.txt" ]; then
        echo -e "${YELLOW}初始化 Python 项目...${NC}"
        if [ "$create_requirements" = "yes" ]; then
            : > requirements.txt
        fi
    fi
    if prompt_yes_no "是否创建 Python 虚拟环境 (.venv)?" "y"; then
        python3 -m venv .venv
    fi
    if [ -f "requirements.txt" ] && prompt_yes_no "是否安装 Python 依赖 (pip install -r requirements.txt)?" "y"; then
        if [ -d ".venv" ]; then
            ./.venv/bin/pip install -r requirements.txt
        else
            if prompt_yes_no "检测到系统 Python 受管理(PEP 668)。是否使用 --break-system-packages 安装?" "n"; then
                pip3 install --break-system-packages -r requirements.txt
            else
                echo -e "${YELLOW}⚠️ 已跳过系统级安装，请先创建 .venv 再安装依赖${NC}"
            fi
        fi
    fi
}

pip_install_list() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        return 0
    fi
    if [ -d ".venv" ]; then
        ./.venv/bin/pip install "${pkgs[@]}"
    else
        if prompt_yes_no "检测到系统 Python 受管理(PEP 668)。是否使用 --break-system-packages 安装?" "n"; then
            pip3 install --break-system-packages "${pkgs[@]}"
        else
            echo -e "${YELLOW}⚠️ 已跳过系统级安装，请先创建 .venv 再安装依赖${NC}"
        fi
    fi
}

setup_python_tooling() {
    if ! has_python_req "pytest" || ! has_python_req "pytest-cov"; then
        if prompt_yes_no "是否安装 pytest + pytest-cov?" "y"; then
            pip_install_list pytest pytest-cov
        fi
    fi
        if [ ! -f "pytest.ini" ]; then
            cat << 'EOF' > pytest.ini
[pytest]
testpaths = tests
EOF
        fi
    fi
    if ! has_python_req "ruff"; then
        if prompt_yes_no "是否安装 ruff 进行代码检查?" "y"; then
            pip_install_list ruff
        fi
    fi
        if [ ! -f "ruff.toml" ]; then
            cat << 'EOF' > ruff.toml
[lint]
select = ["E", "F", "I"]
EOF
        fi
    fi
    if ! has_python_req "mypy"; then
        if prompt_yes_no "是否安装 mypy 进行类型检查?" "y"; then
            pip_install_list mypy
        fi
    fi
        if [ ! -f "mypy.ini" ]; then
            cat << 'EOF' > mypy.ini
[mypy]
python_version = 3.11
ignore_missing_imports = true
EOF
        fi
    fi
    if ! has_python_req "playwright"; then
        if prompt_yes_no "是否安装 Python Playwright (E2E)?" "n"; then
            pip_install_list playwright
        fi
    fi
    if has_python_req "playwright"; then
        if [ -d ".venv" ]; then
            ./.venv/bin/python -m playwright install --with-deps 2>/dev/null || ./.venv/bin/python -m playwright install
        else
            python3 -m playwright install --with-deps 2>/dev/null || python3 -m playwright install
        fi
    fi
}

init_go_stack() {
    if ! ensure_command "go" "golang" "go"; then
        return 1
    fi
    if [ ! -f "go.mod" ]; then
        read -p "请输入 Go module 名称 (如 github.com/you/project): " GO_MODULE
        if [ -n "$GO_MODULE" ]; then
            go mod init "$GO_MODULE"
        fi
    fi
    if prompt_yes_no "是否运行 go mod tidy?" "y"; then
        go mod tidy
    fi
    if prompt_yes_no "是否需要 golangci-lint (手动安装提示)?" "n"; then
        echo -e "${YELLOW}请参考: https://golangci-lint.run/usage/install/${NC}"
    fi
}

init_rust_stack() {
    if ! ensure_command "cargo" "cargo" "rust"; then
        return 1
    fi
    if [ ! -f "Cargo.toml" ]; then
        cargo init
    fi
    if prompt_yes_no "是否需要 rustfmt/clippy 检查?" "n"; then
        rustup component add rustfmt clippy 2>/dev/null || true
    fi
}

init_custom_stack() {
    read -p "请输入初始化命令 (将在项目目录执行): " CUSTOM_CMD
    if [ -n "$CUSTOM_CMD" ]; then
        eval "$CUSTOM_CMD"
    fi
}

# ==========================================
# Step 0.5: 根目录 Claude 初始化检查
# ==========================================
echo -e "\n${YELLOW}[Step 0.5] 检测根目录 Claude 初始化...${NC}"

ROOT_CLAUDE_DIR="$TEMPLATE_DIR/.claude"
ROOT_SETTINGS_FILE="$ROOT_CLAUDE_DIR/settings.json"
ROOT_SETTINGS_LOCAL_FILE="$ROOT_CLAUDE_DIR/settings.local.json"
ROOT_MCP_FILE="$TEMPLATE_DIR/.mcp.json"

root_claude_initialized() {
    if [ -f "$ROOT_MCP_FILE" ] && { [ -f "$ROOT_SETTINGS_FILE" ] || [ -f "$ROOT_SETTINGS_LOCAL_FILE" ]; }; then
        return 0
    fi
    return 1
}

if root_claude_initialized; then
        echo -e "${GREEN}✓ 根目录 Claude 已初始化${NC}"
else
        echo -e "${YELLOW}⚠️ 根目录未检测到完整 Claude 初始化，开始初始化...${NC}"

        if command -v claude &> /dev/null; then
            INIT_OUTPUT=$(cd "$TEMPLATE_DIR" && claude init 2>&1) || {
                echo -e "${RED}❌ claude init 失败:${NC}"
                echo "$INIT_OUTPUT"
                exit 1
            }
        fi

        # 若 claude init 未生成配置，则创建最小可用配置以支持 planning.sh
        if [ ! -f "$ROOT_SETTINGS_FILE" ]; then
                mkdir -p "$ROOT_CLAUDE_DIR"
                cat << 'EOF' > "$ROOT_SETTINGS_FILE"
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
            "Bash(curl:*)|sh",
            "Bash(wget:*)|sh",
            "Read(/etc/passwd)",
            "Read(/etc/shadow)",
            "Read(./.env)",
            "Read(./.env.*)"
        ],
        "ask": [
            "Bash(git push:*)",
            "Bash(git commit:*)",
            "Bash(npm publish:*)",
            "Bash(rm:*)"
        ]
    }
}
EOF
        fi

        if [ ! -f "$ROOT_MCP_FILE" ]; then
                cat << 'EOF' > "$ROOT_MCP_FILE"
{
    "mcpServers": {
        "superpowers": {
            "command": "npx",
            "args": ["-y", "@anthropic-ai/superpower"]
        }
    }
}
EOF
        fi

        if [ -f "$ROOT_SETTINGS_FILE" ] && [ -f "$ROOT_MCP_FILE" ]; then
            echo -e "${GREEN}✓ 根目录 Claude 初始化完成${NC}"
        else
            echo -e "${RED}❌ 根目录 Claude 初始化失败，请手动执行: claude init${NC}"
            exit 1
        fi
fi

# ==========================================
# Step 1: 检测并下载 ralph-claude-code
# ==========================================
echo -e "\n${YELLOW}[Step 1] 检测 ralph-claude-code 模板...${NC}"

RALPH_REPO_DIR="$TEMPLATE_DIR/ralph-claude-code"

if [ -d "$RALPH_REPO_DIR" ]; then
    echo -e "${GREEN}✓ ralph-claude-code 已存在${NC}"
    echo -e "  路径: $RALPH_REPO_DIR"
    
    # 询问是否更新
    echo ""
    read -p "是否更新到最新版本? [y/N]: " UPDATE_RALPH
    if [[ "$UPDATE_RALPH" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}更新 ralph-claude-code...${NC}"
        cd "$RALPH_REPO_DIR"
        git pull origin main || git pull origin master || true
        cd "$TEMPLATE_DIR"
        echo -e "${GREEN}✓ 更新完成${NC}"
    fi
else
    echo -e "${YELLOW}下载 ralph-claude-code...${NC}"
    git clone https://github.com/frankbria/ralph-claude-code.git "$RALPH_REPO_DIR"
    echo -e "${GREEN}✓ 下载完成${NC}"
fi

# ==========================================
# Step 2: 检测并安装 Superpowers
# ==========================================
echo -e "\n${YELLOW}[Step 2] 检测 Superpowers 插件...${NC}"

check_superpowers() {
    # 检查新版本地配置
    if [ -f "$HOME/.claude.json" ]; then
        if grep -q "superpower" "$HOME/.claude.json" 2>/dev/null; then
            return 0
        fi
    fi

    # 检查全局 MCP 配置
    if [ -f "$HOME/.claude/mcp.json" ]; then
        if grep -q "superpower" "$HOME/.claude/mcp.json" 2>/dev/null; then
            return 0
        fi
    fi
    
    # 检查 claude settings
    if [ -f "$HOME/.claude/settings.json" ]; then
        if grep -q "superpower" "$HOME/.claude/settings.json" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

if check_superpowers; then
    echo -e "${GREEN}✓ Superpowers 已安装${NC}"
else
    echo -e "${YELLOW}⚠️ Superpowers 未检测到，自动安装...${NC}"
    
    # 使用 claude mcp add 命令（官方推荐方式）
    if command -v claude &> /dev/null; then
        claude mcp add superpowers -- npx -y @anthropic-ai/superpower 2>/dev/null || {
            echo -e "${YELLOW}  使用备用方式安装...${NC}"
            
            # 确保目录存在
            mkdir -p "$HOME/.claude"
            
                        # 创建或更新 mcp.json
            if [ -f "$HOME/.claude/mcp.json" ]; then
                # 使用 jq 添加
                jq '.mcpServers.superpowers = {"command": "npx", "args": ["-y", "@anthropic-ai/superpower"]}' \
                    "$HOME/.claude/mcp.json" > "$HOME/.claude/mcp.json.tmp" && \
                    mv "$HOME/.claude/mcp.json.tmp" "$HOME/.claude/mcp.json"
            else
                cat << 'EOF' > "$HOME/.claude/mcp.json"
{
  "mcpServers": {
    "superpowers": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/superpower"]
    }
  }
}
EOF
            fi
        }
        echo -e "${GREEN}✓ Superpowers 安装成功${NC}"
    else
        echo -e "${RED}❌ Claude CLI 不可用，无法安装 Superpowers${NC}"
    fi
fi

# ==========================================
# Step 3: 询问项目类型 (新项目 / 已有项目)
# ==========================================
echo -e "\n${YELLOW}[Step 3] 项目配置...${NC}"

echo ""
echo -e "${BLUE}请选择项目类型:${NC}"
echo -e "  1) 新项目 - 创建一个全新的项目"
echo -e "  2) 已有项目 - 从 Git 仓库 clone"
echo -e "  3) 本地项目 - 选择已有本地目录"
echo ""
read -p "请输入选项 [1-3] (默认: 1): " PROJECT_TYPE

case "$PROJECT_TYPE" in
    2)
        # 已有项目 - clone
        echo ""
        echo -e "${CYAN}请输入 Git 仓库地址:${NC}"
        read -p "Git URL: " GIT_URL
        
        if [ -z "$GIT_URL" ]; then
            echo -e "${RED}❌ Git URL 不能为空${NC}"
            exit 1
        fi
        
        echo ""
        read -p "请输入分支名 (默认: main): " GIT_BRANCH
        GIT_BRANCH="${GIT_BRANCH:-main}"
        
        # 从 URL 提取项目名
        PROJECT_NAME=$(basename "$GIT_URL" .git)
        echo ""
        read -p "项目文件夹名 (默认: $PROJECT_NAME): " CUSTOM_NAME
        PROJECT_NAME="${CUSTOM_NAME:-$PROJECT_NAME}"
        
        PROJECT_DIR="$TEMPLATE_DIR/$PROJECT_NAME"
        
        if [ -d "$PROJECT_DIR" ]; then
            echo -e "${YELLOW}⚠️ 目录已存在: $PROJECT_DIR${NC}"
            read -p "是否覆盖? [y/N]: " OVERWRITE
            if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
                rm -rf "$PROJECT_DIR"
            else
                echo -e "${RED}❌ 操作取消${NC}"
                exit 1
            fi
        fi
        
        echo -e "${YELLOW}克隆项目...${NC}"
        git clone -b "$GIT_BRANCH" "$GIT_URL" "$PROJECT_DIR"
        echo -e "${GREEN}✓ 项目克隆成功${NC}"
        ;;
    3)
        echo ""
        echo -e "${CYAN}请输入本地项目路径:${NC}"
        read -p "项目路径: " LOCAL_PROJECT_PATH

        if [ -z "$LOCAL_PROJECT_PATH" ]; then
            echo -e "${RED}❌ 项目路径不能为空${NC}"
            exit 1
        fi

        if [ ! -d "$LOCAL_PROJECT_PATH" ]; then
            echo -e "${RED}❌ 本地目录不存在: $LOCAL_PROJECT_PATH${NC}"
            exit 1
        fi

        PROJECT_DIR="$(cd "$LOCAL_PROJECT_PATH" && pwd)"
        PROJECT_NAME="$(basename "$PROJECT_DIR")"
        echo -e "${GREEN}✓ 使用本地项目目录: $PROJECT_DIR${NC}"
        ;;
    *)
        # 新项目
        echo ""
        echo -e "${CYAN}请输入项目名称:${NC}"
        read -p "项目名: " PROJECT_NAME
        
        if [ -z "$PROJECT_NAME" ]; then
            echo -e "${RED}❌ 项目名不能为空${NC}"
            exit 1
        fi
        
        # 替换空格为下划线
        PROJECT_NAME=$(echo "$PROJECT_NAME" | tr ' ' '_')
        PROJECT_DIR="$TEMPLATE_DIR/$PROJECT_NAME"
        
        if [ -d "$PROJECT_DIR" ]; then
            echo -e "${YELLOW}⚠️ 目录已存在: $PROJECT_DIR${NC}"
            read -p "是否覆盖? [y/N]: " OVERWRITE
            if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
                rm -rf "$PROJECT_DIR"
            else
                echo -e "${RED}❌ 操作取消${NC}"
                exit 1
            fi
        fi
        
        mkdir -p "$PROJECT_DIR"
        echo -e "${GREEN}✓ 创建项目目录: $PROJECT_DIR${NC}"
        ;;
esac

# ==========================================
# Step 4: 进入项目目录，配置项目结构
# ==========================================
echo -e "\n${YELLOW}[Step 4] 项目结构配置...${NC}"

cd "$PROJECT_DIR"
echo -e "  工作目录: ${BLUE}$PROJECT_DIR${NC}"

echo ""
echo -e "${BLUE}请选择你的项目结构:${NC}"
echo -e "  1) 单体项目 (所有代码在根目录)"
echo -e "  2) Monorepo - 前端在 frontend/"
echo -e "  3) Monorepo - 前端在 client/"
echo -e "  4) Monorepo - 前端在 web/"
echo -e "  5) 自定义前端目录"
echo ""
read -p "请输入选项 [1-5] (默认: 1): " PROJECT_STRUCTURE

case "$PROJECT_STRUCTURE" in
    2)
        FRONTEND_DIR="frontend"
        ;;
    3)
        FRONTEND_DIR="client"
        ;;
    4)
        FRONTEND_DIR="web"
        ;;
    5)
        read -p "请输入前端目录名称: " CUSTOM_DIR
        FRONTEND_DIR="${CUSTOM_DIR:-frontend}"
        ;;
    *)
        FRONTEND_DIR=""
        ;;
esac

# 设置文件路径
if [ -n "$FRONTEND_DIR" ]; then
    PLAYWRIGHT_CONFIG_DIR="$FRONTEND_DIR"
    TESTS_DIR="$FRONTEND_DIR/tests/e2e"
    echo -e "${GREEN}✓ Monorepo 模式: 前端目录 = $FRONTEND_DIR${NC}"
else
    PLAYWRIGHT_CONFIG_DIR="."
    TESTS_DIR="tests/e2e"
    echo -e "${GREEN}✓ 单体项目模式${NC}"
fi

echo ""
echo -e "${BLUE}请选择默认端口:${NC}"
echo -e "  1) 3000 (Next.js / Express / 通用)"
echo -e "  2) 5173 (Vite)"
echo -e "  3) 8080 (Vue CLI / 通用)"
echo -e "  4) 4200 (Angular)"
echo -e "  5) 自定义端口"
echo ""
read -p "请输入选项 [1-5] (默认: 1): " PORT_CHOICE

case "$PORT_CHOICE" in
    2)
        DEFAULT_PORT="5173"
        ;;
    3)
        DEFAULT_PORT="8080"
        ;;
    4)
        DEFAULT_PORT="4200"
        ;;
    5)
        read -p "请输入端口号: " CUSTOM_PORT
        DEFAULT_PORT="${CUSTOM_PORT:-3000}"
        ;;
    *)
        DEFAULT_PORT="3000"
        ;;
esac

echo -e "${GREEN}✓ 默认端口: $DEFAULT_PORT${NC}"

# ==========================================
# Step 5: 技术栈初始化
# ==========================================
echo -e "\n${YELLOW}[Step 5] 技术栈初始化...${NC}"

FRONTEND_PATH="$PROJECT_DIR"
if [ -n "$FRONTEND_DIR" ]; then
    FRONTEND_PATH="$PROJECT_DIR/$FRONTEND_DIR"
    mkdir -p "$FRONTEND_PATH"
fi

BACKEND_DIR=""
BACKEND_REQUESTED=false
BACKEND_INITIALIZED=false
BACKEND_STACK=""

if prompt_yes_no "是否有后端?" "n"; then
    BACKEND_REQUESTED=true
    read -p "后端目录名 (默认: backend): " BACKEND_DIR_INPUT
    BACKEND_DIR="${BACKEND_DIR_INPUT:-backend}"
else
    if [[ "$PROJECT_TYPE" =~ ^2$ ]]; then
        for candidate in backend server api; do
            if [ -d "$PROJECT_DIR/$candidate" ]; then
                if prompt_yes_no "检测到后端目录: $candidate，是否使用?" "y"; then
                    BACKEND_DIR="$candidate"
                    BACKEND_REQUESTED=true
                    break
                fi
            fi
        done
        if [ "$BACKEND_REQUESTED" = false ]; then
            if prompt_yes_no "未检测到后端目录，是否初始化后端?" "n"; then
                BACKEND_REQUESTED=true
                read -p "后端目录名 (默认: backend): " BACKEND_DIR_INPUT
                BACKEND_DIR="${BACKEND_DIR_INPUT:-backend}"
            fi
        fi
    fi
fi

HAS_BACKEND=false
BACKEND_PATH=""
if [ -n "$BACKEND_DIR" ]; then
    BACKEND_PATH="$PROJECT_DIR/$BACKEND_DIR"
    if [ -d "$BACKEND_PATH" ]; then
        HAS_BACKEND=true
    fi
fi

if [[ "$PROJECT_TYPE" =~ ^2$ ]]; then
    HAS_STACK=false

    if [ -f "$FRONTEND_PATH/package.json" ]; then
        HAS_STACK=true
        echo -e "${GREEN}✓ 检测到 Node.js 项目${NC}"
        (cd "$FRONTEND_PATH" && {
            if prompt_yes_no "是否安装前端依赖?" "y"; then
                install_node_dependencies
            fi

            if prompt_yes_no "是否安装 ESLint + Prettier?" "n"; then
                install_eslint_prettier
            fi

            if [ -f "tsconfig.json" ] || has_typescript_dep; then
                echo -e "${GREEN}✓ 检测到 TypeScript 配置${NC}"
                if ! has_typescript_dep; then
                    if prompt_yes_no "未检测到 typescript 依赖，是否安装?" "y"; then
                        install_typescript_deps
                    fi
                fi
            else
                if prompt_yes_no "是否为 TypeScript 项目?" "n"; then
                    install_typescript_deps
                fi
            fi

            echo -e "${BLUE}选择单测框架:${NC}"
            echo -e "  1) Vitest"
            echo -e "  2) Jest"
            echo -e "  3) 跳过"
            UNIT_RUNNER=""
            while true; do
                read -p "请输入选项 [1-3]: " UNIT_CHOICE
                case "$UNIT_CHOICE" in
                    1) install_vitest; UNIT_RUNNER="vitest"; break ;;
                    2) install_jest; UNIT_RUNNER="jest"; break ;;
                    3) break ;;
                    *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                esac
            done

            if has_playwright_dep; then
                if prompt_yes_no "是否安装 Playwright 浏览器?" "y"; then
                    npx playwright install
                fi
            else
                if prompt_yes_no "未检测到 @playwright/test，是否安装?" "y"; then
                    install_playwright
                fi
            fi

            if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                setup_node_scripts "$UNIT_RUNNER"
            fi
        })
    fi

    if [ -n "$BACKEND_PATH" ] && [ -d "$BACKEND_PATH" ]; then
        if [ -f "$BACKEND_PATH/pyproject.toml" ] || [ -f "$BACKEND_PATH/requirements.txt" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Python 后端${NC}"
            (cd "$BACKEND_PATH" && {
                init_python_stack "no"
                setup_python_tooling
            })
        fi

        if [ -f "$BACKEND_PATH/go.mod" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Go 后端${NC}"
            (cd "$BACKEND_PATH" && init_go_stack)
        fi

        if [ -f "$BACKEND_PATH/Cargo.toml" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Rust 后端${NC}"
            (cd "$BACKEND_PATH" && init_rust_stack)
        fi
    else
        if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Python 项目${NC}"
            init_python_stack "no"
            setup_python_tooling
        fi

        if [ -f "go.mod" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Go 项目${NC}"
            init_go_stack
        fi

        if [ -f "Cargo.toml" ]; then
            HAS_STACK=true
            echo -e "${GREEN}✓ 检测到 Rust 项目${NC}"
            init_rust_stack
        fi
    fi

    if [ "$HAS_STACK" = false ]; then
        echo -e "${YELLOW}⚠️ 未检测到已知技术栈${NC}"
        echo -e "${BLUE}请选择要初始化的技术栈:${NC}"
        echo -e "  1) Node.js (JavaScript)"
        echo -e "  2) TypeScript"
        echo -e "  3) Python"
        echo -e "  4) Go"
        echo -e "  5) Rust"
        echo -e "  6) 自定义命令"
        echo -e "  7) 跳过"
        while true; do
            read -p "请输入选项 [1-7]: " STACK_CHOICE
            case "$STACK_CHOICE" in
                1) init_node_stack; break ;;
                2) init_typescript_stack; break ;;
                3) init_python_stack; break ;;
                4) init_go_stack; break ;;
                5) init_rust_stack; break ;;
                6) init_custom_stack; break ;;
                7) echo -e "${YELLOW}已跳过技术栈初始化${NC}"; break ;;
                *) echo -e "${YELLOW}请输入 1-7 的有效选项${NC}" ;;
            esac
        done
    fi

    if [ "$HAS_BACKEND" = true ]; then
        if [ -f "$BACKEND_PATH/pyproject.toml" ] || [ -f "$BACKEND_PATH/requirements.txt" ]; then
            echo -e "${GREEN}✓ 检测到 Python 后端${NC}"
            (cd "$BACKEND_PATH" && init_python_stack "no")
        elif [ -f "$BACKEND_PATH/package.json" ]; then
            echo -e "${GREEN}✓ 检测到 Node.js 后端${NC}"
            if prompt_yes_no "是否安装后端依赖?" "y"; then
                (cd "$BACKEND_PATH" && install_node_dependencies)
            fi
            if prompt_yes_no "是否安装 ESLint + Prettier?" "n"; then
                (cd "$BACKEND_PATH" && install_eslint_prettier)
            fi
            echo -e "${BLUE}选择后端单测框架:${NC}"
            echo -e "  1) Vitest"
            echo -e "  2) Jest"
            echo -e "  3) 跳过"
            UNIT_RUNNER=""
            while true; do
                read -p "请输入选项 [1-3]: " UNIT_CHOICE
                case "$UNIT_CHOICE" in
                    1) (cd "$BACKEND_PATH" && install_vitest); UNIT_RUNNER="vitest"; break ;;
                    2) (cd "$BACKEND_PATH" && install_jest); UNIT_RUNNER="jest"; break ;;
                    3) break ;;
                    *) echo -e "${YELLOW}请输入 1-3 的有效选项${NC}" ;;
                esac
            done
            if prompt_yes_no "是否补齐 package.json scripts?" "y"; then
                (cd "$BACKEND_PATH" && setup_node_scripts "$UNIT_RUNNER")
            fi
        elif [ -f "$BACKEND_PATH/go.mod" ]; then
            echo -e "${GREEN}✓ 检测到 Go 后端${NC}"
            (cd "$BACKEND_PATH" && init_go_stack)
        elif [ -f "$BACKEND_PATH/Cargo.toml" ]; then
            echo -e "${GREEN}✓ 检测到 Rust 后端${NC}"
            (cd "$BACKEND_PATH" && init_rust_stack)
        else
            if prompt_yes_no "未检测到后端配置，是否初始化后端?" "n"; then
                echo -e "${BLUE}请选择后端技术栈:${NC}"
                echo -e "  1) FastAPI"
                echo -e "  2) Flask"
                echo -e "  3) Django"
                echo -e "  4) Express"
                echo -e "  5) NestJS"
                echo -e "  6) Go (Gin)"
                echo -e "  7) Rust (Axum)"
                echo -e "  8) 自定义命令"
                echo -e "  9) 跳过"
                while true; do
                    read -p "请输入选项 [1-9]: " BACKEND_CHOICE
                    case "$BACKEND_CHOICE" in
                        1) init_backend_stack "$BACKEND_PATH" fastapi; break ;;
                        2) init_backend_stack "$BACKEND_PATH" flask; break ;;
                        3) init_backend_stack "$BACKEND_PATH" django; break ;;
                        4) init_backend_stack "$BACKEND_PATH" express; break ;;
                        5) init_backend_stack "$BACKEND_PATH" nest; break ;;
                        6) init_backend_stack "$BACKEND_PATH" gin; break ;;
                        7) init_backend_stack "$BACKEND_PATH" axum; break ;;
                        8) init_backend_stack "$BACKEND_PATH" custom; break ;;
                        9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                        *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
                    esac
                done
            fi
        fi
    elif [ "$BACKEND_REQUESTED" = true ]; then
        if prompt_yes_no "是否需要初始化后端?" "n"; then
            echo -e "${BLUE}请选择后端技术栈:${NC}"
            echo -e "  1) FastAPI"
            echo -e "  2) Flask"
            echo -e "  3) Django"
            echo -e "  4) Express"
            echo -e "  5) NestJS"
            echo -e "  6) Go (Gin)"
            echo -e "  7) Rust (Axum)"
            echo -e "  8) 自定义命令"
            echo -e "  9) 跳过"
            while true; do
                read -p "请输入选项 [1-9]: " BACKEND_CHOICE
                case "$BACKEND_CHOICE" in
                    1) init_backend_stack "$BACKEND_PATH" fastapi; break ;;
                    2) init_backend_stack "$BACKEND_PATH" flask; break ;;
                    3) init_backend_stack "$BACKEND_PATH" django; break ;;
                    4) init_backend_stack "$BACKEND_PATH" express; break ;;
                    5) init_backend_stack "$BACKEND_PATH" nest; break ;;
                    6) init_backend_stack "$BACKEND_PATH" gin; break ;;
                    7) init_backend_stack "$BACKEND_PATH" axum; break ;;
                    8) init_backend_stack "$BACKEND_PATH" custom; break ;;
                    9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                    *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
                esac
            done
        fi
    fi
else
    echo -e "${BLUE}请选择前端技术栈:${NC}"
    echo -e "  1) Node.js (JavaScript)"
    echo -e "  2) TypeScript"
    echo -e "  3) 自定义命令"
    echo -e "  4) 跳过前端"
    while true; do
        read -p "请输入选项 [1-4]: " FRONT_CHOICE
        case "$FRONT_CHOICE" in
            1) init_frontend_stack "$FRONTEND_PATH" node; break ;;
            2) init_frontend_stack "$FRONTEND_PATH" ts; break ;;
            3) init_frontend_stack "$FRONTEND_PATH" custom; break ;;
            4) init_frontend_stack "$FRONTEND_PATH" skip; break ;;
            *) echo -e "${YELLOW}请输入 1-4 的有效选项${NC}" ;;
        esac
    done

    if prompt_yes_no "是否需要初始化后端?" "n"; then
        echo -e "${BLUE}请选择后端技术栈:${NC}"
        echo -e "  1) FastAPI"
        echo -e "  2) Flask"
        echo -e "  3) Django"
        echo -e "  4) Express"
        echo -e "  5) NestJS"
        echo -e "  6) Go (Gin)"
        echo -e "  7) Rust (Axum)"
        echo -e "  8) 自定义命令"
        echo -e "  9) 跳过"
        while true; do
            read -p "请输入选项 [1-9]: " BACKEND_CHOICE
            case "$BACKEND_CHOICE" in
                1) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" fastapi; break ;;
                2) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" flask; break ;;
                3) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" django; break ;;
                4) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" express; break ;;
                5) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" nest; break ;;
                6) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" gin; break ;;
                7) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" axum; break ;;
                8) init_backend_stack "$PROJECT_DIR/$BACKEND_DIR" custom; break ;;
                9) echo -e "${YELLOW}已跳过后端初始化${NC}"; break ;;
                *) echo -e "${YELLOW}请输入 1-9 的有效选项${NC}" ;;
            esac
        done
    fi

fi

# ==========================================
# Step 6: 创建目录结构
# ==========================================
echo -e "\n${YELLOW}[Step 6] 创建目录结构...${NC}"

if prompt_yes_no "是否创建标准目录结构 (src, tests/unit, tests/e2e, docs, logs)?" "y"; then
    ensure_dir "src"
    ensure_dir "tests/unit"
    ensure_dir "$TESTS_DIR"
    ensure_dir "docs"
    ensure_dir "logs"
else
    ensure_dir "$TESTS_DIR"
    ensure_dir "docs"
    ensure_dir "logs"
fi

if [ -n "$FRONTEND_DIR" ]; then
    ensure_dir "$FRONTEND_DIR"
fi

ensure_dir "$PLAYWRIGHT_CONFIG_DIR/playwright"

echo -e "${GREEN}✓ 目录结构已创建${NC}"

# ==========================================
# Step 7: 创建 .mcp.json
# ==========================================
echo -e "\n${YELLOW}[Step 7] 创建 .mcp.json...${NC}"

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
    },
    "superpowers": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/superpower"]
    }
  }
}
EOF

echo -e "${GREEN}✓ .mcp.json${NC}"

# ==========================================
# Step 8: 创建示例测试和配置
# ==========================================
echo -e "\n${YELLOW}[Step 8] 创建辅助文件...${NC}"

# 示例测试
cat << 'TS_EOF' > "$TESTS_DIR/example.spec.ts"
import { test, expect } from '@playwright/test';

test.describe('示例测试', () => {
  test('首页加载', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.*/);
  });
});
TS_EOF

echo -e "${GREEN}✓ $TESTS_DIR/example.spec.ts${NC}"

# Playwright 配置
if [ -n "$FRONTEND_DIR" ]; then
    PLAYWRIGHT_CONFIG_PATH="$FRONTEND_DIR/playwright.config.ts"
    mkdir -p "$FRONTEND_DIR/playwright"
else
    PLAYWRIGHT_CONFIG_PATH="playwright.config.ts"
    mkdir -p "playwright"
fi

cat << TS_EOF > "$PLAYWRIGHT_CONFIG_PATH"
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 0,
  
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:$DEFAULT_PORT',
    headless: true,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  
  reporter: [['list']],
  
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
TS_EOF

echo -e "${GREEN}✓ $PLAYWRIGHT_CONFIG_PATH${NC}"

# .gitignore (追加缺失项)
append_line_if_missing .gitignore "# Ralph"
append_line_if_missing .gitignore "logs/"
append_line_if_missing .gitignore "test-results/"
append_line_if_missing .gitignore "playwright-report/"
append_line_if_missing .gitignore "# Node / System"
append_line_if_missing .gitignore "node_modules/"
append_line_if_missing .gitignore ".env"
append_line_if_missing .gitignore ".env.*"
append_line_if_missing .gitignore ".DS_Store"
append_line_if_missing .gitignore "dist/"
append_line_if_missing .gitignore "build/"
append_line_if_missing .gitignore "coverage/"
append_line_if_missing .gitignore "__pycache__/"
append_line_if_missing .gitignore "*.pyc"
append_line_if_missing .gitignore ".venv/"
append_line_if_missing .gitignore ".pytest_cache/"

echo -e "${GREEN}✓ 辅助文件已创建${NC}"

# ==========================================
# 完成
# ==========================================
echo ""
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Ralph Loop V7.2 安装完成！${NC}"
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo ""
echo -e "📁 项目目录: ${CYAN}$PROJECT_DIR${NC}"
echo ""
echo -e "创建的文件:"
echo -e "  ✓ .mcp.json"
echo -e "  ✓ $PLAYWRIGHT_CONFIG_PATH"
echo -e "  ✓ $TESTS_DIR/example.spec.ts"
echo -e "  ✓ .gitignore"
if [ "$BACKEND_INITIALIZED" = true ] && [ -n "$BACKEND_DIR" ]; then
    echo -e "  ✓ (后端) $BACKEND_DIR"
fi
echo -e "创建的目录:"
echo -e "  ✓ logs"
echo -e "  ✓ docs"
echo -e "  ✓ tests/e2e"
echo -e "  ✓ playwright"
echo ""
echo -e "🚀 快速开始:"
echo ""
echo -e "  ${CYAN}# 1. 进入项目目录${NC}"
echo -e "  cd $PROJECT_NAME"
echo ""
echo -e "  ${CYAN}# 2. 启动 Claude${NC}"
echo -e "  claude"
echo ""

# ==========================================
# Step 16: 生成 Manifest 文件
# ==========================================
echo -e "\n${YELLOW}[Step 16] 生成安装清单...${NC}"

generate_manifest() {
    local manifest_file="$PROJECT_DIR/.template-manifest.json"
    local timestamp=$(date -Iseconds)
    
    # 根据项目结构确定实际路径
    local tests_dir_path="$TESTS_DIR"
    local playwright_config_path="$PLAYWRIGHT_CONFIG_PATH"
    local playwright_dir_path="playwright"
    if [ -n "$FRONTEND_DIR" ]; then
        playwright_dir_path="$FRONTEND_DIR/playwright"
    fi

    local backend_files_json="[]"
    local backend_dirs_json="[]"
    local backend_category=""
    if [ "$BACKEND_INITIALIZED" = true ] && [ -n "$BACKEND_DIR" ]; then
        local backend_files=()
        local backend_path="$PROJECT_DIR/$BACKEND_DIR"
        for f in "main.py" "app.py" "server.js" "package.json" "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "requirements.txt" "pyproject.toml" "go.mod" "Cargo.toml" "src/main.rs"; do
            if [ -f "$backend_path/$f" ]; then
                backend_files+=("$BACKEND_DIR/$f")
            fi
        done
        backend_files_json=$(printf '%s\n' "${backend_files[@]}" | jq -R . | jq -s .)
        backend_dirs_json=$(printf '%s\n' "$BACKEND_DIR" | jq -R . | jq -s .)
        backend_category=$(cat << EOF
    "backend-init": {
      "name": "后端初始化",
      "description": "由 install.sh 初始化的后端骨架",
      "files": $backend_files_json,
      "directories": $backend_dirs_json
    },
EOF
)
    fi

# CI/CD
if prompt_yes_no "是否生成 GitHub Actions CI?" "n"; then
        ensure_dir ".github/workflows"
        cat << 'EOF' > .github/workflows/ci.yml
name: CI

on:
    push:
        branches: ["main"]
    pull_request:

jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v4

            - name: Set up Node
                if: hashFiles('package.json') != ''
                uses: actions/setup-node@v4
                with:
                    node-version: 18
                    cache: npm

            - name: Install Node deps
                if: hashFiles('package.json') != ''
                run: npm ci

            - name: Node lint/typecheck/unit
                if: hashFiles('package.json') != ''
                run: |
                    npm run lint --if-present
                    npm run type-check --if-present
                    npm run test:unit --if-present

            - name: Set up Python
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                uses: actions/setup-python@v5
                with:
                    python-version: '3.11'

            - name: Install Python deps
                if: hashFiles('requirements.txt') != ''
                run: pip install -r requirements.txt

            - name: Python lint/typecheck/unit
                if: hashFiles('requirements.txt') != '' || hashFiles('pyproject.toml') != ''
                run: |
                    ruff check . || true
                    mypy . || true
                    pytest -q || true

            - name: Go test
                if: hashFiles('go.mod') != ''
                run: go test ./...

            - name: Rust test
                if: hashFiles('Cargo.toml') != ''
                run: cargo test
EOF
fi
    
    cat << MANIFEST_EOF > "$manifest_file"
{
  "version": "7.2",
  "installed_at": "$timestamp",
  "project_name": "$PROJECT_NAME",
  "frontend_dir": "$FRONTEND_DIR",
  "default_port": "$DEFAULT_PORT",
  "categories": {
        "mcp-config": {
      "name": "MCP 配置",
      "description": "Model Context Protocol 服务器配置",
      "files": [".mcp.json"],
      "directories": []
    },
$backend_category
        "tooling-config": {
            "name": "工具链与测试配置",
            "description": "Lint/Test/CI 配置文件",
            "files": [
                ".eslintrc.json",
                ".prettierrc",
                "vitest.config.ts",
                "jest.config.cjs",
                "pytest.ini",
                "ruff.toml",
                "mypy.ini",
                ".github/workflows/ci.yml",
                "Makefile"
            ],
            "directories": [".github/workflows"]
        },
        "test-examples": {
            "name": "测试示例",
            "description": "Playwright 测试模板和配置",
            "files": ["$tests_dir_path/example.spec.ts", "$playwright_config_path"],
            "directories": ["$tests_dir_path", "$playwright_dir_path"]
        },
    "meta-files": {
      "name": "项目元文件",
      "description": "日志、文档目录",
      "files": [],
            "directories": ["logs", "docs"]
    }
  }
}
MANIFEST_EOF

    echo -e "${GREEN}✓ .template-manifest.json${NC}"
}

generate_manifest

echo -e "${GREEN}✓ .template-manifest.json${NC}"

echo ""
echo -e "${CYAN}💡 提示: 如需卸载模板文件，运行 ./uninstall.sh${NC}"
echo ""
