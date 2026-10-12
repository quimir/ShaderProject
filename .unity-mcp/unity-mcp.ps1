<#
.SYNOPSIS
    Standalone bridge to the MCP for Unity server that serves this project.

.DESCRIPTION
    Talks Streamable HTTP MCP directly to the FastMCP endpoint the Unity plugin
    launches (this project runs on http://127.0.0.1:8082/mcp), so Unity can be driven from a
    shell without depending on any editor integration being loaded.

    The Unity Editor plugin writes the endpoint and its instance token into
    Library/MCPForUnity/RunState, which this script reads so the endpoint stays
    correct if the port ever changes.

.EXAMPLE
    pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 probe
    pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 tools
    pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 assets -FilterType Shader -PageSize 20
    pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 read mcpforunity://editor/state
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Command,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest,

    [string]$Url,
    [int]$TimeoutSec = 300,
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$projectRoot = Split-Path -Parent $PSScriptRoot

function Get-Endpoint {
    if ($Url) { return $Url }
    $runState = Join-Path $projectRoot 'Library\MCPForUnity\RunState'
    if (Test-Path $runState) {
        $pidFile = Get-ChildItem $runState -Filter 'mcp_http_*.pid' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($pidFile -and $pidFile.BaseName -match 'mcp_http_(\d+)$') {
            return "http://127.0.0.1:$($Matches[1])/mcp"
        }
    }
    return 'http://127.0.0.1:8082/mcp'
}

$script:endpoint = Get-Endpoint
$script:session = $null
$script:nextId = 0

function Invoke-McpRequest {
    param([string]$Method, $Params)

    $script:nextId++
    $payload = @{
        jsonrpc = '2.0'
        id      = $script:nextId
        method  = $Method
        params  = $Params
    } | ConvertTo-Json -Depth 40 -Compress

    $headers = @{
        'Accept'       = 'application/json, text/event-stream'
        'Content-Type' = 'application/json'
    }
    if ($script:session) { $headers['mcp-session-id'] = $script:session }

    try {
        $resp = Invoke-WebRequest -Uri $script:endpoint -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec $TimeoutSec -UseBasicParsing
    } catch {
        $hint = "Unity Editor not reachable at $script:endpoint. " +
                "Open the project's Unity Editor and confirm the MCP for Unity window shows 'Running'."
        throw "$hint`n$($_.Exception.Message)"
    }

    $sid = $resp.Headers['mcp-session-id']
    if ($sid -and $sid.Count -gt 0) { $script:session = $sid[0] }

    $frames = @()
    foreach ($line in ($resp.Content -split "`r?`n")) {
        if ($line -match '^data:\s*(.*)$') { $frames += $Matches[1] }
    }
    # The server interleaves notifications (e.g. "Listing Unity instances") with the
    # real reply, so select the frame carrying this request's id, not the first one.
    $deferred = $null
    foreach ($frame in $frames) {
        if ([string]::IsNullOrWhiteSpace($frame)) { continue }
        $msg = $frame | ConvertFrom-Json -Depth 40
        if ($msg.PSObject.Properties.Name -contains 'error') {
            throw "MCP error $($msg.error.code): $($msg.error.message)"
        }
        if ($msg.PSObject.Properties.Name -contains 'id' -and $msg.id -eq $script:nextId) {
            return $msg
        }
        if ($msg.PSObject.Properties.Name -contains 'id') { $deferred = $msg }
    }
    return $deferred
}

function Connect-Mcp {
    $init = Invoke-McpRequest -Method 'initialize' -Params @{
        protocolVersion = '2024-11-05'
        capabilities    = @{}
        clientInfo      = @{ name = 'shaderproject-bridge'; version = '1.0.0' }
    }
    # Notifications carry no id and expect no reply; the server answers with 202.
    $headers = @{
        'Accept'       = 'application/json, text/event-stream'
        'Content-Type' = 'application/json'
    }
    if ($script:session) { $headers['mcp-session-id'] = $script:session }
    $note = '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'
    try {
        Invoke-WebRequest -Uri $script:endpoint -Method Post -Headers $headers `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($note)) -TimeoutSec 30 -UseBasicParsing | Out-Null
    } catch { }
    return $init.result
}

# Unwrap the common { success, message, data } envelope the Unity tools return.
# tools/call answers with result.content (singular); resources/read answers with
# result.contents (plural) — accept either so one formatter covers both.
function Format-McpResult {
    param($Message)

    $blocks = @()
    if ($Message -and $Message.PSObject.Properties.Name -contains 'result' -and $Message.result) {
        $env = $Message.result
        if ($env.PSObject.Properties.Name -contains 'content') { $blocks += @($env.content) }
        if ($env.PSObject.Properties.Name -contains 'contents') { $blocks += @($env.contents) }
    }

    $texts = @()
    foreach ($b in $blocks) {
        if ($b.text) { $texts += $b.text }
        elseif ($b.type) { $texts += "[$($b.type) content]" }
    }
    $text = ($texts -join "`n").Trim()
    if (-not $text) { return '(<empty result>)' }

    $parsed = $null
    try { $parsed = $text | ConvertFrom-Json -Depth 40 } catch { }

    if ($parsed -and ($parsed.PSObject.Properties.Name -contains 'data') -and $null -ne $parsed.data) {
        $ok = if ($parsed.PSObject.Properties.Name -contains 'success') { [bool]$parsed.success } else { $true }
        $head = if ($ok) { "# ok" } else { "# FAILED" }
        if ($parsed.message) { $head += "  $($parsed.message)" }
        if (-not $ok -and $parsed.error) { $head += "  error: $($parsed.error)" }
        return "$head`n$($parsed.data | ConvertTo-Json -Depth 40)"
    }
    return $text
}

function Get-ToolSchema {
    param([string]$Name)
    $list = Invoke-McpRequest -Method 'tools/list' -Params @{}
    return $list.result.tools | Where-Object { $_.name -eq $Name }
}

function Convert-ArgValue {
    param([string]$Text)
    if ($Text -match '^(true|false)$') { return [bool]$Text }
    if ($Text -match '^-?\d+$') { return [int64]$Text }
    if ($Text -match '^-?\d*\.\d+$') { return [double]$Text }
    if ($Text -match '^[\[{]') {
        try { return ($Text | ConvertFrom-Json -Depth 40) } catch { }
    }
    return $Text
}

$toolAliases = @{
    assets     = 'manage_asset'
    scene      = 'manage_scene'
    editor     = 'manage_editor'
    gameobject = 'manage_gameobject'
    shader     = 'manage_shader'
    material   = 'manage_material'
    script     = 'manage_script'
    build      = 'manage_build'
    camera     = 'manage_camera'
    components = 'manage_components'
    prefabs    = 'manage_prefabs'
    console    = 'read_console'
    tests      = 'run_tests'
    testjob    = 'get_test_job'
    refresh    = 'refresh_unity'
}

# Bare tool aliases: 'assets -FilterType Shader' == 'call manage_asset -FilterType Shader'.
if ($toolAliases.ContainsKey($Command)) {
    $Rest = @($toolAliases[$Command]) + @($Rest)
    $Command = 'call'
}

switch ($Command.ToLowerInvariant()) {

    'probe' {
        $init = Connect-Mcp
        $info = $init.serverInfo
        $tools = (Invoke-McpRequest -Method 'tools/list' -Params @{}).result.tools
        $instances = Format-McpResult (Invoke-McpRequest -Method 'resources/read' -Params @{ uri = 'mcpforunity://instances' })
        Write-Output "endpoint   : $script:endpoint"
        Write-Output "server     : $($info.name) $($info.version)"
        Write-Output "tools      : $($tools.Count)"
        Write-Output "unity      : $instances"
    }

    'tools' {
        $null = Connect-Mcp
        $tools = (Invoke-McpRequest -Method 'tools/list' -Params @{}).result.tools
        if ($Rest -and $Rest.Count -gt 0) {
            $tools = $tools | Where-Object { $_.name -like "*$($Rest[0])*" }
        }
        foreach ($t in ($tools | Sort-Object name)) {
            Write-Output ("{0,-32} {1}" -f $t.name, $t.description)
        }
    }

    'schema' {
        $null = Connect-Mcp
        if (-not $Rest -or $Rest.Count -lt 1) { throw 'usage: schema <toolName>' }
        $tool = Get-ToolSchema -Name $Rest[0]
        if (-not $tool) { throw "no such tool: $($Rest[0])" }
        $tool | ConvertTo-Json -Depth 40
    }

    'read' {
        $null = Connect-Mcp
        if (-not $Rest -or $Rest.Count -lt 1) { throw 'usage: read <mcpforunity://uri>' }
        $msg = Invoke-McpRequest -Method 'resources/read' -Params @{ uri = $Rest[0] }
        $texts = @($msg.result.contents | ForEach-Object { $_.text })
        $joined = ($texts -join "`n")
        try { $joined = ($joined | ConvertFrom-Json -Depth 40) | ConvertTo-Json -Depth 40 } catch { }
        Write-Output $joined
    }

    'resources' {
        $null = Connect-Mcp
        $list = Invoke-McpRequest -Method 'resources/list' -Params @{}
        foreach ($r in $list.result.resources) { Write-Output ("{0,-24} {1}" -f $r.name, $r.uri) }
    }

    'call' {
        $null = Connect-Mcp
        if (-not $Rest -or $Rest.Count -lt 1) { throw 'usage: call <toolName> [-Key value] [-Flag]' }
        $toolName = $Rest[0]
        $argsTable = @{}
        $i = 1
        while ($i -lt $Rest.Count) {
            $token = $Rest[$i]
            if ($token -match '^-{1,2}(.+)$') {
                $key = $Matches[1]
                $nextIsValue = ($i + 1 -lt $Rest.Count) -and ($Rest[$i + 1] -notmatch '^-{1,2}[A-Za-z]')
                if ($nextIsValue) {
                    $argsTable[$key] = Convert-ArgValue $Rest[$i + 1]
                    $i += 2
                } else {
                    $argsTable[$key] = $true
                    $i += 1
                }
            } else {
                throw "unexpected positional token '$token' after '$toolName'; use -Key value pairs"
            }
        }
        $msg = Invoke-McpRequest -Method 'tools/call' -Params @{ name = $toolName; arguments = $argsTable }
        if ($Raw) { $msg | ConvertTo-Json -Depth 40; break }
        Format-McpResult $msg
    }

    'raw' {
        $null = Connect-Mcp
        if (-not $Rest -or $Rest.Count -lt 2) { throw 'usage: raw <method> <jsonParams>' }
        $params = $Rest[1] | ConvertFrom-Json -Depth 40
        $msg = Invoke-McpRequest -Method $Rest[0] -Params $params
        $msg | ConvertTo-Json -Depth 40
    }

    default {
        throw "unknown command '$Command'. Use: probe | tools [filter] | schema <tool> | resources | read <uri> | call <tool> [-Key value] | raw <method> <json>"
    }
}

