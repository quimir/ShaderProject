# Unity-MCP 常驻链接（本仓库）

本文件记录 **ShaderProject** 与 Unity Editor 之间的 MCP 通道，保证换会话、重启 DSH 之后依然能连上
`http://127.0.0.1:8081`。

## 1. 端点事实（已实测）

| 项 | 值 |
|---|---|
| Base URL | `http://127.0.0.1:8081` |
| MCP 端点 | `http://127.0.0.1:8081/mcp`（FastMCP Streamable HTTP；`/` 会返回 404） |
| 健康检查 | `GET /health` → `{"status":"healthy","version":"10.2.0","message":"MCP for Unity server is running"}` |
| 服务器 | `mcp-for-unity-server` 3.4.8（Python FastMCP） |
| Unity 实例 | `ShaderProject@a3fa6c3754f3ab93`，Unity `6000.5.4f1`，`Assets/Scenes/SampleScene.unity` |
| 工具数 | 48 + 动态 custom tools |
| 鉴权 | 无（只绑定 127.0.0.1，本地直连） |
| 进程 | `mcp-for-unity.exe --transport http --http-url http://127.0.0.1:8081 --pidfile Library/MCPForUnity/RunState/mcp_http_8081.pid` |

服务器进程由 Unity 插件（`com.coplaydev.unity-mcp`，见 `Packages/manifest.json`）自动拉起，
PID 写在 `Library/MCPForUnity/RunState/mcp_http_8081.pid`，日志在
`Library/MCPForUnity/Logs/server-launch-8081.log`。

## 2. 通道 A：DSH 原生工具（模型直接调用）

配置在 DSH 桌面 profile：

`C:\Users\25466\.dsh\profiles\desktop\cordis.patch.yml`

```yaml
- insert:
    - id: mcp-unity
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: unity
        transport: streamable-http
        url: http://127.0.0.1:8081/mcp
        toolCallTimeoutMs: 600000
        failOnStartupError: false
        reconnect:
          enabled: true
          initialDelayMs: 500
          maxDelayMs: 30000
          maxAttempts: 1000000
```

要点：

- 必须是 `- insert:` 包一层。profile patch 里**裸写**一个 `- id: ...` 行不是插入语法，
  会被 loader 警告并跳过（方言见 `cordis-composition-reference`）。
- `url` 是**完整端点**：客户端内部走 `new StreamableHTTPClientTransport(new URL(config.url))`，
  基址后面要自己带 `/mcp`。
- 行 id `mcp-unity` 用作 patch 目标键；`serverName: unity` 决定工具名前缀。
- `toolCallTimeoutMs` 提到 600000：跑测试/构建/烘焙会超过默认 60s。
- `maxAttempts` 不可写 0（`z.number().min(1)`），写大值≈长期不断线。
- 改完要重启 DSH 才生效；重启后模型侧多出 `mcp__unity__<tool>` 一类工具。

## 3. 通道 B：项目内脚本桥（不依赖任何客户端加载）

`.unity-mcp/unity-mcp.ps1`

```powershell
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 probe
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 tools shader
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 schema manage_shader
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 resources
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 read mcpforunity://project/info
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 console -action get -types '["error","warning"]' -count 5
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 call manage_shader -action read -name MyShader -path Assets/Shaders
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 assets -FilterType Shader -PageSize 20   # 别名 → manage_asset
```

脚本会自动从 `Library/MCPForUnity/RunState/mcp_http_*.pid` 推断端口，端口变了也不用改。
需要换端点时显式传 `-Url http://127.0.0.1:PORT/mcp`。

## 4. 协议坑（踩过的，别再踩）

1. **必须带双 Accept**：`Accept: application/json, text/event-stream`，否则初始化就是 `406 Not Acceptable`。
2. **会话头**：`initialize` 响应头带回 `mcp-session-id`，后续每个请求都要在 `mcp-session-id` 头里回传。
3. **只能连一次 initialize**：同一会话重复 initialize 会得到 `Session not found`。
   PowerShell 里 `Invoke-WebRequest` 每次调用是新进程/新连接，所以要在**一次进程内**完成
   initialize → (notifications/initialized) → tools/list。
4. **SSE 会夹杂通知帧**：`resources/read` 之前服务器会先推 `notifications/message`
   （例如 "Listing Unity instances"），**不要取第一帧**，要按响应 `id` 取匹配帧。
5. **`contents` vs `content`**：`resources/read` 的结果字段是 `result.contents`（复数），
   `tools/call` 是 `result.content`（单数）。写解析器两个都要认。
6. **`notification` 不要当 request 发**：`notifications/initialized` 作为带 id 的请求发会被 pydantic
   拒绝（31 条校验错误）。
