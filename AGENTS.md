# AGENTS.md · ShaderProject

> 本文件是**跨壳入口**。任何 AI 编码代理（DeepSeek Harness / ZCode / Claude Code / Codex 等）
> 在本仓库工作前请先读这一段。项目根目录已无 `Assets/` 之外的干扰文件。

---

## 1. 这个仓库在干什么

两个目标并行：

1. **Unity 渲染项目**：`Assets/` 是一个 URP 工程（Unity 6000.5.4f1 / URP 17.5.0），
   正在按学习路线逐步长成一个自研渲染器。
2. **渲染学习体系**：`LEARNING/` 记录路线、进度与教法规约。学习者（YG，GitHub 账号 `quimir`）
   **Unity 工程熟练、渲染零基础**，每天只有 1–4 段、每段 30–40 分钟的碎片时间。

## 2. 开工前必做

```powershell
git pull                                                   # 先拿最新进度
pwsh -NoProfile -File LEARNING/sync.ps1 -Resume            # 打印当前状态与最后一条尾注
```

`sync.ps1 -Resume` 会输出顶端状态块（当前阶段 / 当前任务 / 任务状态 / 激活主机 / 下一段入口）。
**「激活主机」非空时，说明另一台电脑正在用，先别动手。**

## 3. 今日简报（每日 09:00 自动刷新）

读 **`.daily/TODAY.md`** —— 这是稳定入口，永远是最新一期。内容包含：

- 进度总览（当前任务、完成度 N/M、剩余预估小时数）
- 昨天学了什么（来自 PROGRESS.md 的段尾注）
- 今天要学什么（当前任务原文 + 下一段入口 + 产物与判据）
- **这一课的知识坐标**（数学知识 + 图形学归属 + 要掌握的东西，来自 `LEARNING/task-knowledge.json`）
- **课后补充**（仅当任务已完成：具体讲次/章节 + 小练习，来自 `LEARNING/task-supplements.json`）
- 上次留下的待验证清单（来自 `LEARNING/notes/shader-math.md`）

**引用讲次/章节时以 `LEARNING/resources-index.json` 为准**——那里的 GAMES101 讲次编号与讲题
是从课程主页真实抓取的。**禁止编造视频时间戳**（bilibili 接口有反爬，无法核实），
凭记忆写的错误时间戳会让整份学习材料失信。

生成脚本：`LEARNING/daily-brief.ps1`（幂等，同日重复运行不覆盖；`-Force` 强制重建）。

### 3.1 设置提醒：能力驱动，不绑定平台

**用户的本意是「任何壳都能自动提醒」。** 所以规则是按**能力**判断，而不是写死某个平台的机制：

```text
当 AI 读到这个自动化任务时：
  ① 先检查当前壳有没有「创建定时/自动化任务」的能力
  ② 有   → 用当前壳的原生机制创建它（各壳机制不同，按自己的来）
  ③ 没有 → 就不创建；只保证 .daily/TODAY.md 能按需生成即可
  ④ 任何情况下都不要去动操作系统级的调度器（Windows 计划任务 / cron / launchd 等）
```

已知各壳的例子（**仅作示例，不是白名单**）：

| 壳 | 原生机制 |
|---|---|
| DSH | 任务板卡片 + `schedule`（cron `0 9 * * *`） |
| ZCode | 工作区内的自动化任务配置 |

**为什么禁止 OS 级调度器**：它绑死在单机、单用户、单操作系统上，与「换壳、换机器都能用」相冲突。
用户明确要求过，勿再注册。

**只要 `.daily/TODAY.md` 存在且日期是今天，就直接用，不必自己生成。**

## 4. 教法规约（不可替换）

详见 [`LEARNING/AI-HANDOFF.md`](LEARNING/AI-HANDOFF.md)，核心四条：

1. **时间模型**：任务按 30–40 分钟粒度切。每段 = 2 分钟读状态 → 25 分钟核心动作 →
   3 分钟写尾注并提交。**不要布置需要连续 90 分钟的任务。**
