<#
.SYNOPSIS
    Diagnose and clear Burst JIT compile-cache entries that Windows blocks from loading.

.DESCRIPTION
    Symptom in the Unity console:

        Unexpected error in Burst compilation: System.AggregateException: ...
        (Unable to load the unmanaged library
         `...\Library\BurstCache\JIT\<hash>.dll`, error code 4551)
        ---> System.DllNotFoundException: ... error code 4551

    Error 4551 is Win32 0x11C7 ERROR_VIRUS_INFECTED. Windows raises it when an
    application-control policy -- on consumer Windows that is Smart App Control
    (SAC) -- refuses the file. In the Unity Editor process Burst surfaces it as
    DllNotFoundException. The DLL is not corrupt: the policy simply declines to
    map it.

    Burst would normally recompile a library the user deleted, but a blocked
    loader request does not mark the cache entry as bad, so the stale file stays
    and the error repeats on every Editor start. Deleting the blocked DLL forces
    a fresh compile, and the freshly written file loads.

    Run with no arguments for a read-only report. Pass -Fix to delete the blocked
    files after backing them up.

.PARAMETER Fix
    Back up every blocked DLL/PDB, then delete it so Burst recompiles it.
    Reload the Unity Editor (or call refresh_unity) afterwards.

.PARAMETER ProjectPath
    Unity project root. Defaults to the repository this script lives in.

.EXAMPLE
    pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1
    pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1 -Fix
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [string]$ProjectPath
)

$ErrorActionPreference = 'Stop'

if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $PSScriptRoot }
$jitRoot = Join-Path $ProjectPath 'Library\BurstCache\JIT'
$backupDir = Join-Path $ProjectPath '.unity-mcp\burst-blocked-backup'

if (-not (Test-Path $jitRoot)) {
    Write-Host "No Burst JIT cache at $jitRoot - nothing to check."
    return
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BurstCacheProbe {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern IntPtr LoadLibraryExW(string lpLibFileName, IntPtr hFile, uint dwFlags);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr hModule);
}
'@

# Ask the loader directly, the same way Unity does: a refusal is the bug.
function Test-Loadable {
    param([string]$Path)
    $handle = [BurstCacheProbe]::LoadLibraryExW($Path, [IntPtr]::Zero, 0x00000008)
    if ($handle -ne [IntPtr]::Zero) {
        [void][BurstCacheProbe]::FreeLibrary($handle)
        return $null
    }
    return [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
}

Write-Host "Burst JIT cache : $jitRoot"
$dlls = @(Get-ChildItem $jitRoot -Filter '*.dll' -File -ErrorAction SilentlyContinue)
Write-Host "DLL count       : $($dlls.Count)"

$blocked = @()
foreach ($dll in $dlls) {
    $err = Test-Loadable -Path $dll.FullName
    if ($null -ne $err) {
        $blocked += [pscustomobject]@{
            File      = $dll.Name
            Win32     = $err
            Meaning   = if ($err -eq 4551) { 'ERROR_VIRUS_INFECTED - blocked by an application-control policy' } else { 'load refused' }
            SizeBytes = $dll.Length
            Written   = $dll.LastWriteTime
            Path      = $dll.FullName
        }
    }
}

if ($blocked.Count -eq 0) {
    Write-Host "`nAll Burst JIT libraries load. Nothing to repair." -ForegroundColor Green
    return
}

Write-Host "`nBlocked libraries: $($blocked.Count)" -ForegroundColor Yellow
$blocked | Select-Object File, Win32, SizeBytes, Written, Meaning | Format-Table -AutoSize

if (-not $Fix) {
    Write-Host "Read-only report. Re-run with -Fix to back up and delete these files." -ForegroundColor Yellow
    return
}

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
foreach ($item in $blocked) {
    foreach ($ext in 'dll', 'pdb') {
        $source = [System.IO.Path]::ChangeExtension($item.Path, $ext)
        if (Test-Path $source) {
            Copy-Item $source (Join-Path $backupDir ([System.IO.Path]::GetFileName($source))) -Force
            Remove-Item $source -Force
            Write-Host "  cleared $(Split-Path -Leaf $source)"
        }
    }
}

Write-Host "`nRemoved $($blocked.Count) blocked librar(y/ies); originals kept in:" -ForegroundColor Green
Write-Host "  $backupDir"
Write-Host "Reload the Unity Editor (or run refresh_unity) so Burst recompiles them."
