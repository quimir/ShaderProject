# 渲染学习路线 · ShaderProject 实战版

> **这本书/课要不要吃透？** 见每条的 `标签` 列。三个档位的定义在
> [`AI-HANDOFF.md`](AI-HANDOFF.md) 第 4 节：
> **吃透** = 能自己复述原理并手写实现（占 60% 时间）· **扫读** = 知道有这东西、什么时候用（占 25%）·
> **工具书** = 按目录查，不通读（占 15%）。
>
> 任务清单与勾选在 [`PROGRESS.md`](PROGRESS.md)。每段 30–40 分钟。

## 0. 起点与目标

| 项 | 事实 |
|---|---|
| 引擎 | Unity `6000.5.4f1`，URP `17.5.0` |
| 你的能力 | Unity 工程**熟练**，渲染/Shader**零基础**，愿意做数学推导 |
| 时间 | 每天 1–4 段 × 30–40 分钟，约 **7 小时/周** |
| 目标 | **B+A**：把 ShaderProject 做成像样的渲染器；副产品是作品集与面试考点 |
| 预计总量 | 阶段 0–5 约 **300 小时 ≈ 40 周**（按 7.5 小时/周） |

**Unity 基础内容全部砍掉**——不讲 Inspector、不讲 C#、不讲怎么建材质。

---

## 阶段 0 · 数学直觉（1 周 · 5 个任务）

> 只求看得懂几何含义，不求推导。每个任务都落成一个能看见的效果。

