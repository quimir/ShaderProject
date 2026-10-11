<#
.SYNOPSIS
    收尾：写尾注、更新状态、提交推送。也可用于换机时拉取进度。

.DESCRIPTION
    把「一段学习结束」的固定动作自动化，避免碎片时间下忘记同步：

        1. 更新 PROGRESS.md 顶部状态块（当前任务 / 任务状态 / 最后更新 / 下一段入口 / 激活主机）
        2. 在「段尾注」末尾追加一行记录
        3. git add -A → commit → push（未配远程则跳过推送）
        4. 顺手跑一次 MCP 通道自检（失败不阻断）

    参数分三类，注意区分：
        -Task      本次**做完**的任务（只写进尾注）
        -Message   git 提交信息（同时用于状态块的「最后一段」）
        -NextTask / -NextState / -NextEntry   下次的状态，**显式给出，脚本不推断**

.PARAMETER Message
    git 提交信息，必填。

.PARAMETER Resume
    换机 / 隔久回来：只 pull 并打印当前状态，不写文件、不提交。

.EXAMPLE
    # 换机或恢复
    pwsh -NoProfile -File LEARNING/sync.ps1 -Resume

    # 一段结束：T0.1 全部做完，下次开 T0.2
    pwsh -NoProfile -File LEARNING/sync.ps1 `
        -Message "stage0: T0.1 向量可视化完成" `
        -Task T0.1 -Minutes 30 `
        -NextTask T0.2 -NextState 未开始 `
        -NextEntry "给 Math_Visualize 接入世界法线，输出 dot(N,L) 灰度" `
        -Note "搞懂了 dot 越接近 1 越亮；下次直接改 frag 里的 return"

    # 一段没做完：任务状态写「进行中」，下次接着干
    pwsh -NoProfile -File LEARNING/sync.ps1 `
        -Message "stage0: T0.2 起头" `
        -Task T0.2 -Minutes 25 `
        -NextTask T0.2 -NextState 进行中 `
        -NextEntry "接上：世界法线已取到，还差和主光方向点乘" `
        -Note "卡在 UNITY_MATRIX_M 用错，取了对象空间法线"
#>
[CmdletBinding()]
param(
    [string]$Message,
    [string]$Task,
    [string]$NextTask,
    [ValidateSet('未开始', '进行中', '已完成')]
    [string]$NextState,
    [string]$NextEntry,
    [int]$Minutes,
    [string]$Note,
    [switch]$Resume,
    [switch]$NoPush,
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
$progressPath = Join-Path $ProjectPath 'LEARNING\PROGRESS.md'
if (-not (Test-Path $progressPath)) { throw "找不到 $progressPath" }

function Get-Today { (Get-Date).ToString('yyyy-MM-dd') }

function Show-State {
    param([string]$Text)
    $inBlock = $false
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^```yaml') { $inBlock = $true; continue }
        if ($inBlock -and $line -match '^```\s*$') { break }
        if ($inBlock) { Write-Host "  $line" }
    }
}

# ── 换机 / 恢复模式：只拉取并显示状态 ──
if ($Resume) {
    Write-Host "== 拉取最新进度 ==" -ForegroundColor Cyan
    if (git -C $ProjectPath remote) {
        git -C $ProjectPath pull --ff-only 2>&1 | ForEach-Object { "  $_" }
    } else {
        Write-Host "  尚未配置远程仓库，本地模式（配置方法见 HANDOFF.md 第 6 节）" -ForegroundColor Yellow
    }

    $text = Get-Content $progressPath -Raw -Encoding UTF8
    Write-Host "`n== 当前状态 ==" -ForegroundColor Cyan
    Show-State $text

    Write-Host "`n== 最后一条尾注 ==" -ForegroundColor Cyan
    $notes = ($text -split "`r?`n") | Where-Object { $_ -match '^- \d{4}-\d{2}-\d{2} \|' }
    if ($notes) { $notes | Select-Object -Last 1 | ForEach-Object { Write-Host "  $_" } }
    else { Write-Host "  （还没有尾注）" }

    Write-Host "`n提醒：开工前把状态块的「激活主机」填成 $(Get-Today) 的主机名 $env:COMPUTERNAME" -ForegroundColor DarkGray
    return
}

