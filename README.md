# Claude Code Template (V0.2)

一个面向 Claude Code 的项目启动与协作模板，重点提供：
- 可交互安装（支持新建/克隆/本地项目）
- 前端/后端技术栈初始化与依赖安装
- MCP 配置与 Playwright 基础测试配置
- 可选卸载与恢复

---
## 🚀 Quick Start

```bash
git clone https://github.com/dawenrenhub/claude_code_template.git
cd claude_code_template

# 安装（Linux）
bash install.sh
```

---
## 📦 install.sh 做了什么

### 1) 项目来源选择
- 新项目
- Git 克隆项目
- 本地已有项目

### 2) 目录结构选择
支持单体项目或前端子目录模式（frontend/client/web/自定义）。

### 3) 技术栈初始化（前端/后端）
会明确询问技术栈类别，不会默认创建 package.json。

**前端选项**
- Node.js (JavaScript)
- TypeScript
- 自定义命令
- 跳过前端

**后端选项**
- FastAPI / Flask / Django
- Express / NestJS
- Go (Gin)
- Rust (Axum)
- 自定义命令 / 跳过

### 4) Playwright 基础配置
生成基础测试配置和示例测试，适配单体/前端子目录。

---
## ✅ install.sh 详细执行清单

### 系统依赖与环境
- 检查 Linux 系统
- 检查并尝试安装依赖：git / jq / python3 / npx / claude / uvx

### 根目录（模板仓库）
- Claude 根目录初始化（缺失则补齐）：
  - .claude/settings.json
  - .mcp.json
- 下载/更新 ralph-claude-code
- Superpowers 检测与安装（读取 ~/.claude.json / ~/.claude/mcp.json / ~/.claude/settings.json）

### 项目来源选择
- 新项目创建
- Git 克隆项目
- 本地已有项目

### 结构与端口
- 前端目录结构选择：单体或前端子目录（frontend/client/web/自定义）
- 默认端口选择

### 技术栈初始化（显式询问）
**前端**
- Node.js / TypeScript / 自定义 / 跳过
- Node.js：创建 package.json，并安装 Playwright
- TypeScript：创建 package.json + tsconfig.json，并安装 TypeScript 依赖与 Playwright
 - 可选安装 ESLint + Prettier
 - 可选选择单测框架（Vitest/Jest）

**后端**
- FastAPI / Flask / Django / Express / NestJS / Gin / Axum / 自定义 / 跳过
- 选择后端会创建 backend/ 并生成示例入口与依赖配置
 - Python 可选 pytest/ruff/mypy/Playwright
 - Node 可选 ESLint + Prettier、Vitest/Jest
 - Go/Rust 可选生成测试/覆盖率入口

**克隆项目模式**
- 自动检测现有配置（package.json / requirements.txt / go.mod / Cargo.toml 等）
- 根据检测结果询问是否安装依赖/补齐缺失配置
- 不会默认创建 package.json

### 项目目录内创建的目录
- logs
- docs
- src（可选）
- tests/unit（可选）
- tests/e2e
- playwright
- 若前端为子目录，则目录创建在对应子目录下

### 项目目录内生成的文件
- .mcp.json
- playwright.config.ts
- tests/e2e/example.spec.ts
- .gitignore（追加）
- .template-manifest.json
 - 可能生成：.eslintrc.json / .prettierrc / vitest.config.ts / jest.config.cjs
 - 可能生成：pytest.ini / ruff.toml / mypy.ini
 - 可选生成：.github/workflows/ci.yml

### 后端初始化生成物（示例）
**FastAPI**
- backend/main.py
- backend/requirements.txt

**Flask**
- backend/app.py
- backend/requirements.txt

**Django**
- backend/requirements.txt
- Django 项目结构（django-admin startproject 生成）

**Express**
- backend/package.json
- backend/server.js

**NestJS**
- Nest CLI 生成的完整结构

**Go (Gin)**
- backend/go.mod
- backend/main.go

**Rust (Axum)**
- backend/Cargo.toml
- backend/src/main.rs

