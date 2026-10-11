# 进度交接 · ShaderProject

> 换电脑、换 AI、隔了很久回来 —— 从这里开始。**三分钟上手。**

## 1. 拉最新进度

```powershell
cd <你的项目路径>
git pull
```

## 2. 读 PROGRESS.md 顶部状态块

打开 [`PROGRESS.md`](PROGRESS.md)，只看最上面那个 ```yaml 块：

```yaml
当前阶段: 0
当前任务: T0.1
任务状态: 未开始          # 未开始 | 进行中 | 已完成
激活主机: ""              # 开始一段前填主机名，结束前清空
最后更新: 2026-10-11
最后一段: 尚未开始
下一段入口: 从 T0.1 开始，先做向量可视化
```

字段含义：

| 字段 | 用途 |
|---|---|
| `当前阶段` / `当前任务` | 现在走到哪个阶段的哪个任务（任务 ID 对应 ROADMAP 与 PROGRESS） |
| `任务状态` | `进行中` 说明上次没做完，要去 PROGRESS 底部读**尾注**看卡在哪 |
| `激活主机` | 非空 = 另一台正在用，**先别动**；空 = 可以开工 |
| `最后更新` / `最后一段` | 上次是何时、做了什么 |
| `下一段入口` | **最重要的一行**：下次坐下直接照它干，不用回忆 |

## 3. 开工前自检（换机器必做）

```powershell
# a) MCP 通道是否活着（Unity 得先开着）
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 probe

# b) 控制台有没有阻断性报错
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 console -action get -types '["error","warning"]'
```

若 MCP 起不来，见 [`../.unity-mcp/UNITY-MCP.md`](../.unity-mcp/UNITY-MCP.md)。
若看到 Burst `error code 4551`，跑 `pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1 -Fix`。

## 4. 干活时的节奏

```
[2 分钟] 读上面的状态块 + PROGRESS 底部最后一条尾注
[25 分钟] 做「当前任务」
[3 分钟] 收尾（见下）
```

## 5. 收尾（一段结束必须做，这是同步的关键）

1. **勾选**：把 PROGRESS.md 里对应任务的 `[ ]` 改成 `[x]`（没做完改 `[~]`）。
2. **写尾注**：在 PROGRESS.md 底部「段尾注」追加一行：
   `日期 | 时长 | 任务 | 学到什么 / 卡在哪 / 下次从哪接`
3. **更新顶部状态块**：改 `当前任务`、`任务状态`、`最后更新`、`下一段入口`，清空 `激活主机`。
4. **提交并推送**：

```powershell
git add -A
git commit -m "stage0: T0.1 向量可视化"
git push
```

或者直接跑脚本：

```powershell
pwsh -NoProfile -File LEARNING/sync.ps1 -Task "stage0: T0.1 向量可视化"
```

---

## 6. 首次配置远程仓库（只做一次）

本仓库已 `git init` 并完成首次提交（分支 `main`，459→458 个文件，约 21.8MB）。
还差连上 GitHub：

1. 在 GitHub 网页上新建一个**空仓库**（不要勾选 README / .gitignore / license，全留空）。
2. 在本机执行（把 URL 换成你的）：

```powershell
cd F:\Projects\ShaderProject
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git branch -M main
git push -u origin main
```

3. 另一台电脑：

```powershell
git clone https://github.com/<你的用户名>/<仓库名>.git
# 然后用 Unity Hub 添加这个目录打开项目
```

**注意**：`Library/`、`Temp/`、`Logs/`、`obj/`、`.vs/` 已被 `.gitignore` 排除，
它们是可重建的生成物，不要为了让别的机器「能直接打开」而把它们提交上去——
另一台机器首次打开 Unity 会自己重建（视项目大小需几分钟）。
真正需要同步的只有文本资产：`Assets/`、`Packages/`、`ProjectSettings/`、
`LEARNING/`、`.unity-mcp/*.md|*.ps1`。

### 认证

首次 `push` 会要凭据。推荐装 GitHub CLI 后 `gh auth login`，
或在 GitHub 生成 Personal Access Token 当密码用（用 Windows 凭据管理器保存即可）。

---

## AI 接手必读

教法规约（时间模型、理论对话法、代码分工、资源分级）在 [`AI-HANDOFF.md`](AI-HANDOFF.md)。
**不要换一套教法**：核心光照公式行必须让 YG 自己写，理论必须「先问他的思路，再指出错在哪」。