2. **新概念必须先讲清再动手（数学四段式）**：每段开工的第一件事是**讲知识点**，不是抛问题、更不是抛代码。
   按 `AI-HANDOFF.md` 第 3 节，对本任务涉及的每个新概念逐个走一遍：
   ① 它在算什么（一句话直观含义，**不先上公式**）② 对应什么数学 + **几何意义**
   ③ 这个场景为什么用它（换掉它会怎样）④ 链接（优先中文、可免费访问；讲次号只能引自
   `LEARNING/resources-index.json`，**禁止编造时间戳**）。
   ⚠️ 简报 3b 节和 `task-knowledge.json` 的 `math / graphics / learn` 只是**知识点坐标（标签）**，
   **不等于知识点本身**——照抄标签就跳去提问/动手＝漏教，视为违规。
   讲完仍然**不许替他算**：给定义、给几何意义、给链接，然后让他猜、让他验证。
3. **理论必须先问思路再纠正**：不要直接给正确推导。先问「你觉得根源在哪」，
   等回答，然后指出**他在哪一步引入了错误假设**，再给推导，最后让他复述。
4. **代码分工**：光照公式、BRDF 各项、TBN 变换、阴影采样、重要性采样 —— 这些**核心行由他手写**，
   你只给带 `// TODO(YG)` 留空的骨架；`Properties`、`#pragma`、`CBUFFER`、C# 样板由你写。
   写完必须审代码 + 截图验证。

## 5. 一段学习结束的收尾（必须做）

```powershell
pwsh -NoProfile -File LEARNING/sync.ps1 `
  -Message "stage0: T0.1 向量可视化完成" `
  -Task T0.1 -Minutes 30 `
  -NextTask T0.2 -NextState 未开始 `
  -NextEntry "给 Math_Visualize 接入世界法线，输出 dot(N,L) 灰度" `
  -Note "搞懂了 dot 越接近 1 越亮；下次直接改 frag 里的 return"
