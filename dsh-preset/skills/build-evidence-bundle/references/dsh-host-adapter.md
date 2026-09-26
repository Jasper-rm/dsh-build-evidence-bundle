# DSH 宿主适配说明（本 preset 添加，非上游内容）

本文件由 DeepSeek Harness 的 `evidence-bundle` preset 添加，用于把上游 Skill
（`build-evidence-bundle` v19.0.1，Codex 形态）接到 DSH 运行时上。

上游的 `SKILL.md` 与其余 `references/` 保持原样：**业务规则以上游为准，宿主事实以本文件为准**。
两者冲突时，按本文件执行宿主操作，按上游执行证据规则。

## 1. 先定位 Skill 目录

用 `skill` 工具加载 `build-evidence-bundle` 后，结果里会给出该 Skill 的基目录，形如：

    Base directory for this skill: /Users/<用户>/Library/Application Support/dsh-desktop/harness/.agent-presets/evidence-bundle/skills/build-evidence-bundle

下文用 `$SKILL_DIR` 指代这个绝对路径。**先把它记下来，后面每条命令都用绝对路径。**

两个硬事实：

- `scripts/` 下的脚本以顶层模块互相 import（`from path_safety import ...`）。因此必须用
  **脚本完整路径**调用（Python 会把脚本所在目录放进 `sys.path`），**不要** `cd scripts/` 后再调用。
- `bash` 工具的每次调用都是**全新 shell**：cwd、环境变量、函数都不保留。不要依赖上一条命令的
  `cd` 或 `export`；要么写绝对路径，要么给 bash 工具传 `workdir` 参数。

## 2. 解释器：先检测，后安装

上游要求 Python 3.10+。仓库自带能力探测，先用它拿到现状（本机实测可直接运行）：

    PYTHONDONTWRITEBYTECODE=1 "$PY" "$SKILL_DIR/scripts/office_capabilities.py" --json

`$PY` 见下方「本机已就绪的共享运行环境」。

`PYTHONDONTWRITEBYTECODE=1` 是必要的：Skill 安装目录位于会话工作区之外、对会话只读，
不设它 Python 会尝试写 `__pycache__` 并产生噪声（虽然会静默失败）。

输出各能力的 `status: available|unavailable`，覆盖 `python_pillow`、`python_docx`、
`office_to_pdf`（LibreOffice）以及 PDF→PNG 工具。**这是判断"缺什么"的唯一依据，不要靠猜。**

### 运行环境：先探测，再按需安装

> 下面这段是**某台 macOS 机器上安装该 preset 时的实测记录**，用来说明一个可用环境的
> 具体形状；你的机器路径与版本可能不同，以第 2 节开头的 `office_capabilities.py` 实测为准。

#### 示例记录：已就绪的共享运行环境

preset 安装时已在用户级目录建好隔离环境，后续会话**直接使用它**：

    VENV="$HOME/.local/share/evidence-bundle/venv"     # Python 3.10.20 + python-docx 1.2.0 + Pillow 12.3.0
    PY="$VENV/bin/python"

下文所有 `$PY` 都指这个解释器。该目录位于会话工作区之外，**读取可用、写入需要审批或直接被拒绝**，
因此除非用户明确要求，不要往里面装包。系统 `python3` 仍是 3.9.6，低于上游要求的 3.10+，
不要用它跑 `scripts/`。

FFmpeg 套件已随 preset 安装就绪，`ffmpeg` 与 `ffprobe` 都在 PATH 上（Homebrew，9.0.2）：

    ffmpeg -version     # ffmpeg version 9.0.2
    ffprobe -version    # ffprobe version 9.0.2

因此截帧命令里的 `--ffmpeg/--ffprobe` 可省略（脚本默认从 PATH 查找）；需要显式指定时用
`/opt/homebrew/bin/ffmpeg` 与 `/opt/homebrew/bin/ffprobe`。**已在合成视频上完成过真实截帧验证**，
不要仅凭"命令存在"就宣称视频能力可用；环境变动后仍应实跑一次。

实测边界（同一台机器）：

- **已跑通**：图片只读盘点、Office 只读预检、Manifest 校验与法律门禁、DOCX 生成、覆盖矩阵、
  QA 结构门禁；以及**视频材料入卷全流程**（合成 fixture：截帧 3 帧 → 正式生成 → 3 个附件页 /
  3 个书签 / 2 个 PAGEREF / 页脚 PAGE 域）。
