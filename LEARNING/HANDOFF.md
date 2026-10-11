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

## 6. 远程仓库（已配置完成）

本仓库已接上远程并完成首次推送：

```
origin  https://github.com/quimir/ShaderProject.git   （分支 main）
作者    QuiMir <2546670299@qq.com>（全局与仓库级都已设置）
```

### 另一台电脑首次接入

```powershell
git clone https://github.com/quimir/ShaderProject.git
cd ShaderProject
git config user.name "QuiMir"
git config user.email "2546670299@qq.com"
# 然后用 Unity Hub 添加该目录并打开项目（Library 会自动重建，需几分钟）
```

### 认证

- **本机**：Windows 凭据管理器里已有 GitHub 凭据（账号 `quimir`），push/pull 免交互，无需任何配置。
- **另一台机器**：跑一次一次性的凭据配置脚本即可：

```powershell
pwsh -NoProfile -File LEARNING/setup-github-auth.ps1 -UserName quimir
```

它会提示你粘贴一个 Personal Access Token（GitHub → Settings → Developer settings →
Personal access tokens → Tokens (classic) → 勾选 `repo`），存进 Windows 凭据管理器，
token 不落明文文件、不经过聊天记录。之后该机的 pull/push 全程免交互。

> 也可选择装 GitHub CLI 后 `gh auth login`，效果等价。

### 不要提交的东西

`Library/`、`Temp/`、`Logs/`、`obj/`、`.vs/` 已在 `.gitignore` 里排除——它们是可重建的生成物。
**不要为了「让别的机器直接能打开」而把它们提交上去**，仓库体积会从 22MB 膨胀到几 GB。
真正需要同步的只有文本资产：`Assets/`、`Packages/`、`ProjectSettings/`、`LEARNING/`、
`.unity-mcp/*.md|*.ps1`。

---

## AI 接手必读

教法规约（时间模型、理论对话法、代码分工、资源分级）在 [`AI-HANDOFF.md`](AI-HANDOFF.md)。
**不要换一套教法**：核心光照公式行必须让 YG 自己写，理论必须「先问他的思路，再指出错在哪」。