if (-not $Message) { throw "缺少 -Message。加 -Resume 可只看状态而不提交。" }

$raw = Get-Content $progressPath -Raw -Encoding UTF8

function Set-StateField {
    param([string]$Content, [string]$Field, [string]$Value)
    $pattern = '(?m)^(\s*' + [regex]::Escape($Field) + ':\s*).*$'
    if ($Content -notmatch $pattern) { throw "状态块里找不到字段: $Field" }
    return [regex]::Replace($Content, $pattern, { param($m) $m.Groups[1].Value + $Value }, 1)
}

# ── 1. 更新状态块 ──
# 本段已结束 → 释放主机占用
$raw = Set-StateField $raw '激活主机' '""'
# 下次要做的事：状态由 -NextState 显式给出，不靠推断
if ($NextTask) { $raw = Set-StateField $raw '当前任务' $NextTask }
if ($NextState) { $raw = Set-StateField $raw '任务状态' $NextState }
$raw = Set-StateField $raw '最后更新' (Get-Today)

if ($NextEntry) {
    $raw = Set-StateField $raw '下一段入口' $NextEntry
} elseif ($raw -match '(?m)^\s*下一段入口:\s*""\s*$') {
    $raw = Set-StateField $raw '下一段入口' '见 PROGRESS 底部尾注'
}

# 「最后一段」用本次的提交信息概括，保留人类可读的一行
$lastSummary = if ($Task) { "$Task $Message" } else { $Message }
if ($lastSummary.Length -gt 80) { $lastSummary = $lastSummary.Substring(0, 77) + '...' }
$raw = Set-StateField $raw '最后一段' ($lastSummary -replace '[\r\n]+', ' ')

# ── 2. 追加尾注 ──
$duration = if ($Minutes -gt 0) { "$Minutes 分钟" } else { '—' }
$noteText = if ($Note) { $Note } else { '（未填写，下次补）' }
$target = if ($Task) { $Task } else { '—' }
$newNote = "- $(Get-Today) | $duration | $target | $noteText"

$marker = '<!-- 从下面这一行开始追加 -->'
if ($raw -match [regex]::Escape($marker)) {
    $raw = $raw -replace [regex]::Escape($marker), ($marker + "`r`n`r`n" + $newNote)
} else {
    $raw = $raw.TrimEnd() + "`r`n`r`n" + $newNote + "`r`n"
}

Set-Content -Path $progressPath -Value $raw -Encoding UTF8 -NoNewline
Write-Host "已更新 PROGRESS.md" -ForegroundColor Green
Write-Host "  尾注: $newNote"

# ── 3. 提交并推送 ──
Write-Host "`n== 同步到远程 ==" -ForegroundColor Cyan
git -C $ProjectPath add -A
git -C $ProjectPath commit -q -m $Message
Write-Host "  已提交: $Message"

if (-not $NoPush) {
    if (git -C $ProjectPath remote) {
        git -C $ProjectPath push 2>&1 | ForEach-Object { "  $_" }
        Write-Host "  已推送" -ForegroundColor Green
    } else {
        Write-Host "  尚未配置远程仓库，跳过推送（见 HANDOFF.md 第 6 节）" -ForegroundColor Yellow
    }
}

# ── 4. 顺手自检通道（不阻断） ──
$probe = Join-Path $ProjectPath '.unity-mcp\unity-mcp.ps1'
if (Test-Path $probe) {
    Write-Host "`n== MCP 通道自检 ==" -ForegroundColor Cyan
    try { & pwsh -NoProfile -File $probe probe 2>&1 | ForEach-Object { "  $_" } }
    catch { Write-Host "  自检失败（Unity 可能没开）" -ForegroundColor Yellow }
}