- **失败路径同样已验证**：损坏视频会以真实解码错误停下并**不产生任何帧或目录**，不会伪造截帧。
- **PDF 光栅化已就绪**：`pdftoppm` 26.09.0 与 `mutool` 1.28.5 都在 PATH 上，
  `office_capabilities.py` 报 `pdf_to_png: available`，并按本 Skill 的发现顺序优先选 `pdftoppm`。
  两者都以 180 DPI 渲染 PNG；实测含中文的 PDF 两条路径都能正常出图（分辨率与文本区墨迹占比一致，
  无缺字或空白页）。
- **Office 转换已就绪，但有两个必踩的坑**：LibreOffice 26.8.0.3 已安装（官方 dmg，位于
  `/Applications/LibreOffice.app`），Office → PDF → PNG 全链路已实测跑通。但下面的
  「Office 转换：两个本机陷阱」是**动手前必读**：踩中会静默产出一份中文全是方框、
  看起来却完全正常的证据页。
- 任何任务的 QA 都会保持 `HOLD/RENDER_REVIEW_UNAVAILABLE`：本机没有独立页面渲染复核能力
  （需要 LibreOffice 或等效渲染链）。这是上游设计的正确结果，不要声称视觉验收已通过。

环境陷阱（实测）：

- **不要用 `/tmp`**：macOS 上 `/tmp` 是指向 `/private/tmp` 的符号链接，上游路径安全门禁会拒绝
  经过符号链接的输出路径（报"输出路径不得经过符号链接或目录联接"）。派生目录一律建在 workspace
  内的真实路径下。
- **最终 DOCX 不要写进材料目录**：生成器把材料目录视为只读保护区，输出落在其中会被直接拒绝
  （报"输出路径不得落入材料目录（只读保护）"）。把 DOCX 写到材料目录的上层或同级目录。
- **若还要用 Homebrew 装别的东西**：本机 `HOMEBREW_BOTTLE_DOMAIN` / `HOMEBREW_API_DOMAIN` 指向
  USTC 镜像，该镜像缺少本机（macOS 27）的预编译包，会报 `no bottle available` 或校验和不匹配。
  需要时把两个域同时覆盖为官方源：
  `HOMEBREW_API_DOMAIN=https://formulae.brew.sh/api HOMEBREW_BOTTLE_DOMAIN=https://ghcr.io/v2/homebrew/core`。

### Office 转换：两个本机陷阱（动手前必读）

**陷阱一：LibreOffice 不在 PATH 上。** 官方 dmg 装到 `/Applications`，而本 Skill 的
`discover(["soffice","libreoffice"])` 只按名字在 PATH 里找，因此默认探测会报
`office_to_pdf: unavailable` —— 明明装了却报没有。本机已用用户级包装器解决：

    ~/.local/bin/soffice                                  # 普通文件，不是符号链接
    ~/.config/dsh-evidence-bundle/libreoffice-fonts.conf  # 它注入的字体配置

`~/.local/bin` 已在 PATH 上，所以 `office_capabilities.py` 现在能直接发现它。

> **维护警告**：不要把这个包装器写成指向 `/Applications/LibreOffice.app/Contents/MacOS/soffice`
> 的符号链接，也不要用 `cat >` / `>` 去覆盖它 —— shell 会跟随符号链接，把应用包里的 Mach-O
> 启动器直接截断。`CFBundleExecutable` 就是它，被截断后 LibreOffice 完全无法启动。
> 需要它的原始副本时，从官方 dmg 提取 `LibreOffice.app/Contents/MacOS/soffice`。

**陷阱二：隔离 profile 看不到 macOS 系统字体（最容易漏）。** `convert_office.py` 有意用
`-env:UserInstallation=<全新空目录>` 做隔离转换；在这种模式下，LibreOffice 只读它自带的
fontconfig 配置，而那份配置**不含任何 macOS 字体目录**。后果：

- 转换**不报错**，sidecar 正常生成，PDF 正常产出；
- 但 PDF 里只剩 LibreOffice 自带的拉丁字体（Caladea / LiberationSerif / DejaVuSans），
  **中文全部渲染成方框**；渲染页墨迹占比只有约 0.10%（正常应约 1.2%）；
- 交付出去就是一份结构完整、实际完全不可用的中文证据页。

