# 计算机图形学学习路线 · 结合 ShaderProject 的实战版

> 目标：从「会写 shader」走到「懂渲染器」。每个阶段都以**能在本项目里跑起来、能截图验证**的产物收尾，
> 不产出「看完了但没写过」的知识。

## 0. 你现在的起点（已实测）

| 项 | 现状 |
|---|---|
| 引擎 | Unity `6000.5.4f1`（Unity 6），URP `17.5.0` |
| 渲染配置 | `Mobile_RPAsset` / `PC_RPAsset` 双 RP Asset，各自带 Renderer |
| 着色器 | 只有 `Assets/Shaders/NewUnlitUniversalRenderPipelineShader.shader`（URP Unlit 模板） |
| 场景 | `Assets/Scenes/SampleScene.unity`，3 个根物体：Main Camera / Directional Light / Global Volume |
| 工具链 | Unity-MCP 常驻通道（见 `UNITY-MCP.md`）：可直接建 shader、读控制台、截图自检 |

**这意味着你不需要新建项目**。所有阶段的作业都落在 `Assets/Shaders/` 与 `Assets/Scripts/` 下，
用现有的 MCP 通道做「改 → 编译 → 截图 → 看控制台」的闭环。反过来，图形学练熟了，
这个项目本身就会长成一个像样的渲染器。

---

## 1. 路线总览

```
阶段0 数学直觉 ──┐
                 ├─→ 阶段1 光栅化基础 ──→ 阶段2 PBR ──→ 阶段3 阴影/GI ──→ 阶段4 渲染管线工程
阶段0 数学证明 ──┘                                          │
                                                            └─→ 阶段5 光线追踪（可并行，回报最直接）
                                                                     │
阶段6 引擎架构（GAMES104）· 阶段7 综合项目（自研混合渲染器）
```

依赖关系的硬约束只有三条，其余都能交叉进行：

1. **阶段 1 必须在阶段 2 之前**：不会写插值、法线变换、UV，PBR 只是抄公式。
2. **阶段 3 依赖阶段 2**：阴影是「对光源方向的可见性」，先得有正确的光照。
3. **阶段 5（光追）不依赖阶段 3/4**：可以早点开始，它对理解采样/蒙特卡洛/降噪的帮助最大。

---

## 2. 阶段 0 · 数学直觉（2–3 周）

图形学的数学不是「学完再用」，是「用到再补」。这个阶段只求**看得懂几何含义**，不求推导。

### 资源

