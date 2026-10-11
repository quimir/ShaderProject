<#
.SYNOPSIS
    生成每日学习简报：昨天学了什么、今天要学什么、还剩多少。

.DESCRIPTION
    从 LEARNING/PROGRESS.md 的状态块与任务清单里解析出进度，渲染成人可读的简报，
    写到两个位置，供任意 AI 壳（DSH、ZCode 等）读取：

        .daily/TODAY.md      —— 始终是最新一期（稳定入口，壳只需读这一个）
        .daily/<日期>.md     —— 当天归档

    幂等：同一天重复运行不会覆盖已生成的 TODAY.md，只打印「已生成」。
    需要重新生成时加 -Force。

    退出码：0 = 已有简报或生成成功；1 = 解析失败。

.PARAMETER Force
    即使当天简报已存在也重新生成。

.PARAMETER Quiet
    不打印简报正文（供计划任务使用）。

.EXAMPLE
    pwsh -NoProfile -File LEARNING/daily-brief.ps1
    pwsh -NoProfile -File LEARNING/daily-brief.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Quiet,
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }

$progressPath = Join-Path $ProjectPath 'LEARNING\PROGRESS.md'
$roadmapPath  = Join-Path $ProjectPath 'LEARNING\ROADMAP.md'
$dailyDir     = Join-Path $ProjectPath '.daily'

if (-not (Test-Path $progressPath)) { throw "找不到 $progressPath" }
New-Item -ItemType Directory -Force -Path $dailyDir | Out-Null

$today     = (Get-Date).ToString('yyyy-MM-dd')
$todayFile = Join-Path $dailyDir "$today.md"
$liveFile  = Join-Path $dailyDir 'TODAY.md'

if ((Test-Path $todayFile) -and -not $Force) {
    if (-not $Quiet) {
        Write-Host "今日简报已存在：$todayFile" -ForegroundColor Yellow
        Write-Host (Get-Content $todayFile -Raw -Encoding UTF8)
    }
    exit 0
}

$raw = Get-Content $progressPath -Raw -Encoding UTF8

# ── 解析顶部状态块 ──
function Get-StateField {
    param([string]$Text, [string]$Field)
    $m = [regex]::Match($Text, '(?m)^\s*' + [regex]::Escape($Field) + ':\s*(.*?)\s*$')
    if (-not $m.Success) { return '' }
    return ($m.Groups[1].Value -replace '^\s*"|"\s*$', '').Trim()
}

$stage    = Get-StateField $raw '当前阶段'
$task     = Get-StateField $raw '当前任务'
$status   = Get-StateField $raw '任务状态'
$activeOn = Get-StateField $raw '激活主机'
$nextIn   = Get-StateField $raw '下一段入口'

# ── 统计任务完成度 ──
$allTasks = [regex]::Matches($raw, '(?m)^- \[( |x|~)\]\s+\*\*(T\d+\.\d+)\*\*\s*`\[(\d+)min\]`\s*(.+?)\s*$')
$total = $allTasks.Count
$done  = 0; $doing = 0
$perStage = @{}
foreach ($m in $allTasks) {
    $mark = $m.Groups[1].Value
    $id   = $m.Groups[2].Value
    $st   = "stage" + ($id -replace '^T(\d+)\..*$', '$1')
    if (-not $perStage.ContainsKey($st)) { $perStage[$st] = @{ done = 0; total = 0 } }
    $perStage[$st].total++
    if ($mark -eq 'x') { $done++; $perStage[$st].done++ }
    elseif ($mark -eq '~') { $doing++ }
}

# 剩余分钟数（未完成任务按标注时长估算）
$remainMin = 0
foreach ($m in $allTasks) {
    if ($m.Groups[1].Value -ne 'x') { $remainMin += [int]$m.Groups[3].Value }
}

# ── 尾注（区分「今天」与「昨天」）──
$notes = ($raw -split "`r?`n") | Where-Object { $_ -match '^- (\d{4}-\d{2}-\d{2}) \|' }
$yesterday = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
$todayNotes     = $notes | Where-Object { $_ -match "^- $today \|" }
$yesterdayNotes = $notes | Where-Object { $_ -match "^- $yesterday \|" }

function Format-Notes {
    param($Items)
    if (-not $Items -or $Items.Count -eq 0) { return '（无记录）' }
    return (($Items | ForEach-Object { $_ -replace '^- ', '  - ' }) -join "`n")
}

# ── 当前任务原文（含产物与判据）──
$currentBlock = ''
if ($task) {
    $esc = [regex]::Escape("**$task**")
    $idx = $raw.IndexOf("**$task**")
    if ($idx -ge 0) {
        $tail = $raw.Substring($idx)
        $lines = $tail -split "`r?`n"
        $buf = @()
        foreach ($ln in $lines) {
            if ($buf.Count -gt 0 -and $ln -match '^- \[') { break }
            $buf += $ln
            if ($buf.Count -gt 8) { break }
        }
        $currentBlock = ($buf -join "`n").TrimEnd()
    }
}

$pct = if ($total -gt 0) { [math]::Round(100 * $done / $total, 0) } else { 0 }
$hoursRemain = [math]::Round($remainMin / 60, 1)