包装器在检测到 `--headless` 时注入 `FONTCONFIG_FILE` 指向上面那份配置（列出
`/System/Library/Fonts`、`/System/Library/Fonts/Supplemental`、`/Library/Fonts` 以及
LibreOffice 自带字体目录），问题即消除；GUI 启动不受影响。

**因此：Office 材料入卷后必须做视觉复核，不能只看脚本退出码。** 自查方法：

    pdffonts "<派生目录>/OFF001.pdf"   # 应出现 STSongti / HiraMaruPro / MS-Gothic 等中文字体
    # 只列出 Caladea / LiberationSerif / DejaVuSans → 字体链路断了，停止并报告

再用 `read_image` 打开 `*-page-001.png` 亲眼确认中文可读，然后才继续后续入卷步骤。
这正是上游要求「自动转换生成的 sidecar 默认仍为 HOLD」的原因：字体、空白页、可读性必须人工确认。


探测到缺失时按上游规则处理：报告缺什么 → **一次性**请求授权 → 用可信来源安装 →
安装后**实跑验证**（视频能力必须用合成视频真实截出一帧，不能只看命令是否存在）。

如需**重建**隔离环境（换机、升级或环境损坏时；日常不必执行）：

    # 1) 找一个 >= 3.10 的解释器
    for p in python3.13 python3.12 python3.11 python3.10 python3; do
      command -v "$p" >/dev/null 2>&1 || continue
      "$p" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)' && { echo "FOUND $p"; break; }
    done

    # 2) 在工作区内建 venv 并装上游 requirements（POSIX；Windows 用 venv/Scripts/python.exe）
    python3 -m venv "$PWD/.evidence-bundle/venv"
    "$PWD/.evidence-bundle/venv/bin/python" -m pip install -r "$SKILL_DIR/scripts/requirements.txt"

    # 3) 用 venv 解释器复跑能力探测，确认 python_docx / python_pillow 变为 available
    PYTHONDONTWRITEBYTECODE=1 "$PWD/.evidence-bundle/venv/bin/python" \
      "$SKILL_DIR/scripts/office_capabilities.py" --json

之后所有脚本调用都用**该 venv 的解释器**，例如
`"$PWD/.evidence-bundle/venv/bin/python" "$SKILL_DIR/scripts/inspect_materials.py" ...`。
macOS 上 FFmpeg 由 Homebrew 提供时，可执行文件通常需要显式传给 `--ffmpeg/--ffprobe`
（`/opt/homebrew/bin/ffmpeg`、`/opt/homebrew/bin/ffprobe`），不要为此修改系统 PATH。

## 3. 上游示例到本宿主的等价命令

上游示例写成 PowerShell 代码块，但脚本本身跨平台（见上游 `references/portable-runtime.md`
「平台边界」）。在 POSIX 主机上按下表调用；`<...>` 一律用真实绝对路径替换并加引号
（本机工作目录含中文，路径必须加引号）。

| 上游步骤 | 本宿主命令（POSIX） |
| --- | --- |
| 能力探测 | `PYTHONDONTWRITEBYTECODE=1 "$PY" "$SKILL_DIR/scripts/office_capabilities.py" --json` |
| 视频截帧 | `"$PY" "$SKILL_DIR/scripts/extract_video_frames.py" "<视频>" "<隔离帧目录>" --ffmpeg "<ffmpeg>" --ffprobe "<ffprobe>"` |
| 只读盘点 | `"$PY" "$SKILL_DIR/scripts/inspect_materials.py" "<材料目录>" --output "<盘点.json>"` |
| Office 预检 | `"$PY" "$SKILL_DIR/scripts/inspect_office_materials.py" "<材料目录>" --output "<预检.json>"` |
| Office 转换 | `"$PY" "$SKILL_DIR/scripts/convert_office.py" "<源文件>" --workspace-root "<工作区>" --output-dir "<全新派生目录>"` |
| 正式生成 | `"$PY" "$SKILL_DIR/scripts/build_evidence_bundle.py" "<manifest.json>" "<输出.docx>"` |
| 交付前 QA | `"$PY" "$SKILL_DIR/scripts/qa_bundle.py" "<输出.docx>" --manifest "<manifest.json>"` |
| 公开包检查 | `"$PY" "$SKILL_DIR/scripts/package_check.py" .` |

