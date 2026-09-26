#!/bin/sh
# 从本仓库组装 DeepSeek Harness 的 agent preset。
#
# 用法：
#   sh dsh-preset/install.sh
#
# 可覆盖的环境变量：
#   DSH_HOME   DSH 用户根目录（默认 $HOME/.dsh）
#   PRESET_ID  preset 目录名（默认 evidence-bundle）
set -eu

SCAFFOLD=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCAFFOLD/.." && pwd)
PRESET_ID=${PRESET_ID:-evidence-bundle}
DSH_ROOT=${DSH_HOME:-$HOME/.dsh}
TARGET="$DSH_ROOT/.agent-presets/$PRESET_ID"

[ -f "$REPO_ROOT/SKILL.md" ] || { echo "错误：未在仓库根目录找到 SKILL.md" >&2; exit 1; }
[ -f "$SCAFFOLD/agent.cordis.yml" ] || { echo "错误：缺少 dsh-preset/agent.cordis.yml" >&2; exit 1; }

if [ -e "$TARGET" ]; then
  echo "错误：$TARGET 已存在。请先删除它，或用 PRESET_ID 指定另一个 id。" >&2
  exit 1
fi

SKILL_DIR="$TARGET/skills/build-evidence-bundle"
mkdir -p "$SKILL_DIR"

# 仓库内容即 Skill 目录。排除 evals/（上游运行时安装包同样排除）与 dsh-preset/ 自身。
for item in "$REPO_ROOT"/*; do
  base=$(basename "$item")
  case "$base" in
    evals|dsh-preset) continue ;;
  esac
  cp -R "$item" "$SKILL_DIR/"
done

# preset 平面文件
cp "$SCAFFOLD/preset.yml" "$TARGET/preset.yml"
cp "$SCAFFOLD/agent.cordis.yml" "$TARGET/agent.cordis.yml"

# DSH 宿主适配层：随 Skill 一起安装，SKILL.md 与上游其余内容保持原样
mkdir -p "$SKILL_DIR/references"
cp "$SCAFFOLD/skills/build-evidence-bundle/references/dsh-host-adapter.md" "$SKILL_DIR/references/"

echo "已安装 preset：$TARGET"
echo
echo "下一步："
echo "  1) 确认 DSH 的 preset 选择器里出现「证据卷宗模式」"
echo "  2) 运行依赖按 references/dsh-host-adapter.md 第 2 节「先探测，再按需安装」"
echo "  3) 新建会话并选择该 preset"