# ── 渲染简报 ──
$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# 今日学习简报 · $today")
[void]$sb.AppendLine()
[void]$sb.AppendLine("> 本文件由 ``LEARNING/daily-brief.ps1`` 生成，供任意 AI 壳（DSH / ZCode / 其他）读取。")
[void]$sb.AppendLine("> 每日 09:00 自动刷新。稳定入口始终是 ``.daily/TODAY.md``。")
[void]$sb.AppendLine()
[void]$sb.AppendLine('## 1. 进度总览')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| 指标 | 值 |')
[void]$sb.AppendLine('|---|---|')
[void]$sb.AppendLine("| 当前阶段 | 阶段 $stage |")
[void]$sb.AppendLine("| 当前任务 | ``$task``（$status） |")
[void]$sb.AppendLine("| 任务完成度 | $done / $total（$pct%） |")
[void]$sb.AppendLine("| 剩余预估 | 约 $hoursRemain 小时（$remainMin 分钟） |")
if ($activeOn) { [void]$sb.AppendLine("| 激活主机 | **$activeOn**（另一台正在用，先别动） |") }
[void]$sb.AppendLine()
[void]$sb.AppendLine('## 2. 昨天学了什么')
[void]$sb.AppendLine()
[void]$sb.AppendLine((Format-Notes $yesterdayNotes))
[void]$sb.AppendLine()
[void]$sb.AppendLine('## 3. 今天要学什么')
[void]$sb.AppendLine()
if ($nextIn) { [void]$sb.AppendLine("**入口**：$nextIn") }
[void]$sb.AppendLine()
if ($currentBlock) {
    [void]$sb.AppendLine('```markdown')
    [void]$sb.AppendLine($currentBlock)
    [void]$sb.AppendLine('```')
} else {
    [void]$sb.AppendLine('（状态块里的当前任务在清单中定位失败，请检查 PROGRESS.md）')
}
[void]$sb.AppendLine()

# ── 知识卡：这一课要用的数学 + 在图形学里的位置 ──
# 数据来自 LEARNING/task-knowledge.json，任何壳读简报都能拿到，不依赖谁记得。
$knowledgePath = Join-Path $ProjectPath 'LEARNING\task-knowledge.json'
if ((Test-Path $knowledgePath) -and $task) {
    try {
        $kb = (Get-Content $knowledgePath -Raw -Encoding UTF8 | ConvertFrom-Json).tasks
        $card = $kb.$task
        if ($card) {
            [void]$sb.AppendLine('## 3b. 这一课的知识坐标')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("**数学**：$($card.math)")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("**图形学归属**：$($card.graphics)")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine("**这一课要掌握**：$($card.learn)")
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('> 动手之前先讲清上面这些数学概念（几何意义优先于公式），')
            [void]$sb.AppendLine('> 讲完让他自己猜、自己验证，公式全表见 [`notes/shader-math.md`](../LEARNING/notes/shader-math.md)。')
            [void]$sb.AppendLine()
        }
    } catch {
        [void]$sb.AppendLine("> （task-knowledge.json 解析失败：$($_.Exception.Message)）")
        [void]$sb.AppendLine()
    }
}

if ($todayNotes.Count -gt 0) {
    [void]$sb.AppendLine('## 4. 今天已完成的段落')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine((Format-Notes $todayNotes))
    [void]$sb.AppendLine()
}
[void]$sb.AppendLine('## 阶段分布')
[void]$sb.AppendLine()
[void]$sb.AppendLine('| 阶段 | 完成 | 总数 |')
[void]$sb.AppendLine('|---|---|---|')
foreach ($k in ($perStage.Keys | Sort-Object)) {
    $v = $perStage[$k]
    [void]$sb.AppendLine("| $k | $($v.done) | $($v.total) |")
}
[void]$sb.AppendLine()

# ── 附上数学待验证清单（来自 notes/shader-math.md 的「待验证」小节）──
# 下次坐下时最需要的是「上段没验证完的东西」，公式全文留在笔记里按需查。
$mathNote = Join-Path $ProjectPath 'LEARNING\notes\shader-math.md'
if (Test-Path $mathNote) {
    $mathRaw = Get-Content $mathNote -Raw -Encoding UTF8
    $m = [regex]::Match($mathRaw, '(?ms)^## 待验证.*?(?=^## |\z)')
    if ($m.Success) {
        [void]$sb.AppendLine('## 上次留下的待验证清单')
        [void]$sb.AppendLine()
        # 去掉标题行本身，只留正文
        $body2 = ($m.Value -split "`r?`n" | Select-Object -Skip 1) -join "`r`n"
        [void]$sb.AppendLine($body2.Trim())
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('> 公式与几何意义见 [`LEARNING/notes/shader-math.md`](../LEARNING/notes/shader-math.md)。')
        [void]$sb.AppendLine()
    }
}

[void]$sb.AppendLine('---')
[void]$sb.AppendLine()
[void]$sb.AppendLine('**下一步动作**：按「今天要学什么」的入口开始，30–40 分钟一段；')
[void]$sb.AppendLine('收尾时运行 `pwsh -NoProfile -File LEARNING/sync.ps1 -Message "..." -Task <ID> -NextTask <下一个ID> -NextState <未开始|进行中> -Minutes <分钟> -Note "..."`')
[void]$sb.AppendLine('（提交后由 git 钩子自动 push，无需手动。想临时跳过推送：设环境变量 `GIT_SKIP_AUTOPUSH=1`。）')

$content = $sb.ToString()

[System.IO.File]::WriteAllText($todayFile, $content, (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($liveFile,  $content, (New-Object System.Text.UTF8Encoding($false)))

if (-not $Quiet) {
    Write-Host "已生成: $todayFile" -ForegroundColor Green
    Write-Host "稳定入口: $liveFile" -ForegroundColor Green
    Write-Host ''
    Write-Host $content
} else {
    Write-Host "简报已刷新 -> $liveFile"
}