### 资源

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| 3Blue1Brown《线性代数的本质》 | **吃透** | 中文配音版：[B 站 BV1ys411472E](https://www.bilibili.com/video/BV1ys411472E)。看第 1–4、7–8 集即可 |
| 3Blue1Brown《微积分的本质》 | **扫读** | [B 站 BV1qW411N7FU](https://www.bilibili.com/video/BV1qW411N7FU)。只求「导数是变化率、积分是累加」 |
| Freya Holmér — *The Math of Computer Graphics* | **吃透** | [YouTube](https://www.youtube.com/watch?v=MOYiVLEnhrw)（B 站搜「Freya Holmér 图形学数学」有搬运）。点乘/叉乘/矩阵在 shader 里的实际用途 |
| 《3D 数学基础：图形与游戏开发》 | **工具书** | 原名 *3D Math Primer for Graphics and Game Development*。**注意**：官方英文第 2 版网页版免费挂载在 [gamemath.com](https://gamemath.com/)，可直接在线读，不必买。只看第 4–8 章 |
| [ShaderToy](https://www.shadertoy.com/) | 练习场 | 在线 GLSL 片段着色器，改参数立刻看到结果，反馈最快 |

### 产物

`Math_Visualize.shader`：把 `dot(N,L)` 画成灰度、把 TBN 三轴染成红绿蓝、手写一次旋转矩阵。
判据见 `PROGRESS.md` 的 T0.1–T0.5。

---

## 阶段 1 · 光栅化与 Shader 基础（3 周 · 7 个任务）

> **整条路线性价比最高的一段。** 光照公式行必须你自己写。

### 资源

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| **GAMES101 现代计算机图形学入门**（闫令琪） | **主线 · 吃透** | 课程主页 [games-cn.org/intro-graphics](https://games-cn.org/intro-graphics/)，B 站有官方全集。**只精看这几讲**：光栅化、光栅化中的抗锯齿、着色模型、纹理映射、几何。**作业必做** |
| LearnOpenGL（中文版） | **吃透** | [learnopengl-cn.github.io](https://learnopengl-cn.github.io/) / [英文原版](https://learnopengl.com/)。只看「入门 → 光照」这一段（第 1–5 章） |
| 《Unity Shader 入门精要》冯乐乐 | **吃透（前半）** | [人民邮电出版社页面](https://www.ptpress.com.cn/shopping/buy?bookId=f0f004f8-1386-44bb-8c22-92c44894de4a) · [出版介绍](https://www.ptpress.com.cn/publishing/book/f0f004f8-1386-44bb-8c22-92c44894de4a)。**只看第 1–8 章**，第 9 章之后偏技巧，全部跳过 |
| Unity URP 自定义 Shader 官方文档 | **吃透** | [Writing custom shaders in URP](https://docs.unity3d.com/6000.5/Documentation/Manual/urp/writing-custom-shaders-urp.html)。URP 下的正确写法、SRP Batcher 的约束 |
| Unity URP Renderer Features 官方文档 | **工具书** | [Renderer features](https://docs.unity3d.com/6000.5/Documentation/Manual/urp/renderer-features/renderer-features-landing.html)。阶段 3/4 才用得上 |
| ShaderToy 入门向作品 | 练习场 | 抄改别人的 raymarching 作品，理解「片元着色器能干嘛」 |

### 为什么 GAMES101 是主线

它是唯一把「光栅化到底在算什么」讲到你能自己写出来的免费课程，而且中文。**但不要全看**——
几何、曲线曲面、动画模拟那几讲跟你的主线无关，跳过。

### 产物（T1.1–T1.7）

手写棋盘格 → **手写 Lambert** → **手写 Blinn-Phong 高光** → **手写法线贴图 TBN** →
C# 写一个三角形填充器 → 加 Z-Buffer 让它正确遮挡。

---

## 阶段 2 · PBR（3 周 · 4 个任务，**全吃透**）

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| **Real-Time Rendering 4th**（RTR4）第 9 章 | **吃透** | 官网资源库 [realtimerendering.com](https://www.realtimerendering.com/)。中文版《实时渲染（第 4 版）》，清华大学出版社，[图书详情页](http://www.tup.com.cn/bookscenter/book_08077601.html) · [文轩购买](https://item.winxuan.com/1204313880) · [天珑（ISBN 9787302661276）](https://www.tenlong.com.tw/products/9787302661276)。**只精读第 9 章**，其余按需查 |
| RTR4 社区中文翻译 | **扫读** | [Real-Time-Rendering-4th-CN](https://github.com/Morakito/Real-Time-Rendering-4th-CN)（GitHub，含 PDF release）。中文对照用，术语以纸质版为准 |
| **Google Filament — 材质系统文档** | **吃透（口径）** | [google.github.io/filament/Materials.html](https://google.github.io/filament/Materials.html)。工业级 PBR 实现口径，比教材贴工程 |
| Sébastien Lagarde — PBR 推导 | **吃透（推导）** | [Frostbite 的 PBR 系列](https://seblagarde.wordpress.com/)。看完能解释「公式为什么长这样」 |
| **Physically Based Rendering (PBRT) 4th** | **工具书** | [pbr-book.org](https://pbr-book.org/)（官网**在线免费**）。第 4 版起可免费在线读。查 BRDF/采样/蒙特卡洛的定义 |
| Disney BRDF Explorer | 工具 | [github.com/wdas/brdf](https://github.com/wdas/brdf)。直观对比 GGX / Phong / Beckmann |

### 产物（T2.1–T2.4）

**手写 Cook-Torrance**：`D_GGX` + `Smith G` + `Schlick F` 三项全部自己写。
再做 keyword 切换的调试可视化（分别显示 D / G / F / NdotV）。

---

## 阶段 3 · 阴影与全局光照（3 周 · 4 个任务）

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| **GAMES202 高质量实时渲染**（闫令琪） | **主线 · 吃透** | 课程主页 [games-cn.org/games202](https://games-cn.org/games202/)。**重点**：实时阴影、实时 GI、降噪。同样**不做全部作业**，挑阴影与降噪两讲 |
| RTR4 第 7 章（阴影）、第 11 章（GI） | 工具书 | 同上官网/中文版 |
| **Ray Tracing Gems I / II** | **扫读** | [realtimerendering.com/raytracinggems](https://www.realtimerendering.com/raytracinggems/)。**免费 PDF**，降噪与采样实践，读起来很快 |
| Sebastian Lague — 阴影/球谐光照系列 | **扫读** | [YouTube 频道](https://www.youtube.com/c/SebastianLague)。动手向，直观 |
| Acerola — 图形学系列 | **扫读** | [YouTube 频道](https://www.youtube.com/c/Acerola_t)。每集讲一个具体问题（如为什么阴影会有锯齿） |

### 产物（T3.1–T3.4）

**手写 Shadow Map**（不用 URP 自带）→ CSM 级联 → SSAO 做成 Renderer Feature → SSR + 降噪。

---

## 阶段 4 · 渲染管线工程（3 周 · 3 个任务）

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| **URP 源码** | **吃透（读源码）** | [Unity-Technologies/Graphics](https://github.com/Unity-Technologies/Graphics)（GitHub）。本地也有一份：`Library/PackageCache/com.unity.render-pipelines.universal@*/`。**这一步躲不掉** |
| URP 官方文档（自定义渲染） | 工具书 | [Customizing URP](https://docs.unity.com/en-us/engine/6000.6/manual/render-pipelines/universal-render-pipeline/customizing-urp) |
| RTR4 第 17–20 章 | 工具书 | Pipeline / Deferred / Image Effects / NPR |
| **Advances in Real-Time Rendering**（SIGGRAPH 年度课程） | **扫读** | [advances.realtimerendering.com](https://advances.realtimerendering.com/)。**免费**，每年前沿且工程化 |
| GDC Vault 渲染专题 | 扫读 | [gdcvault.com](https://www.gdcvault.com/)（部分免费） |
| GPUOpen / NVIDIA 技术博客 | 工具书 | [gpuopen.com](https://gpuopen.com/) |

### 产物（T4.1–T4.3）

描边 Renderer Feature → 手写 Deferred G-Buffer + 光照 pass → 后处理链 + **性能基线表**。
判据：看到 Profiler 里某个 pass 变贵，能定位到自己的哪个 Feature；没有数据的优化都是猜测。

---

## 阶段 5 · 光线追踪（3 周 · 5 个任务，可与阶段 2–3 并行）

| 资源 | 标签 | 说明与链接 |
|---|---|---|
| **Ray Tracing in One Weekend**（三册） | **主线 · 吃透** | [raytracing.github.io](https://raytracing.github.io/)（官网**在线免费**，三册：《In One Weekend》《The Next Week》《The Rest of Your Life》）。最好的入门，`The Rest of Your Life` 专门讲重要性采样 |
| **PBRT 4th** 第 2 章（蒙特卡洛）、第 8 章（采样） | **吃透** | [pbr-book.org](https://pbr-book.org/)（在线免费）。采样理论与积分器的权威 |
| Veach 1997 博士论文（MIS 源头） | 工具书 | [graphics.stanford.edu](https://graphics.stanford.edu/papers/veach_thesis/)。读第 9 章多重重要性采样 |
| GAMES101 的光追部分 | 吃透 | 同上，Whitted 光线追踪 + 路径追踪几讲 |
| 闫令琪 GAMES202 的降噪部分 | 吃透 | 同上 |

### 产物（T5.1–T5.5）

CPU 路径追踪 → 递归反弹 → **搬进 Compute Shader 做渐进式渲染** → 降噪 → 与光栅化结果对账。
判据：能解释为什么噪点收敛是 1/√N，以及 MIS 解决了什么问题。

---

## 阶段 6+ · 长期延后（**当前不做**）

以下内容现在碰会拖垮主线，触发条件是阶段 0–5 走完，或出现明确求职指向：

| 资源 | 标签 | 链接 |
|---|---|---|
| **GAMES104 现代游戏引擎**（王希） | 分阶段吃透 | [games104.boomingtech.com](https://games104.boomingtech.com/)（中文最好的引擎课，免费） |
| 《游戏引擎架构》Jason Gregory | 工具书 | 第 11 章讲渲染在引擎中的位置 |
| **GPU Gems 1–3** | 扫读 | [NVIDIA 免费在线](https://developer.nvidia.com/gpugems/gpugems3/contributors) |
| 《Interactive Computer Graphics》(Angel) | 工具书 | [官网](https://www.cs.unm.edu/~angel/BOOK/INTERACTIVE_COMPUTER_GRAPHICS/)。**买前核对官网当前版次**，教材换代很快 |
| 《Computer Graphics: Principles and Practice》 | 工具书 | 经典大部头，按需查 |
| Real-Time Shadows（SIGGRAPH 课程） | 扫读 | [sites.cs.ucsb.edu/~lingqi](https://sites.cs.ucsb.edu/~lingqi/)（闫令琪讲课资料） |

---

## 三条最容易走错的路

1. **只看课不写代码。** GAMES101 的作业一定要做；光栅化器自己写一遍，胜过看十遍视频。
2. **过早追高级特效。** SSR、体积雾很酷，但 BRDF 没搞懂就写，只会得到「能跑但不对」的结果。
3. **不读源码。** 阶段 4 起必须读 URP 源码，shader 只是冰山一角，管线怎么调度资源才是大头。

---

## 实用提示

- **免费优先**：PBRT 4th、Ray Tracing in One Weekend、Ray Tracing Gems 全部官网免费在线，先读这些。
- **教材版次**：Angel 的 *Interactive Computer Graphics*、RTR 系列都有多版，**买前核对出版社官网当前版次**，别按记忆下单。
- **视频不要全看**：标注「扫读」的直接 1.5–2 倍速过一遍，不写代码不做笔记。你只有 7 小时/周，
  把时间留给「吃透」档。

---

## 仓库内相关文件

| 文件 | 作用 |
|---|---|
| [`PROGRESS.md`](PROGRESS.md) | 进度清单（勾选）+ 机器可读状态块（AI 入口） |
| [`AI-HANDOFF.md`](AI-HANDOFF.md) | AI 教法规约：时间模型、理论对话法、代码分工、多机协作 |
| [`notes/`](notes/) | 你的推导与小结（阶段产物） |
| [`shots/`](shots/) | 每个阶段的验证截图（作品集素材） |
| `../.unity-mcp/UNITY-MCP.md` | MCP 通道说明、协议坑、自检命令 |
| `../.unity-mcp/unity-mcp.ps1` | 脚本桥：建 shader / 读控制台 / 截图 |