7. 工具结果统一包在 `{"success":bool,"message":str,"data":...}` 里；资源文本外面再套一层
   `{"data":{...}}`，字段路径是 `data.<section>.<field>`。

## 5. 自检

```powershell
# 1) 端口活着，并确认是 MCP-for-Unity
Invoke-RestMethod http://127.0.0.1:8081/health

# 2) 两条通道都能打通
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 probe

# 3) 模型侧：调用 mcp__unity__manage_scene（action=get_active）或读 mcpforunity://instances
```

`probe` 应输出：`server : mcp-for-unity-server 3.4.8`、`tools : 48`、以及
`instance_count: 1` 与实例名 `ShaderProject@a3fa6c3754f3ab93`。

## 6. 回滚

```powershell
Copy-Item "C:\Users\25466\.dsh\profiles\desktop\cordis.patch.yml.bak-unitymcp" `
          "C:\Users\25466\.dsh\profiles\desktop\cordis.patch.yml" -Force
```

备份是写入前原样复制的版本（不含 MCP 条目）。只删 `- insert:` 那一段同样可以，其余 patch 行未改动。

## 7. `vendor/` 里是什么

从 `D:\DSH\resources\app.asar` 里抽出来的只读参考副本，用来锁定上面这套配置所依据的契约：

| 文件 | 用途 |
|---|---|
| `vendor\dsh-mcp-client.README.md` | `@deepseek-ai/dsh-mcp-client` 官方说明：配置字段表、重连策略、命名规则 |
| `vendor\dsh-mcp-client.index.js` | 该插件实现：`Config` schema（Schemastery）、URL 处理、工具名前缀算法 |
| `vendor\cordis-plugin-loader\index.js` | Cordis loader 实现，用于核对 patch 方言 |

DSH 升级后如果 MCP 行为变了，先比对这几个文件再改配置。

## 8. Burst `error code 4551` —— 根因与处理（已修复）

报错原文：

```
Unexpected error in Burst compilation: System.AggregateException: ...
(Unable to load the unmanaged library
 `...\Library\BurstCache\JIT\<hash>.dll`, error code 4551)
---> System.DllNotFoundException: ... error code 4551
```

### 4551 是什么

`4551 = 0x11C7 = ERROR_VIRUS_INFECTED`。它**不是**「文件损坏」「缺 VC 运行库」「缺 .NET」。
实测方式：直接让 Windows 加载器去加载那个 dll——

```powershell
[NativeLoad]::LoadLibraryExW($path, [IntPtr]::Zero, 0x00000008)   # 返回 0，GetLastError = 4551
# 系统给出的文案：应用程序控制策略已阻止此文件。
```

即：**是应用程序控制策略拒绝映射这个文件**，在 Unity 进程里被包装成了 `DllNotFoundException`。
本机该策略是 **Smart App Control**：`HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy`
的 `VerifiedAndReputablePolicyState = 1`（开启）。Burst JIT 生成的包装 dll 没有数字签名
（`Get-AuthenticodeSignature` → `NotSigned`），正是 SAC 的拦截目标。

### 为什么它会一直重复

缓存文件本身没坏，PE 结构完整（8 个导出：`burst.initialize`、`burst.setup_extra` 等）。
但**加载被拒不会让 Burst 把这个缓存条目判定为坏**，所以它每次都拿同一个文件再去加载一次，
每次都被拒——于是每次启动编辑器都报一遍。清空缓存、升级 Burst 都没用，文件会原样回来。

### 修复（已验证）

删掉被拒的 dll，逼 Burst 重新编译；**刚写出来的新文件可以直接加载**，被拒状态不会复现。

```powershell
pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1        # 只诊断，列出被拒文件
pwsh -NoProfile -File .unity-mcp/burst-cache-fix.ps1 -Fix   # 备份 + 删除，之后重载编辑器
```

脚本用 `LoadLibraryExW` 逐个探测 `Library/BurstCache/JIT/*.dll`，把 4551 的文件备份到
`.unity-mcp/burst-blocked-backup/` 再删除；随后重载编辑器或调用 `refresh_unity` 触发重编译。

本次实测结果：5 个被拒 dll 清除后重新生成，`f04c342a…dll`（2026/10/11 10:30:08）
与 `af32fe3ee247…dll`（10:30:09）均已可正常加载，控制台 error 归零。

### 会不会复发

会，但只在缓存变旧之后。SAC 的判断带时间/信誉因素：同一批字节，陈旧的会被拒，
刚生成的能加载。所以复发时**再跑一次同样的脚本即可**，不需要清空整个 `Library`。

想彻底不再出现，只有关掉 SAC（管理员 + 重启，且属于不可逆的降级操作，不建议随手做）。
`Set-MpPreference -ExclusionPath` 对此无效：SAC 的判定发生在 Defender 实时扫描之前，
排除路径管不到它。