`$PY` 是本机已就绪的解释器 `"$HOME/.local/share/evidence-bundle/venv/bin/python"`；重建环境时才改用第 2 步选定的解释器绝对路径。需要看脚本参数时先跑 `--help`，不要照抄上游示例里
未列出的选项。

大盘点、批量截帧和正式生成可能远超单次命令的超时：用 bash 工具的
`run_in_background: true` 起后台作业，再用 `job_output` 收集，不要靠加大超时硬等。

## 5. 可写范围与文件沙箱

- 会话工作目录（`{{cwd}}`，即当前 session 的 workspace）是**唯一默认可写区域**。
- 派生输出**全部放在 workspace 内**：隔离帧目录、盘点 JSON、Office 预检 JSON、sidecar、
  Manifest、覆盖矩阵、最终 DOCX。上游「输出目录不得位于原视频所在目录内」的要求，在
  workspace 内建 `frames/` 之类的独立目录即天然满足。
- 案件原始材料可以在 workspace **之外只读**访问：盘点、预检、转换和生成都可以直接读它们的
  绝对路径，不需要审批。
- **不要往 workspace 之外写文件**，也不要用系统临时目录绕过沙箱：这类写入会被拒绝并要求
  审批。上游要求的"隔离目录"在 workspace 内创建即可，语义完全一致。

- **派生目录不要建在 `/tmp` 下**：macOS 的 `/tmp` 是符号链接，上游路径安全门禁会直接拒绝。
- **最终 DOCX 不要落在材料目录内**：生成器会判定材料目录为只读保护区并拒绝该输出路径。
- **不要写入 Skill 安装目录**（preset 目录对会话只读）。需要留存中间产物时写进 workspace。
- 隐私：本 preset 的产物可能包含真实案件材料。公开或分发任何派生包之前运行上游
  `scripts/package_check.py`，并遵守 `references/publication-safety.md`。

## 6. 审批与交互映射

- 上游的 **intake_clarification 硬停止**在本宿主由 `ask_user_question` 承载：结构化选项
  正好满足上游"一问一个 `entity_ref` + `field_key`、每轮 1—3 问"的纪律。选项必须覆盖
  上游要求的所有路径：**不知道 / 不提供 / 稍后补充 / 请 AI 回查已授权材料后判断**。
  问题文本按上游要求自然表述（已知信息 + 具体差异 + 需要确认的事项），不要机械输出标签。
- 工具的返回结果里用户的实际选择就是上游要求的**可复核回答留痕**，据此填写 Manifest 的
  `intake_clarification.questions[].answer_binding`；用户选择"回查材料"时还必须真的回查并
  记录 `material_lookup` / `computed` 来源。
- 安装依赖、联网、以及写入 workspace 之外都需要审批。**先检测 → 报告缺什么 → 一次性请求
  授权**，与上游 1.2 的授权语义一致；不要循环请求，也不要在宿主拒绝后换措辞重问。
- 本 preset 不需要任何凭据：不要在对话中索要 API key。

## 7. 交付

生成并通过 QA 后，用 `present` 工具把最终 DOCX 与 JSON 侧车（覆盖矩阵、QA 结果）呈现给用户，
使用户能直接在 GUI 中打开；随后在回复中说明生成状态（PASS/HOLD/BLOCKED/DRAFT）、未决字段
和仍需人工复核的事项。Word 内部洁净性约束（不得出现路径、哈希、内部编号、载体字段、
「案号待补/暂缺」占位）由上游 `qa_bundle.py` 复核，`present` 只负责交付文件本身。

## 8. 与上游的差异清单

- `agents/openai.yaml`（Codex UI 元数据：display_name / short_description / default_prompt）
  已转换为 `preset.yml` 的 `name`/`description` 与 persona，不再是运行时文件。
- 上游 `evals/` 未随本 preset 分发（上游运行时安装包同样排除）。需要时按 preset 根目录
  `SOURCE.md` 的说明重新获取。
- 新增本机 OCR 工具 `dsh-ocr`（macOS Vision 框架），本 preset 的默认文字识别路径，
  全程离线；是否上云由用户决定。
- 工具面未挂载 subagent / workflow / ralph / plan mode：它们不属于本工作流。需要时在
  `agent.cordis.yml` 中追加对应行，保持"提供 service 的行必须带 isolate realm"的规则。
