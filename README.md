# Claude Code Template (Lean, Modular, Token-Safe)

A production-minded template for **Claude Code** workflows, built for:
- **Modularity**: turn modules on/off (MCP, LSP, Skills, Hooks, Ralph loop, tests, CI) via simple toggles.
- **Token efficiency**: strict read scope allowlist to reduce context bloat and avoid long-context “rotting”.
- **Safety + reproducibility**: guardrails, quality gates, and repeatable commands across local + CI.

> Goal: enable fast, reliable agentic coding without letting the assistant read your whole repo.

---
## 🚀 Quick Start

```bash
# 1. Clone the template
git clone https://github.com/dawenrenhub/claude_code_template.git
cd claude_code_template

# 2. Run the installer (Linux only)
bash install.sh

# 3. Start Ralph Loop
./scripts/ralph_loop.sh
```

---

## 📦 What install.sh Does

The installer is **interactive** and will ask you about your project structure:

### Step 1: Project Structure Selection
```
请选择你的项目结构:
  1) 单体项目 (所有代码在根目录)
  2) Monorepo - 前端在 frontend/
  3) Monorepo - 前端在 client/
  4) Monorepo - 前端在 web/
  5) 自定义前端目录
```

### Step 2: Default Port Selection
```
请选择默认端口:
  1) 3000 (Next.js / Express / 通用)
  2) 5173 (Vite)
  3) 8080 (Vue CLI / 通用)
  4) 4200 (Angular)
  5) 自定义端口
```

### Files Created

| File | Purpose |
|------|---------|
| `.claude/settings.json` | Permissions, hooks, security rules |
| `.claude/hooks/pre_tool_use.py` | Security hook - blocks dangerous commands |
| `.claude/hooks/stop_hook.py` | Quality Gate enforcement on exit |
| `.mcp.json` | MCP servers (Playwright + Browser-use) |
| `scripts/quality_gate.sh` | Automated E2E test runner |
| `scripts/ralph_loop.sh` | Main automation loop |
| `playwright.config.ts` | Playwright configuration |
| `playwright/llm-reporter.ts` | Token-optimized test reporter |
| `tests/e2e/example.spec.ts` | Example test file |
| `PROMPT.md` | Ralph agent instructions |
| `.ralph/config.sh` | Project configuration |

---

## 🔧 V7.1 Features

### 1. Intelligent Port Detection
Automatically detects the correct port based on your framework:
- Vite → 5173
- Next.js → 3000
- Nuxt → 3000
- Or use your configured default

### 2. Monorepo Support
Files are placed in the correct directory based on your project structure:
- Single repo: `./playwright.config.ts`, `./tests/e2e/`
- Monorepo: `./frontend/playwright.config.ts`, `./frontend/tests/e2e/`

### 3. LLM-Optimized Reporter
Custom Playwright reporter that outputs minimal, LLM-friendly test results:
```
══════════════════════════════════════════
📊 测试结果摘要 (LLM Reporter)
══════════════════════════════════════════
❌ 失败: 2/20
✅ 通过: 18

📋 失败详情:
──────────────────────────────────────────
1. login.spec.ts:15
   测试: should login successfully
   错误: Locator expected to be visible
──────────────────────────────────────────
```

### 4. Failure Persistence
Gate failures are saved to `.ralph/last_failure.md`, so Claude remembers what went wrong even after restart.

### 5. Security Hooks
PreToolUse hook blocks dangerous commands:
- `rm -rf /`
- `curl | sh`
- `chmod 777`
- And more...

---

## 📋 System Requirements

- **OS**: Linux only (macOS not supported due to `sed -i` differences)
- **Python**: 3.9+ (auto-upgrade available)
- **Node.js**: 18+
- **Dependencies**: jq, npx, pipx

---
## What’s Included

### Core Claude Code Modules
- **MCP (Model Context Protocol)**: optional tool servers with explicit endpoints and permissions.
- **LSP (Language Server Protocol)**: LSP-friendly structure and consistent lint/format/typecheck entrypoints.
- **Skills**: reusable, composable task playbooks (e.g., generate tests, refactor safely, doc updates).
- **Ralph Loop**: iterative Plan → Implement → Verify → Summarize to keep work small and controlled.
- **Hooks (Quality Gates)**: blocking/non-blocking hooks with fast vs full verification tiers.
- **Repo Read/Write Scope Restriction**: allowlist-based access to reduce tokens and limit risk.
- **Autonomous Basic Testing**: predictable `verify:fast` + `verify:full` pipelines.

