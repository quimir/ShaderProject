<#
.SYNOPSIS
    一次性配置 GitHub 凭据，让 git push 不再弹窗、不再要求输入账号密码。

.DESCRIPTION
    git 通过 credential.helper（本机是 Git Credential Manager）取凭据。本脚本把凭据
    交给 GCM 存储，之后本仓库的 push/pull 全程免交互，Windows 凭据管理器里可随时查看或删除。

    Token 不经过聊天记录，只在本进程内传递。

    准备 token（只需一次，浏览器）：
        https://github.com/settings/tokens
        → Generate new token (classic)
        → 勾选 scope：repo（私有仓库需要；公开仓库推送也需要它）
        → 有效期建议 90 天，到期重新生一个再跑本脚本

.EXAMPLE
    pwsh -NoProfile -File LEARNING/setup-github-auth.ps1 -UserName quimir
    pwsh -NoProfile -File LEARNING/setup-github-auth.ps1 -UserName quimir -Remote https://github.com/quimir/ShaderProject.git -Push
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UserName,

    [string]$Remote,
    [switch]$Push,
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }

Write-Host "== 配置 GitHub 凭据 ==" -ForegroundColor Cyan
Write-Host "账号: $UserName"
Write-Host ""
Write-Host "请粘贴 Personal Access Token（GitHub → Settings → Developer settings →" -ForegroundColor Yellow
Write-Host "Personal access tokens → Tokens (classic) → Generate new token，勾选 repo）" -ForegroundColor Yellow
Write-Host "注意：输入内容会显示在屏幕上，粘贴后回车即可；这串内容不会被打印回来。" -ForegroundColor DarkGray

$secure = Read-Host -Prompt "Token" -AsSecureString
$plain = [System.Net.NetworkCredential]::new('', $secure).Password

if ([string]::IsNullOrWhiteSpace($plain)) { throw "Token 为空，已取消。" }
if ($plain.Length -lt 20) { Write-Host "警告：token 长度偏短，可能不是有效 PAT。" -ForegroundColor Yellow }

# 交给 GCM 存储：标准 credential helper 协议 —— 一行 key=value，空行结束
$payload = "protocol=https`nhost=github.com`nusername=$UserName`npassword=$plain`n`n"
$payload | & git credential approve
if ($LASTEXITCODE -ne 0) { throw "git credential approve 失败" }

# 立刻把明文从内存里清掉
$plain = $null
[System.GC]::Collect()

Write-Host "`n已存入 Windows 凭据管理器（可在「凭据管理器 → Windows 凭据」中查看/删除）。" -ForegroundColor Green

# ── 可选：配置远程并发起推送 ──
if ($Remote) {
    Push-Location $ProjectPath
    try {
        if (git remote | Select-String -Quiet '^origin$') { git remote set-url origin $Remote }
        else { git remote add origin $Remote }
        Write-Host "远程 origin = $(git remote get-url origin)"

        $env:GIT_TERMINAL_PROMPT = '0'
        Write-Host "`n== 验证认证 ==" -ForegroundColor Cyan
        git ls-remote origin 2>&1 | Select-Object -First 3 | ForEach-Object { "  $_" }
        if ($LASTEXITCODE -ne 0) { throw "认证验证失败（token 可能无效或权限不足）" }
        Write-Host "  认证 OK" -ForegroundColor Green

        if ($Push) {
            Write-Host "`n== 推送 ==" -ForegroundColor Cyan
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            git push -u origin main 2>&1 | ForEach-Object { "  $_" }
            $code = $LASTEXITCODE
            $sw.Stop()
            if ($code -eq 0) {
                Write-Host "  推送完成，耗时 $([math]::Round($sw.Elapsed.TotalSeconds,1))s" -ForegroundColor Green
            } else {
                throw "推送失败，exit=$code"
            }
        }
    } finally { Pop-Location }
}
