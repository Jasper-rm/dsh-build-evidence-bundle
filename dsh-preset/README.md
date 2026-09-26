# DeepSeek Harness preset（证据卷宗模式）

本目录把本仓库的 `build-evidence-bundle` Skill 组装成一个
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（DSH）agent preset，
使其成为一个可在 GUI 里直接选择的会话模式。

**本目录不复制仓库内容。** 仓库根目录就是 Skill 目录，`install.sh` 在安装时把它组装进
preset；这样 Skill 只有一个真源，本目录只维护「DSH 平面」的三样东西：composition、
元数据和宿主适配层。

## 目录内容

    dsh-preset/
    ├── install.sh                                  # 组装并安装 preset
    ├── preset.yml                                  # roster 元数据（名称、说明）
    ├── agent.cordis.yml                            # composition：工具面 + persona
    ├── README.md                                   # 本文件
    └── skills/build-evidence-bundle/references/
        └── dsh-host-adapter.md                     # DSH 宿主适配层（安装时并入 Skill）

## 安装

    sh dsh-preset/install.sh

默认装到 `$DSH_HOME/.agent-presets/evidence-bundle`（`DSH_HOME` 未设置时为 `$HOME/.dsh`）。
DSH Desktop 的 `DSH_HOME` 形如 `~/Library/Application Support/dsh-desktop/harness`，
可在 DSH 的 shell 工具里用 `echo "$DSH_HOME"` 确认。

安装后：

1. 在 DSH 的 preset 选择器里选择「证据卷宗模式」，新建会话；
2. 首次使用前按 Skill 内 `references/dsh-host-adapter.md` 第 2 节做一次能力探测，
   缺什么补什么（图片能力只需 Python 依赖；视频需 FFmpeg 套件；Office 入卷需 LibreOffice）。

## 前置条件

| 项 | 要求 |
| --- | --- |
| DSH | 支持 agent preset 的版本（roster 可列出本地 `.agent-presets`） |
| Python | **3.10+**，并安装 `scripts/requirements.txt`（`python-docx`、`Pillow`） |
| FFmpeg 套件 | 可选；仅在需要视频截帧时。必须同时提供 `ffmpeg` 与 `ffprobe` |
| LibreOffice | 可选；仅在 Office 材料确需入卷时。还需 PDF 光栅化工具（`pdftoppm` 或 `mutool`） |

缺可选工具时，Skill 会按自身规则保留可复核盘点并返回 HOLD/BLOCKED，不会伪造截帧或来源。

## 设计要点

- **plane 划分**：`agent.cordis.yml` 是 agent-plane composition，只注册工具与 prompt 段；
  注册表本身、沙箱与审批栈、持久化、模型路由都留在 host composition。
- **无 service provider**：本文件所有行都不 `provide` service，因此不需要 `isolate` realm。
- **Skill 随 preset 走**：`skill-filesystem` 行的 `customSkillDirs` 用 preset 自身目录作
  `baseUrl` 解析 `skills/`，所以 Skill 随 preset 一起被复制、安装和升级，不依赖用户级
  skill 根目录。
- **上游内容不改**：`SKILL.md` 与上游 `references/` 逐字节保持原样；DSH 相关事实全部集中在
  新增的 `references/dsh-host-adapter.md`，便于上游发新版时整体替换。

## 更新

Skill 内容更新 = 直接更新仓库根目录（那是唯一真源），然后重新安装：

    rm -rf "$DSH_HOME/.agent-presets/evidence-bundle" && sh dsh-preset/install.sh

只改 DSH 平面时（composition / preset.yml / 适配层），重跑同一条命令即可。

## 卸载

    rm -rf "$DSH_HOME/.agent-presets/evidence-bundle"

随后重启 DSH Host。只想临时停用时，把 `agent.cordis.yml` 中相应行注释掉即可。

## 许可

随本仓库，MIT，见根目录 `LICENSE`。
