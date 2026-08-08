#!/usr/bin/env bash
# ============================================================================
# SmartSub -> GitHub Actions 一键部署脚本
# ----------------------------------------------------------------------------
# 前置:
#   1. 一个 GitHub Classic PAT, 勾选 repo + gist 权限 (workflow 由 repo 覆盖)
#   2. Python 含 pynacl:  pip install pynacl
#
# 用法:
#   bash setup_github.sh <PAT> <USERNAME> <REPO> <VISIBILITY> \
#                        [SERVERCHAN] [PUSHPLUS] [TG_BOT] [TG_CHAT]
#
# 例 (公开仓库, 仅配 Gist 发布):
#   bash setup_github.sh ghp_xxx xwx-xwx smartsub-aggregate public
#
# 例 (含全部告警):
#   bash setup_github.sh ghp_xxx xwx-xwx smartsub-aggregate public \
#        SCTxxx PPushxxx 123456:ABCdef 987654321
#
# 说明:
#   - GIST_TOKEN 直接用 PAT 本身 (PAT 已含 gist 权限)
#   - 仓库默认公开(免费 Actions 分钟); 若填 private 则耗 2000 分钟/月额度
#   - 首次运行后会新建一个私密 Gist; 订阅链接固定, 无需 GIST_ID
# ============================================================================
set -e

PAT="$1"; USER="${2:-xwx-xwx}"; REPO="${3:-smartsub-aggregate}"; VIS="${4:-public}"
SC="${5:-}"; PP="${6:-}"; TGB="${7:-}"; TGC="${8:-}"

DIR="$(cd "$(dirname "$0")" && pwd)"
PY="${PYTHON:-python}"

echo "==> 1/3 创建仓库 $USER/$REPO (visibility=$VIS)"
curl -s -H "Authorization: token $PAT" -H "Accept: application/vnd.github+json" \
  -d "{\"name\":\"$REPO\",\"private\":$([ "$VIS" = "private" ] && echo true || echo false),\"auto_init\":false}" \
  https://api.github.com/user/repos >/dev/null || echo "  (仓库可能已存在, 继续)"

echo "==> 2/3 初始化并推送代码"
cd "$DIR"
rm -rf .git
git init -q
git checkout -b main 2>/dev/null || git branch -M main
git add -A
git commit -q -m "init: SmartSub on GitHub Actions (full upstream config, every 6h)"
git remote remove origin 2>/dev/null || true
git remote add origin "https://x-access-token:${PAT}@github.com/${USER}/${REPO}.git"
git push -u origin main

echo "==> 3/3 写入 Secrets"
"$PY" scripts/gh_secret.py "$PAT" "$USER" "$REPO" GIST_TOKEN "$PAT"
[ -n "$SC"  ] && "$PY" scripts/gh_secret.py "$PAT" "$USER" "$REPO" SERVERCHAN_KEY "$SC"
[ -n "$PP"  ] && "$PY" scripts/gh_secret.py "$PAT" "$USER" "$REPO" PUSHPLUS_TOKEN "$PP"
[ -n "$TGB" ] && "$PY" scripts/gh_secret.py "$PAT" "$USER" "$REPO" TELEGRAM_BOT_TOKEN "$TGB"
[ -n "$TGC" ] && "$PY" scripts/gh_secret.py "$PAT" "$USER" "$REPO" TELEGRAM_CHAT_ID "$TGC"

echo ""
echo "✅ 部署完成! 打开 https://github.com/$USER/$REPO/actions 手动触发首次运行,"
echo "   或等待定时 (每6小时). 订阅链接会在 Job Summary 与私密 Gist 中给出。"
