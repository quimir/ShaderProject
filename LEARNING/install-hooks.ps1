<#
.SYNOPSIS
    安装 git 钩子：每次提交后自动 push。

.DESCRIPTION
    git 钩子不随仓库同步（.git/ 不纳入版本管理），所以每台机器都要装一次。
    本脚本写入两个钩子：

        post-commit  —— 提交完成后自动 push 到 origin（带重试）
        post-merge   —— 另一台机器 push 后，本机 pull/merge 完也自动 push（一般无事可做，幂等）

    跳过方式（临时）：设环境变量 GIT_SKIP_AUTOPUSH=1 再提交。
    禁用方式（永久）：跑本脚本加 -Uninstall。

    为什么不用包管理器钩子：Unity 项目根目录的 package.json 是被 Unity Package Manager
    读取的清单，塞进 scripts/husky 字段会导致 UPM 解析异常，所以只能走 git 原生钩子。

.EXAMPLE
    pwsh -NoProfile -File LEARNING/install-hooks.ps1
    pwsh -NoProfile -File LEARNING/install-hooks.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
$gitDir = Join-Path $ProjectPath '.git'
if (-not (Test-Path $gitDir)) { throw "不是 git 仓库：$ProjectPath" }

$hooksDir = Join-Path $gitDir 'hooks'
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

$hookNames = @('post-commit', 'post-merge')

if ($Uninstall) {
    foreach ($n in $hookNames) {
        $p = Join-Path $hooksDir $n
        if (Test-Path $p) { Remove-Item $p -Force; Write-Host "已移除 $n" -ForegroundColor Yellow }
    }
    exit 0
}

# 用 sh 写：Windows 上的 Git for Windows 自带 sh，且 sh 脚本在 DSH / ZCode 两种壳下都能跑
$pushLogic = @'
# ── 自动 push（由 LEARNING/install-hooks.ps1 安装）──
if [ "$GIT_SKIP_AUTOPUSH" = "1" ]; then
  echo "[autopush] GIT_SKIP_AUTOPUSH=1，跳过推送"
  exit 0
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  exit 0
fi

# rebase 过程中不推（rebase 是重写历史，中间态没有推送意义）
if [ -d "$(git rev-parse --git-dir)/rebase-merge" ] || [ -d "$(git rev-parse --git-dir)/rebase-apply" ]; then
  exit 0
fi

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ -z "$branch" ]; then
  exit 0   # detached HEAD，不推
fi

attempt=1
max=3
while [ "$attempt" -le "$max" ]; do
  if git push origin "$branch" 2>&1; then
    echo "[autopush] 已推送 $branch（第 ${attempt} 次尝试）"
    exit 0
  fi
  echo "[autopush] 第 ${attempt} 次推送失败"
  attempt=$((attempt + 1))
  if [ "$attempt" -le "$max" ]; then
    sleep $((attempt * 2))
  fi
done

echo "[autopush] 推送连续失败 ${max} 次 —— 本地提交已保留，联网后执行 git push 即可"
echo "[autopush] 排查：git remote -v / git ls-remote origin"
# 故意不返回非零：避免钩子失败让用户以为提交失败
exit 0
'@

$contents = @{
    'post-commit' = "#! /bin/sh`n# 提交后自动 push`n`n$pushLogic"
    'post-merge'  = "#! /bin/sh`n# pull/merge 后自动 push（通常幂等无事可做）`n`n$pushLogic"
}

foreach ($n in $hookNames) {
    $p = Join-Path $hooksDir $n
    # LF 行尾：sh 脚本不能用 CRLF
    $text = $contents[$n] -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($p, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "已安装钩子: $n" -ForegroundColor Green
}

# 顺带把可执行位相关信息提示出来（Windows 下 git 不依赖 chmod，但 WSL/macOS clone 需要）
Write-Host ""
Write-Host "跳过推送：提交前设 `$env:GIT_SKIP_AUTOPUSH='1'" -ForegroundColor DarkGray
Write-Host "卸载：pwsh -NoProfile -File LEARNING/install-hooks.ps1 -Uninstall" -ForegroundColor DarkGray