---
## ✅ 生成/修改的内容（项目子目录）

**目录**
- logs
- docs
- tests/e2e
- playwright

**文件**
- .mcp.json
- playwright.config.ts
- tests/e2e/example.spec.ts
- .gitignore
- .template-manifest.json

> 若选择后端初始化，会在 backend/ 下生成对应骨架文件和依赖配置，并记录到清单。

---
## 🔧 其他脚本

- init.sh：环境或流程初始化入口
- planning.sh：规划/需求整理流程
- restore.sh：恢复卸载时备份
- uninstall.sh：卸载模板生成内容（支持根目录模块与子项目循环删除）

---
## 🧹 卸载与恢复

```bash
bash uninstall.sh
```

卸载流程支持：
- 选择是否删除根目录模块
- 循环输入子项目目录进行删除
- 可选备份与恢复

---
## 📋 System Requirements

- Linux
- Node.js 18+
- Python 3.9+
- jq / npx / pipx

### Read allowlist
Include only what Claude needs:
- source folders (`frontend/`, `backend/`, `scripts/`, `.claude/`, `docs/`, `tests/`)
Exclude:
- dependencies (`node_modules/`, `.venv/`)
- artifacts (`dist/`, `build/`, `.next/`)
- logs and datasets (`logs/`, `data/`)
- large binaries (`*.zip`, `*.mp4`, etc.)

### Write allowlist
Allow writing only where you want changes:
- `.claude/**`, `scripts/**`, `docs/**`, and selected code folders

> Result: fewer tokens, fewer surprises, and safer autonomous operation.

---

## Verification Strategy (Fast vs Full)

### Fast Verify (default / hook-friendly)
- lint
- format check (optional)
- typecheck
- unit tests (subset)

### Full Verify (manual or CI-required)
- full unit tests
- integration tests
- e2e tests (Playwright/Cypress/etc.)
- build checks

Keep the default quick. Use full when merging or releasing.

---

## Task Runner (One Entry for Everything)

Recommended `Makefile` targets (or `justfile` equivalents):
- `make verify-fast`
- `make verify-full`
- `make lint`
- `make typecheck`
- `make test`
- `make e2e`
- `make format`
- `make clean`

This prevents “how do I run X again?” loops and makes automation reliable.

---

## CI/CD (Make Local == Make CI)

Set CI to run:
- On PR: `verify-fast`
- On main merge: `verify-full`

Publish test reports and artifacts (especially e2e traces/screenshots) to make failures debuggable.

---

## Secrets & Config Hygiene

- Add `.env.example` for required variables.
- Put real secrets in:
  - local `.env` (gitignored)
  - CI secrets (GitHub/GitLab)
- Add secret scanning in CI if possible.

---

## Dependency & Environment Locking

- Keep lockfiles committed:
  - Node: `pnpm-lock.yaml` / `package-lock.json`
  - Python: `uv.lock` / `poetry.lock` / pinned requirements
- Optional: add Docker for reproducible testing.

---

## Changelog & Conventional Commits

Use structured commits:
- `feat: ...`, `fix: ...`, `refactor: ...`, `test: ...`, `docs: ...`

Keep a `CHANGELOG.md` so release notes are easy and history is searchable.

---

## Scaffolding / Codegen (Consistency at Scale)

Add scripts like:
- `scripts/scaffold-module.sh`
- `scripts/scaffold-endpoint.sh`
- `scripts/scaffold-test.sh`

Each scaffold should create:
- source file(s)
- tests
- docs snippet
- export wiring (if needed)

---

## Observability & Debug Artifacts

For autonomous debugging (especially e2e):
- standardized logs with request IDs
- store traces/screenshots on failure
- keep artifacts in CI for inspection

---

## PR / Review Templates

Add a PR template that forces:
- What / Why
- How to test
- Risk / rollback
- Screenshots/traces (if UI/e2e)

This makes agent changes reviewable and safe.

---

## Quick Start (Typical Git Flow)

```bash
git add README.md
git commit -m "Add template README"
git branch -M main
git push -u origin main
