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

生成脚本：`LEARNING/daily-brief.ps1`（幂等，同日重复运行不覆盖；`-Force` 强制重建）。
调度有两个来源，互为冗余：ZCode 自动化任务「每日 09:00 学习简报」（ZCode 工作区内配置，
随 ZCode 存活），以及 DSH 任务板卡片「每日 09:00 学习简报」。**不用 Windows 计划任务**（用户
明确不要，勿再注册）。**只要 `.daily/TODAY.md` 存在且日期是今天，就用它，不必自己生成。**

## 4. 教法规约（不可替换）

详见 [`LEARNING/AI-HANDOFF.md`](LEARNING/AI-HANDOFF.md)，核心三条：

1. **时间模型**：任务按 30–40 分钟粒度切。每段 = 2 分钟读状态 → 25 分钟核心动作 →
   3 分钟写尾注并提交。**不要布置需要连续 90 分钟的任务。**
2. **理论必须先问思路再纠正**：不要直接给正确推导。先问「你觉得根源在哪」，
   等回答，然后指出**他在哪一步引入了错误假设**，再给推导，最后让他复述。
3. **代码分工**：光照公式、BRDF 各项、TBN 变换、阴影采样、重要性采样 —— 这些**核心行由他手写**，
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

### Unity MCP（DSH 与 ZCode 都已配置同一个端点）

```
http://127.0.0.1:8081/mcp        # Streamable HTTP，需 Accept: application/json, text/event-stream
```

DSH 里工具名形如 `mcp__unity__manage_shader`；ZCode 里是 MCP 工具 `unity-mcp`。
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

## 7. 仓库纪律

- **绝不提交** `Library/`、`Temp/`、`Logs/`、`obj/`、`.vs/`（已在 `.gitignore` 排除，别改）。
  它们是可重建的生成物，提交会让仓库从 22MB 涨到数 GB。
- **不要改 Unity 根目录的 `package.json`**：它由 Unity Package Manager 读取，
  加 `scripts` / husky 之类字段会导致 UPM 解析异常。所以自动 push 走 git 原生钩子。
- git 钩子（`.git/hooks/`）**不随仓库同步**，每台新机器跑一次
  `pwsh -NoProfile -File LEARNING/install-hooks.ps1` 即可。
- 文件索引：`LEARNING/ROADMAP.md`（路线与资源链接）· `LEARNING/PROGRESS.md`（进度与状态块）·
  `LEARNING/AI-HANDOFF.md`（教法）· `LEARNING/HANDOFF.md`（换机上手）· `.daily/TODAY.md`（今日简报）。