### Additional Modules Recommended for Long-Running Stability
- **Rules / Guardrails**: explicit “how Claude should behave” to prevent chaotic changes.
- **Context Management / Auto-Compact**: checkpoint summaries to keep sessions stable over time.
- **Task Runner (Make/Just/Scripts)**: one entrypoint for all quality gates and workflows.
- **CI/CD (GitHub Actions/GitLab CI)**: same verification steps in PRs to keep results reproducible.
- **Secrets & Config Hygiene**: `.env.example`, secret scanning, safe config patterns.
- **Environment & Dependency Locking**: lockfiles + optional Docker to prevent “works on my machine” drift.
- **Changelog & Conventional Commits**: commit history becomes external memory + safer releases.
- **Scaffolding / Codegen**: consistent module/test/doc generation to keep style uniform.
- **Observability / Debug Artifacts**: logs/traces/screenshots for autonomous e2e debugging.
- **PR / Review Templates**: structured diffs so reviewers and agents know what changed and why.
- **Docs System (Architecture/Workflows/ADR)**: durable knowledge base so the model re-derives less.

---

## Recommended Repo Structure

You can adapt, but this structure is reliable:

- `.claude/`
  - `settings.json` (sandbox + allowlists + hooks + compact policy)
  - `hooks/` (hook scripts)
  - `skills/` (reusable skills/playbooks)
  - `mcp/` (MCP configs)
  - `rules/` (behavior guardrails / operating policy)
- `scripts/` (toggles + orchestration)
- `docs/`
  - `ARCHITECTURE.md`
  - `WORKFLOWS.md`
  - `DECISIONS/` (ADRs)
- `frontend/` (optional)
- `backend/` (optional)
- `tests/` (optional)
- `Makefile` (or `justfile`) (recommended)

---

## Modules Matrix (What / How to Toggle / Where)

| Module | Purpose | Toggle | Location |
|---|---|---:|---|
| MCP | Tool access via MCP servers | ON/OFF | `.claude/mcp/` + `scripts/toggle.sh` |
| LSP | Better editing + consistent checks | ON/OFF | editor config + `Makefile` |
| Skills | Reusable “recipes” | ON/OFF | `.claude/skills/` |
| Ralph Loop | Plan→Implement→Verify loop | ON/OFF | `.claude/rules/` + docs |
| Hooks | Enforce gates automatically | ON/OFF + FAST/FULL | `.claude/settings.json` + `.claude/hooks/` |
| Read Scope | Reduce tokens and risk | allowlist | `.claude/settings.json` |
| Verify: Fast | Quick sanity checks | default | `Makefile` / `scripts/verify-fast.sh` |
| Verify: Full | Full test suite (unit + e2e) | manual/CI | `Makefile` / `scripts/verify-full.sh` |
| Auto-Compact | Prevent rotting | threshold | `.claude/settings.json` + `docs/STATE.md` |
| CI | Reproducible gates on PRs | workflow files | `.github/workflows/` or `.gitlab-ci.yml` |
| Secrets Hygiene | Prevent key leaks | scanner | CI + `.gitignore` + `.env.example` |
| Locking | Prevent env drift | lockfiles | repo root |
| Scaffolding | Consistent code style | command | `scripts/scaffold-*` |
| Observability | Debug automation failures | artifacts | `logs/` + CI artifacts |
| PR Template | Structured reviews | template | `.github/` |

---

## Rules / Guardrails (Highly Recommended)

Put explicit rules in `.claude/rules/` (or `CLAUDE.md`). Example principles:

- **Small changes only**: prefer PR-sized diffs; avoid repo-wide refactors unless explicitly requested.
- **Verify every change**: every functional change must include or update tests OR explain why not.
- **Scope discipline**: only read/edit allowed folders; never “explore the repo” without need.
- **No secrets**: never write tokens/keys/passwords into the repo; use `.env` and CI secrets.
- **Explainability**: every output should include:
  - What changed
  - Why
  - How to verify
  - Risk + rollback note

---

## Context Management (Anti-Rotting)

Long sessions drift. This template expects you to checkpoint knowledge:

- `docs/STATE.md`: current status, assumptions, “what is true now”
- `docs/NEXT.md`: next steps
- `docs/DECISIONS/ADR-*.md`: key decisions and why

Recommended auto-compact behavior:
- When context grows large, update `docs/STATE.md` and keep prompts narrowly scoped.

---

## Token Control: Read/Write Allowlist (Core Feature)

This template is built around an allowlist model:

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