| 类型 | 资源 | 说明 |
|---|---|---|
| 视频 | [3Blue1Brown 线性代数的本质](https://www.bilibili.com/video/BV1ys411472E) | 矩阵=变换、行列式=体积缩放、特征向量。中文配音版 B 站有 |
| 视频 | [3Blue1Brown 微积分的本质](https://www.bilibili.com/video/BV1qW411N7FU) | 只看到「导数=变化率」「积分=累加」够用 |
| 视频 | [Freya Holmér — The Math of Computer Graphics](https://www.youtube.com/watch?v=MOYiVLEnhrw)（B 站有搬运） | 点乘/叉乘/矩阵在 shader 里到底在干什么，讲得比教材快 |
| 书 | 《3D 数学基础：图形与游戏开发》 | 工具书，别通读。第 4–8 章（向量/矩阵/变换）对着目录查 |

### 本阶段产物

在 `Assets/Shaders/` 下写 `Math_Viz.shader`：**不用任何光照模型**，只做可视化。

- 用 `dot(N, L)` 输出灰度 → 直观看到兰伯特项
- 用 `cross(T, B)` 画法线切线空间的三个轴
- 用 `frac(uv * n)` 画网格，模拟 UV 采样
- 用矩阵 `mul()` 手搓一次旋转 + 平移 + 缩放，和 Transform 面板对账

判据：你能不查资料说出「法线为什么可以用 `(M^-1)^T` 变换，而点可以直接用 `M`」。

---

## 3. 阶段 1 · 光栅化与 shader 基础（4–6 周）

**这是整条路线里性价比最高的一段。** 把这一段吃透，后面都是加概念。

### 资源

| 类型 | 资源 | 说明 |
|---|---|---|
| 课程 | [GAMES101 现代计算机图形学入门](https://games-cn.org/intro-graphics/)（闫令琪，免费） | **主线**。B 站有全集。重点：光栅化、光栅化中的抗锯齿、着色模型、纹理、几何 |
| 课程 | [CS184 Computer Graphics and Imaging](https://cs184.eecs.berkeley.edu/)（Berkeley，公开） | 英文对照，作业是 WebGL 版光栅化器，和 GAMES101 互补 |
| 书 | 《Unity Shader 入门精要》冯乐乐（人民邮电） | 中文 Unity 向最稳的一本。**只看第 1–8 章**，后面偏技巧 |
| 书 | [LearnOpenGL](https://learnopengl.com/)（中文版 [learnopengl-cn](https://learnopengl-cn.github.io/)） | 想搞懂「管线每一步在干嘛」，这本最直白 |
| 书 | [Interactive Computer Graphics (Angel)](https://www.cs.unm.edu/~angel/BOOK/INTERACTIVE_COMPUTER_GRAPHICS/) | 教材型；**版次以官网当前版本为准**，别按记忆买旧版 |
| 手册 | [Unity URP 编写自定义着色器](https://docs.unity3d.com/6000.5/Documentation/Manual/urp/writing-custom-shaders-urp.html) | URP 下的正确写法（`HLSLPROGRAM`、`Core.hlsl`、SRP Batcher 约束） |
| 工具 | [ShaderToy](https://www.shadertoy.com/) | 练 GLSL 手感，不追求工程性，只求快 |

### 本阶段产物（按顺序，每个都可截图）

1. **`Unlit_Checker.shader`** — 程序化棋盘格 + UV 缩放/偏移，先建立「片元着色器在算什么」的直觉。
2. **`Lit_Lambert.shader`** — 把 URP Unlit 模板改成手写 Lambert（自己取主光方向、算 N·L、加环境光）。
3. **`Lit_BlinnPhong.shader`** — 加高光、法线贴图采样、切线空间变换。
4. **`Rasterizer.cs`（可选但强烈建议）** — 用 C# 写一个 CPU 光栅化器：三角形填充、重心坐标、Z-Buffer。
   这一步做完，「GPU 在干什么」会从黑箱变成透明的。

判据：给你一个法线贴图，你能说清 `UnpackNormal` 之后为什么还要 `TBN` 变换；
看到锯齿，你知道是 MSAA 还是着色问题。

---

## 4. 阶段 2 · 从 Blinn-Phong 到 PBR（4–6 周）

| 类型 | 资源 | 说明 |
|---|---|---|
| 书 | [Real-Time Rendering 4th](https://www.realtimerendering.com/)（RTR4）第 9 章「Physically Based Shading」 | **本章是核心**，反复读 |
| 书 | RTR4 中文版《实时渲染（第 4 版）》（清华大学出版社）；社区翻译 [Real-Time-Rendering-4th-CN](https://github.com/Morakito/Real-Time-Rendering-4th-CN) | 中文对照用 |
| 书 | [Physically Based Rendering (PBRT)](https://pbr-book.org/) 第 4 版**在线免费** | 偏离线渲染，但 BRDF/采样/蒙特卡洛的定义最严谨 |
| 视频 | [Google Filament — Physically Based Rendering](https://google.github.io/filament/Materials.html) | 工业实现口径，比教材更贴工程 |
| 视频 | [Sébastien Lagarde — Reading Between The Lines](https://www.seblagarde.wordpress.com/) | Frostbite 的 PBR 推导，看完知道「为什么是这些公式」 |
| 工具 | [Disney BRDF Explorer](https://github.com/wdas/brdf)、[BRDF Explorer 探究](https://www.shadertoy.com/) | 直观对比 GGX / Phong / Beckmann |

### 本阶段产物

1. **`PBR_Direct.shader`** — Cook-Torrance：GGX 法线分布 + Smith 几何项 + Schlick 菲涅尔。手写，别用 URP 的 `Lit`。
2. **`PBR_Debug_Views.shader`** — 用 keyword 切换显示 `D` / `G` / `F` / `NdotV` 各项。**调试可视化是职业素养**，不是附加题。
3. **`PBR_IBL.shader`** — 接入环境光照：预过滤 cubemap + BRDF LUT。可先用 Unity 的 `Lightmapping` 烘一份对照。
4. **能量守恒实验** — 把 roughness 从 0 拉到 1，截图成一组，检查是否出现「变漂亮了但能量不守恒」。

判据：你能解释 metallic/roughness 两个参数各自改的是公式里的哪一项，
以及为什么金属的漫反射项应该接近 0。

---

## 5. 阶段 3 · 阴影与实时全局光照（5–8 周）

| 类型 | 资源 | 说明 |
|---|---|---|
| 课程 | [GAMES202 高质量实时渲染](https://games-cn.org/games202/)（闫令琪，免费） | **本阶段主线**。实时阴影、实时 GI、降噪、SSAO |
| 书 | RTR4 第 7 章「Shadows」、第 11 章「Global Illumination」 | 对照查 |
| 书 | [Ray Tracing Gems](https://www.realtimerendering.com/raytracinggems/)（免费在线） | 降噪、采样、RTX 实践，读起来很快 |
| 视频 | [Acerola](https://www.youtube.com/c/Acerola_t) 的阴影/光照系列；[Sebastian Lague](https://www.youtube.com/c/SebastianLague) 的 Ray Tracing 系列 | 动手向，直观 |
| 论文 | [SIGGRAPH 课程 Real-Time Shadows](https://sites.cs.ucsb.edu/~lingqi/)（闫令琪讲课资料） | 阴影算法的谱系图 |

### 本阶段产物

1. **`Shadow_ShadowMap.shader`** — 手写 Shadow Map：深度 pass + 采样 + PCF 3×3。**不要用 URP 自带的阴影**，自己搭一遍。
2. **`Shadow_Cascaded.shader`** — 级联阴影（CSM）：2–3 级 + 级间混合，看着远处阴影从糊变清楚。
3. **`SSAO_RendererFeature.cs` + `SSAO.shader`** — 作为 URP **Renderer Feature** 接入（这是阶段 4 的预演）。
4. **`GI_SSR.shader`** — 屏幕空间反射，配合降噪（哪怕只是一个简单的时域累积）。

判据：你能说出 shadow acne 和 peter-panning 各自的成因与调参方向，以及为什么需要 bias。

---

## 6. 阶段 4 · 渲染管线工程（4–6 周）

到这里要从「写 shader」跨到「搭管线」——这是从 TA 走向渲染工程师的分水岭。

| 类型 | 资源 | 说明 |
|---|---|---|
| 手册 | [Unity URP Renderer Features](https://docs.unity3d.com/6000.5/Documentation/Manual/urp/renderer-features/renderer-features-landing.html) | 官方口径 |
| 手册 | [Universal RenderPipeline 源码](https://github.com/Unity-Technologies/Graphics)（`com.unity.render-pipelines.universal`） | **读源码**这一步躲不掉，从这个阶段开始读 |
| 书 | RTR4 第 17–20 章：Pipeline、Deferred、Image Effects、Non-Photorealistic | 按目录查 |
| 视频 | [GDC Vault 的 Rendering 系列](https://www.gdcvault.com/)；[Advances in Real-Time Rendering (SIGGRAPH)](https://advances.realtimerendering.com/) | 每年 SIGGRAPH 课程，免费，前沿且工程化 |
| 书 | 《游戏引擎架构》(Game Engine Architecture, Jason Gregory) 第 11 章 | 渲染器在引擎中的位置 |

### 本阶段产物

1. **`Outline_RendererFeature.cs`** — 用 Renderer Feature 做描边：`RenderObjects` + 背面外扩 + 深度/法线。
2. **自己实现一个 Deferred 路径** — 用 `ScriptableRenderPass` 手写 G-Buffer 输出（3–4 张 RT），再手写光照 pass。
   做完你会真正理解为什么移动端更偏好 Forward+/Tiled。
3. **`PostProcess_Stack.cs`** — 串联 Bloom + Tone Mapping（ACES 或 AgX）+ Color Grading，作为后处理链。
4. **性能基线表** — 用 `manage_profiler` / Frame Debugger 记录每个 pass 的耗时，做成表格存进仓库。
   **没有数据的优化都是猜测。**

判据：看到 Unity Profiler 里某个 pass 变贵，你能定位到是自己的哪个 Renderer Feature。

---

## 7. 阶段 5 · 光线追踪与采样（4–8 周，可与阶段 3/4 并行）

| 类型 | 资源 | 说明 |
|---|---|---|
| 书 | [Ray Tracing in One Weekend](https://raytracing.github.io/)（3 册，免费） | **最好的入门**，周末就能跑通 |
| 书 | [PBRT 4th](https://pbr-book.org/)（在线免费） | 采样理论、BSDF、积分器的权威。挑第 2 章（蒙特卡洛）+ 第 8 章（采样） |
| 论文 | [Veach 1997 — Robust Monte Carlo Methods](https://graphics.stanford.edu/papers/veach_thesis/) | 多重重要性采样（MIS）的源头，读第 9 章 |
| 课程 | [GAMES101 的光追部分](https://games-cn.org/intro-graphics/)（Whitted、路径追踪）+ GAMES202 的降噪 | 中文讲解 |
| 视频 | [Sebastian Lague — Ray Tracing](https://www.youtube.com/c/SebastianLague) | 工程实现向 |

### 本阶段产物

1. **`PathTracer.cs`（Unity 内）** — CPU 路径追踪，输出到一张 `Texture2D`，在 `SampleScene` 里贴到一个 Quad 上。
   先用现成的 `Camera` 参数取射线，简单粗暴但立刻有画面。
2. **升级为 Compute Shader** — 把上面的循环搬进 `ComputeShader`，做渐进式渲染（每帧多累积 1 spp），
   看着噪点慢慢收敛。这一步是理解 GPU 并行 + 时域累积的最好练习。
3. **接降噪** — 先做简单的时域累积 + 邻域滤波，再试 SVGF / A-SVGF 的思路。
4. **和光栅化对账** — 同一个场景，光栅化结果 vs 路径追踪结果并排截图，分析差异来自哪里
   （间接光？阴影软硬？高光？）。

判据：你能解释「为什么噪点收敛速度是 1/√N」，以及 MIS 解决了什么问题。

---

## 8. 阶段 6 · 引擎架构视角（3–4 周）

| 类型 | 资源 | 说明 |
|---|---|---|
| 课程 | [GAMES104 现代游戏引擎：从入门到实践](https://games104.boomingtech.com/)（王希，免费） | 中文最好的引擎课，讲渲染管线在引擎中的位置 |
| 书 | 《游戏引擎架构》(Game Engine Architecture) 第三版，Jason Gregory | 工具书，按需查 |
| 书 | [GPU Gems 1–3](https://developer.nvidia.com/gpugems/gpugems3/contributors)（NVIDIA 免费在线） | 章节式，挑渲染相关读 |
| 手册 | [AMD GPUOpen](https://gpuopen.com/)、[NVIDIA GPU 编程指南](https://docs.nvidia.com/cuda/) | 硬件视角 |

**产出**：不是代码，是一份你自己的《ShaderProject 渲染架构说明》——
写清楚数据怎么流、哪些 pass、资源怎么管、瓶颈在哪。写到能给别人讲明白为止。

---

## 9. 阶段 7 · 综合项目（持续）

把前面所有东西收进 ShaderProject，做成一个**自研混合渲染器**：

| 模块 | 内容 | 对应阶段 |
|---|---|---|
| 前向 PBR 主路径 | 手写 BRDF + IBL | 阶段 2 |
| 阴影 | CSM + SSAO | 阶段 3 |
| 后处理链 | Bloom + ACES/AgX + TAA | 阶段 4 |
| 光追反射/GI | Compute Shader 路径追踪 + 降噪，与光栅化混合 | 阶段 5 |
| 性能面板 | 各 pass 耗时 + 显存占用，实时显示 | 阶段 4 |
| 文档 | 架构说明 + 每阶段的验证截图 | 阶段 6 |

这个项目本身就是你最好的作品集。求职/接单时，「我写过一个带 CSM + SSAO + 光追反射的 URP 渲染管线」
比任何证书都有说服力。

---

## 10. 长期参考书单（按需查，别通读）

| 书 | 定位 | 获取 |
|---|---|---|
| [Real-Time Rendering 4th](https://www.realtimerendering.com/) | 实时渲染圣经 | 有中文版；社区翻译 [GitHub](https://github.com/Morakito/Real-Time-Rendering-4th-CN) |
| [Physically Based Rendering 4th](https://pbr-book.org/) | 离线渲染圣经 | 官网在线免费 |
| [Ray Tracing Gems I/II](https://www.realtimerendering.com/raytracinggems/) | 光追工程集 | 免费 PDF |
| [GPU Gems 1–3](https://developer.nvidia.com/gpugems/gpugems3/contributors) | GPU 技巧集 | NVIDIA 免费在线 |
| [ShaderX 系列](https://www.realtimerendering.com/resources/shaderx/) | 着色器技巧 | 老但经典 |
| 《游戏引擎架构》(Gregory) | 引擎全景 | 第三版纸质 |
| 《Unity Shader 入门精要》(冯乐乐) | Unity 入门 | 人民邮电 |
| [Filament 文档](https://google.github.io/filament/) | 工业级 PBR 口径 | 免费在线 |
| [LearnOpenGL](https://learnopengl.com/) | 图形 API 基础 | 免费在线，有[中文版](https://learnopengl-cn.github.io/) |

> 版次注意：教材常有新版（如 Angel 的 Interactive Computer Graphics、RTR 系列）。
> 买之前**核对出版社官网当前版次**，别按记忆或二手信息下单。

---

## 11. 平台的实战题库

| 平台 | 特点 | 适合阶段 |
|---|---|---|
| [ShaderToy](https://www.shadertoy.com/) | GLSL 片段着色器，反馈最快 | 0–1 |
| [Shadertoy 上的 raymarching 教程](https://www.shadertoy.com/view/MdX3Rr) | 用 SDF 做体积渲染，理解「片元着色器能干嘛」 | 1、5 |
| [Coding Adventure (Sebastian Lague)](https://www.youtube.com/c/SebastianLague) | 从零实现，过程完整 | 1–5 |
| [catlikecoding — Rendering 系列](https://catlikecoding.com/unity/tutorials/) | Unity 向的渲染教程，**逐篇精读** | 1–4 |
| [GPUOpen / NVIDIA 技术博客](https://gpuopen.com/) | 工业实践 | 4–6 |
| [pbrt 的在线书 + 代码](https://pbr-book.org/) | 读源码级 | 5 |

---

## 12. 怎么用这套 MCP 通道加速学习

你在 `ShaderProject` 里已经有常驻的 Unity-MCP 连接，把它当成「图形学实验台的即时反馈」：

```powershell
# 建/改 shader（也支持 manage_shader create）
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 shader -action read -name NewUnlitUniversalRenderPipelineShader -path Assets/Shaders
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 shader -action update -name PBR_Direct -path Assets/Shaders -contents <CODE>

# 看有没有编译错
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 console -action get -types '["error","warning"]' -count 10

# 让编辑器刷新并重编译
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 refresh -mode force -scope all -compile request

# 截图自检（学习过程中每改一版就留档）
pwsh -NoProfile -File .unity-mcp/unity-mcp.ps1 camera -action screenshot
```

或者直接用模型侧的原生工具（`mcp__unity__manage_shader`、`mcp__unity__manage_camera`、
`mcp__unity__read_console`），走 `mcp__unity__*` 这一套。

建议：**每个阶段的每个产物都截一张图存进仓库**（比如 `.unity-mcp/shots/`），
半年后回头看，这就是你自己的成长曲线。

---

## 13. 时间预算参考

按每周 10–12 小时（业余强度）：

| 阶段 | 时长 | 累计 |
|---|---|---|
| 0 数学直觉 | 2–3 周 | 3 周 |
| 1 光栅化与 shader 基础 | 4–6 周 | 9 周 |
| 2 PBR | 4–6 周 | 15 周 |
| 3 阴影与 GI | 5–8 周 | 23 周 |
| 4 渲染管线工程 | 4–6 周 | 29 周 |
| 5 光追（可并行） | 4–8 周 | 33 周 |
| 6 引擎架构 | 3–4 周 | 37 周 |
| 7 综合项目 | 持续 | — |

大约 8–10 个月到「能自己搭渲染管线」的水平。如果每天能投入 3 小时以上，压缩到 4–5 个月。

---

## 14. 三条容易走错的路（先说清楚）

1. **只看课不写代码**：GAMES101 的作业一定要做。光栅化器自己写一遍，比看十遍视频有用。
2. **过早追求「高级特效」**：屏幕空间反射、体积雾很酷，但没搞懂 BRDF 就去写，只会得到「能跑但不对」的结果。
3. **不读源码**：从阶段 4 起必须读 URP 源码。shader 只是冰山一角，管线怎么调度资源才是大头。

---

## 附：本仓库相关文件

| 文件 | 作用 |
|---|---|
| `.unity-mcp/UNITY-MCP.md` | MCP 通道说明、协议坑、自检命令 |
| `.unity-mcp/unity-mcp.ps1` | 脚本桥，可直接驱动作业流程 |
| `.unity-mcp/burst-cache-fix.ps1` | 性能相关环境问题的诊断脚本（见 UNITY-MCP.md 第 8 节） |
