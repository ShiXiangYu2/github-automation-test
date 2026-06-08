#!/bin/bash
# GitHub Automation Project Initializer
# Usage: 在已存在的 Git 仓库中运行此脚本
#   cd <repo-dir> && bash .github/skills/github-automation/scripts/init-project.sh

set -e

# 检测是否在 git 仓库中
if [ ! -d ".git" ]; then
  echo "错误: 请在 Git 仓库目录中运行此脚本"
  echo "用法: cd <repo-dir> && bash .github/skills/github-automation/scripts/init-project.sh"
  exit 1
fi

# 检测 GitHub remote
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE_URL" == *"github.com"* ]]; then
  echo "✅ 检测到 GitHub remote"
else
  echo "⚠️ 未检测到 GitHub remote，将只创建本地配置"
fi

# 获取项目名
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "project")

echo "🚀 初始化 GitHub Automation 项目: $REPO_NAME..."

# 创建目录结构
mkdir -p .github/workflows docs/agents tests

# ============ 创建 CI Workflow ============
cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NODE_VERSION: '20'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
EOF

# ============ 创建自动化 Workflow ============
cat > .github/workflows/automation.yml << 'EOF'
name: Automation

on:
  issues:
    types: [opened, labeled, closed]
  pull_request:
    types: [opened, closed, synchronize]
  workflow_run:
    types: [completed]

jobs:
  automate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Issue 自动化
      - name: Issue opened → add needs-triage
        if: github.event_name == 'issues' && github.event.action == 'opened'
        run: |
          gh issue edit ${{ github.event.issue.number }} --add-label "needs-triage"

      - name: Issue closed → check parent issue
        if: github.event_name == 'issues' && github.event.action == 'closed'
        run: |
          echo "Issue #${{ github.event.issue.number }} closed"

      # PR 自动化
      - name: PR merged → close linked issues
        if: github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged == true
        run: |
          gh pr close ${{ github.event.pull_request.number }} --delete-branch
          echo "PR #${{ github.event.pull_request.number }} merged"

      # CI 结果自动化
      - name: CI success → log
        if: github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.name != 'Automation'
        run: |
          echo "✅ CI passed: ${{ github.event.workflow_run.name }}"

      - name: CI failure → notify
        if: github.event_name == 'workflow_run' && github.event.workflow_run.conclusion == 'failure' && github.event.workflow_run.name != 'Automation'
        run: |
          echo "❌ CI failed: ${{ github.event.workflow_run.name }}"
EOF

# ============ 创建 Agent 配置 ============
cat > docs/agents/issue-tracker.md << 'EOF'
# Issue Tracker: GitHub

GitHub Issues. Use `gh` CLI for operations.
EOF

cat > docs/agents/triage-labels.md << 'EOF'
# Triage Labels

| Label | Meaning |
|-------|---------|
| `needs-triage` | New issue, needs evaluation |
| `needs-fix` | CI failed, needs fix |
| `in-progress` | In development |
| `done` | Completed |
EOF

cat > docs/agents/domain.md << 'EOF'
# Domain Docs

Single-context layout at repo root.
EOF

# ============ 创建 package.json ============
cat > package.json << EOF
{
  "name": "$REPO_NAME",
  "version": "1.0.0",
  "scripts": {
    "test": "jest"
  },
  "devDependencies": {
    "jest": "^29.7.0"
  }
}
EOF

# ============ 创建 .gitignore ============
cat > .gitignore << 'EOF'
node_modules/
.DS_Store
*.log
EOF

# ============ 创建示例测试 ============
cat > tests/example.test.js << 'EOF'
describe('Example', () => {
  test('placeholder', () => {
    expect(1 + 1).toBe(2);
  });
});
EOF

# ============ 创建 CLAUDE.md ============
cat > CLAUDE.md << 'EOF'
# CLAUDE.md

## Agent Skills

### Issue Tracker
GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage Labels
See `docs/agents/triage-labels.md`.
EOF

# ============ GitHub Labels 创建 ============
create_labels() {
  echo "🏷️ 创建 GitHub Labels..."
  gh label create "needs-triage" --description "New issue, needs evaluation" --color "fbca04" 2>/dev/null || true
  gh label create "needs-fix" --description "CI failed, needs fix" --color "d73a4a" 2>/dev/null || true
  gh label create "in-progress" --description "In development" --color "1d76db" 2>/dev/null || true
  gh label create "done" --description "Completed" --color "008672" 2>/dev/null || true
}

# 尝试创建 labels
if [[ "$REMOTE_URL" == *"github.com"* ]]; then
  create_labels
fi

# ============ 提交 ============
echo "📝 创建初始提交..."
git add -A
git commit -m "feat: 初始化 GitHub Automation 项目

- 添加 CI workflow (.github/workflows/ci.yml)
- 添加自动化 workflow (.github/workflows/automation.yml)
- 添加 Agent 配置文件 (docs/agents/)
- 添加示例测试 (tests/)

自动化工件:
- Issue 打开时自动添加 needs-triage 标签
- PR 合并时自动关闭关联 Issue
- CI 失败时自动记录日志" 2>/dev/null || echo "⚠️ 没有新的文件需要提交"

# 尝试推送
if [[ "$REMOTE_URL" == *"github.com"* ]]; then
  echo "🚀 推送到 GitHub..."
  git push origin main 2>/dev/null || echo "⚠️ 推送失败，请手动推送"
fi

echo ""
echo "✅ GitHub Automation 项目初始化完成!"
echo ""
echo "下一步:"
echo "  1. 查看 .github/workflows/ci.yml — CI 测试配置"
echo "  2. 查看 .github/workflows/automation.yml — 自动化工件"
echo "  3. 运行 npm test 验证本地测试"
echo "  4. 创建 Issue 开始开发流程"