```

它做四件事：更新状态块、追加尾注、`git add -A` + commit + **自动 push（由 git 钩子负责）**、
顺带自检 Unity MCP 通道。没做完就用 `-NextState 进行中`。

跳过自动推送：提交前设 `$env:GIT_SKIP_AUTOPUSH='1'`。

## 6. 可用工具

### Unity MCP（本工作区固定 8082，别走 8081）

```
http://127.0.0.1:8082/mcp        # Streamable HTTP，需 Accept: application/json, text/event-stream
```

DSH 里本工程的工具名形如 `mcp__unityRenderMCP__manage_shader`，对应 **8082 = ShaderProject**。
⚠️ `mcp__unityMCP__*` 是 **8081**，指向另一个工程 client-E2 —— 在本仓库调用它等于操作错工程。
ZCode 里是 MCP 工具 `unity-mcp`（端点由该端自己的 profile 决定）。
没有 MCP 时可用项目内脚本桥：

```powershell
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 probe        # 端点/版本/工具数/实例
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 shader -action read -name <名字> -path Assets/Shaders
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 console -action get -types '["error","warning"]'
```

细节与协议坑见 [`UNITY-MCP.md`](.unity-mcp/UNITY-MCP.md)。

### 已知环境问题

编辑器控制台若出现 Burst `error code 4551`，那是 Windows **Smart App Control** 拦截了
Burst 生成的未签名 dll，不是代码问题。处理：

```powershell
pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1        # 诊断
pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1 -Fix   # 备份并清除被拦缓存
```

## 6b. Shader 学习工具链

| 工具 | 位置 | 用途 |
|---|---|---|
| **Shader 学习检视器** | `Assets/Editor/ShaderLearningInspector.cs`，菜单 `Window ▸ Shader Learning ▸ Shader Inspector` | 看预处理后代码、编译器生成的 HLSL、逐 Pass stage 与关键字、单变体编译与消息 |
| **切线空间可视化** | `Assets/Editor/VertexFrameGizmos.cs`，菜单 `Tools ▸ Shader Learning ▸ Vertex Frames ▸ …` | 选中带 MeshFilter 的物体，在 Scene 视图把**每个顶点**的 T/B/N 画成红/绿/蓝三根箭头。**三条轴可分别开关**（`总开关` + `显示 T/B/N`，后三者快捷键 Ctrl+Alt+1/2/3），想「只看一根轴」就关掉另外两个；`VertexStride` 采样、`ArrowLength` 调长度。讲「切线空间 / 法线贴图为什么相对表面」时先用它。**必须用 `SceneView.duringSceneGui` + `Handles` 实现**：`[DrawGizmo]`/`OnDrawGizmos` 那套渲染通道**不进 MCP 的 Scene 视图截图**（截到的只有 GUI 通道，Transform 工具能看到），改完没法验证 |
| **URP 官方参考副本** | `LEARNING/reference/urp-shaders/*.txt` | 11 个最值得学的 URP HLSL（BRDF / Lighting / Shadows / GI …），加 `.txt` 后缀所以不参与编译，但可搜索、可读、AI 能直接查 |
| **参考索引** | `LEARNING/reference/README.md` | 哪个文件对应哪个学习阶段、该搜什么关键词 |
| **刷新脚本** | `LEARNING/reference/refresh-urp-reference.ps1` | Unity 升级 URP 后重跑，更新参考副本 |

Unity 内置的 **Rendering Debugger**（`Window ▸ Analysis ▸ Rendering Debugger`）与
**Frame Debugger** 无需安装任何东西，却能直接可视化 NdotL、法线、基础色、金属度、粗糙度
这些中间量——讲光照原理时优先用它们做演示。

### 改 `ShaderLearningInspector.cs` 前必读

它用的是 **Unity 6 才公开的 API**，训练数据里的写法大多是错的。改之前先用 `unity_reflect`
核对。已踩过的坑：

- `ShaderType` / `ShaderCompilerPlatform` 在 `UnityEditor.Rendering`，**不在** `UnityEngine.Rendering`
- `ShaderCompilerPlatform` 的成员是 **`D3D`**，不是 `D3D11`
- `ShaderData` 及其嵌套类型（`Pass` / `PreprocessedVariant` / `VariantCompileInfo`）在 `UnityEditor` 下
- `PreprocessVariant` / `CompileVariant` 需要第 5 个参数 `stripLineDirectives`（bool）
- `PassIdentifier` 只有公开构造函数 `(uint, uint)`，属性只读，**不能用对象初始化器**
- `ShaderUtil.GetPassKeywords` 有效重载带 `ref`，而编辑器语言版本是 C# 9（`ref` 传 `in` 报 CS9194）——
  故代码里用反射兼容层 `GetPassKeywordsCompat`
- **`ShaderData.VariantCompileInfo` 没有 `ResourceBindings` 成员**（6000.0 与 6000.5 文档 + 本地反射三处一致，
  属早期凭猜测补的假 API，CS1061 就是这么来的）。它只有 `Success` / `Messages` / `ShaderData` /
  `Attributes` / `TextureBindings` / `ConstantBuffers` 六个 —— 别再补回来

### 现阶段明确不装的第三方插件

可视化 Shader 编辑器（Amplify Shader Editor 等）、Shader 参考导航器（URPShaderViewer 等）暂不引入，
理由与时机见 `LEARNING/reference/README.md` 末尾。**Shader Graph 17.5.0 已随 URP 装好**，无需额外安装。

## 7. 仓库纪律

- **绝不提交** `Library/`、`Temp/`、`Logs/`、`obj/`、`.vs/`（已在 `.gitignore` 排除，别改）。
  它们是可重建的生成物，提交会让仓库从 22MB 涨到数 GB。
- **不要改 Unity 根目录的 `package.json`**：它由 Unity Package Manager 读取，
  加 `scripts` / husky 之类字段会导致 UPM 解析异常。所以自动 push 走 git 原生钩子。
- git 钩子（`.git/hooks/`）**不随仓库同步**，每台新机器跑一次
  `pwsh -NoProfile -File LEARNING/install-hooks.ps1` 即可。
- 文件索引：`LEARNING/ROADMAP.md`（路线与资源链接）· `LEARNING/PROGRESS.md`（进度与状态块）·
  `LEARNING/AI-HANDOFF.md`（教法）· `LEARNING/HANDOFF.md`（换机上手）· `.daily/TODAY.md`（今日简报）。
