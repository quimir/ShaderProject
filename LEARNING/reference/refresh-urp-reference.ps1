<#
.SYNOPSIS
    从 PackageCache 刷新 URP 官方参考实现副本。

.DESCRIPTION
    把 URP 包里最值得学的 HLSL 文件复制到 LEARNING/reference/urp-shaders/，
    统一加 .txt 后缀（Unity 不会把它们当 shader 编译），并在文件头写入来源与用途。

    Unity 升级 URP 之后重跑本脚本即可更新。只读副本，不要直接改这些文件。

.EXAMPLE
    pwsh -NoProfile -File LEARNING/reference/refresh-urp-reference.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

$cache = Join-Path $ProjectPath 'Library\PackageCache'
if (-not (Test-Path $cache)) { throw "找不到 PackageCache：$cache（先用 Unity 打开一次项目）" }

$urp = Get-ChildItem $cache -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^com\.unity\.render-pipelines\.universal@' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $urp) { throw "PackageCache 里没有 URP 包，先用 Unity 打开一次项目" }

$dst = Join-Path $ProjectPath 'LEARNING\reference\urp-shaders'
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# (包内相对路径, 输出文件名, 说明)
$plan = @(
    @('ShaderLibrary\BRDF.hlsl',                    'BRDF.hlsl.txt',                 'PBR 核心：D_GGX / V_SmithGGXCorrelated / F_Schlick / DirectBRDF'),
    @('ShaderLibrary\Lighting.hlsl',                'Lighting.hlsl.txt',             '光照入口：UniversalFragmentPBR / Lambert / BlinnPhong，含 GI 与阴影混合'),
    @('ShaderLibrary\Shadows.hlsl',                 'Shadows.hlsl.txt',              '阴影：主光与附加光采样、级联选择、PCF、ShadowCoord 变换'),
    @('ShaderLibrary\GlobalIllumination.hlsl',      'GlobalIllumination.hlsl.txt',   'GI + 环境光：SH 求值、GlossyEnvironment、SampleSH'),
    @('ShaderLibrary\RealtimeLights.hlsl',          'RealtimeLights.hlsl.txt',       '光源数据结构：Light / AdditionalLightData / GetMainLight'),
    @('ShaderLibrary\Core.hlsl',                    'Core.hlsl.txt',                 'URP 通用工具箱（内含大量 include，是查函数的地方）'),
    @('ShaderLibrary\Unlit.hlsl',                   'Unlit.hlsl.txt',                '最简顶点/片元流程，适合对照自己写的第一个 shader'),
    @('Shaders\LitForwardPass.hlsl',                'LitForwardPass.hlsl.txt',       'URP Lit 的前向 Pass：Varyings 结构、逐片元光照调用'),
    @('Shaders\LitInput.hlsl',                      'LitInput.hlsl.txt',             'Lit 的属性与纹理声明、关键词、SRP Batcher 的 CBUFFER 写法'),
    @('Shaders\LitMetaPass.hlsl',                   'LitMetaPass.hlsl.txt',          'Meta Pass（烘焙用），理解光照贴图为何需要额外 Pass'),
    @('Editor\ShaderGraph\Includes\ShadowCasterPass.hlsl', 'ShadowCasterPass.hlsl.txt', '投射阴影的 Pass：为什么需要一个只写深度的 Pass')
)

$copied = 0
$missing = New-Object System.Collections.Generic.List[string]

@"
# URP 参考副本清单

来源包：$($urp.Name)
刷新时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

| 文件 | 包内路径 | 说明 |
|---|---|---|
"@ | Set-Content (Join-Path $dst 'INDEX.md') -Encoding UTF8

foreach ($row in $plan) {
    $rel = $row[0]; $out = $row[1]; $desc = $row[2]
    $src = Join-Path $urp.FullName $rel
    if (-not (Test-Path $src)) { $missing.Add($rel); continue }

    $text = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8)
    $header = @"
// ═══════════════════════════════════════════════════════════════════
// URP 官方参考实现（只读副本，勿改）
// 来源：$($urp.Name)\$rel
// 用途：见 LEARNING/reference/README.md
// 说明：$desc
// ═══════════════════════════════════════════════════════════════════

"@
    [System.IO.File]::WriteAllText((Join-Path $dst $out), $header + $text,
        (New-Object System.Text.UTF8Encoding($false)))
    Add-Content (Join-Path $dst 'INDEX.md') -Value "| ``$out`` | ``$rel`` | $desc |" -Encoding UTF8
    $copied++
}

Write-Host "已刷新 $copied / $($plan.Count) 个参考文件 -> $dst" -ForegroundColor Green
if ($missing.Count -gt 0) {
    Write-Host "以下路径在本机 URP 包里不存在（Unity 版本可能变了）：" -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host "  $_" }
    Write-Host "请到 PackageCache 里找对应文件的真实路径，然后更新本脚本的 `$plan。" -ForegroundColor Yellow
}
