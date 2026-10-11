# 今日学习简报 · 2026-10-11

> 本文件由 `LEARNING/daily-brief.ps1` 生成，供任意 AI 壳（DSH / ZCode / 其他）读取。
> 每日 09:00 自动刷新。稳定入口始终是 `.daily/TODAY.md`。

## 1. 进度总览

| 指标 | 值 |
|---|---|
| 当前阶段 | 阶段 0 |
| 当前任务 | `T0.1`（未开始） |
| 任务完成度 | 0 / 28（0%） |
| 剩余预估 | 约 16.5 小时（990 分钟） |

## 2. 昨天学了什么

（无记录）

## 3. 今天要学什么

**入口**：从 T0.1 开始：写 Math_Visualize.shader，用固定向量 float3(0.6,0.8,0) 输出颜色

```markdown
**T0.1** `[25min]` 向量可视化 v1
      写 `Assets/Shaders/Math_Visualize.shader`，只输出 `float3(x,y,0)` 把屏幕坐标变成颜色，
      先用固定向量 `float3(0.6, 0.8, 0)` 输出 RGBA。
      **产物**：一张渐变截图。
      **判据**：能说出为什么用固定向量打底而不是直接用 UV。
```

## 4. 今天已完成的段落

  - 2026-10-11 | — | 工具链 | 控制台清零：修掉 ShaderUtil.GetShaderMessages(null) 空引用（它会打断 OnGUI 布局并连带刷 GUILayout 报错）。删除两个无用备份，MCP 日志停追踪（保留磁盘文件）。两套 URP 路径实测通过。
  - 2026-10-11 | — | 工具链 | ShaderLearningInspector 6 个编译错误全修（Unity 6 API 变更）；新增 LEARNING/reference 参考库（11 个 URP 官方 HLSL）；AGENTS.md 增补工具链与 API 踩坑清单。
  - 2026-10-11 | — | — | 已完成：09:00 定时简报（Windows 计划任务 + DSH 任务板双通道）、git 自动 push 钩子、跨壳入口 AGENTS.md。下一步可开始 T0.1。
  - 2026-10-11 | — | — | 仓库已接 origin 并推送成功（作者已重写为 QuiMir）。新增 setup-github-auth.ps1 供第二台机器一次性配凭据。
  - 2026-10-11 | — | — | 修正上一轮的状态映射缺陷：-State 换成显式 -NextState，并让「最后一段」真正被写入。下一轮进 T0.1。
  - 2026-10-11 | — | — | 本轮未开始学习：完成流程联调（路线文档+进度状态机+同步脚本+仓库初始化）。下次直接进 T0.1。
  - 2026-10-11 | — | 体系搭建 | 路线、进度、AI 交接规约建立完成。**从 T0.1 开始。**

## 阶段分布

| 阶段 | 完成 | 总数 |
|---|---|---|
| stage0 | 0 | 5 |
| stage1 | 0 | 7 |
| stage2 | 0 | 4 |
| stage3 | 0 | 4 |
| stage4 | 0 | 3 |
| stage5 | 0 | 5 |

---

**下一步动作**：按「今天要学什么」的入口开始，30–40 分钟一段；
收尾时运行 `pwsh -NoProfile -File LEARNING/sync.ps1 -Message "..." -Task <ID> -NextTask <下一个ID> -NextState <未开始|进行中> -Minutes <分钟> -Note "..."`
（提交后由 git 钩子自动 push，无需手动。想临时跳过推送：设环境变量 `GIT_SKIP_AUTOPUSH=1`。）
