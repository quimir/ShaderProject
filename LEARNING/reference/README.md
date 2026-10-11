# URP 官方参考实现（只读副本）

> **为什么放在仓库里**：这些是 Unity 官方写 URP shader 的真实实现，是最权威的「标准答案」。
> 它们本来躺在 `Library/PackageCache/` 里——那个目录不进版本管理、换机器会重建、路径带哈希会变，
> 所以既不稳定也不好搜索。这里复制一份带 `.txt` 后缀的副本，**Unity 不会把它当 shader 编译**，
> 但你和 AI 都能随时搜、随时读、随时 diff。
>
> **版本**：Unity 6000.5.4f1 自带的 URP 17.5.0（`com.unity.render-pipelines.universal@e38be786c41e`）。
> Unity 升级后如需更新，重跑一次复制脚本即可。

## 读这些文件的正确姿势

**不要通读。** 它们是工程实现，不是教材。正确用法是「自己先写一遍，卡住了再来对照」：

1. 自己写 Lambert → 卡住 → 打开 `Lighting.hlsl.txt` 搜 `Lambert`
2. 自己写 GGX → 不确定公式 → 打开 `BRDF.hlsl.txt` 搜 `D_GGX`
3. 自己写 CSM → 不知道级联怎么选 → 打开 `Shadows.hlsl.txt` 搜 `cascade`

对照时重点看三件事：**公式长什么样**、**参数从哪来**、**他们为什么这么组织代码**。

---

## 文件索引（按你路线的阶段）

### 阶段 1 · 光栅化与 Shader 基础

| 文件 | 看什么 | 搜索关键词 |
|---|---|---|
| `Unlit.hlsl.txt` | 最简的顶点/片元流程，14 行就能看懂。**对照你自己手写的第一个 shader** | `Vert`, `Frag` |
| `LitForwardPass.hlsl.txt` | 一个正规 Pass 长什么样：`Varyings` 结构、`VertexPositionInputs`、逐片元调用光照 | `Varyings`, `InitializeInputData` |
| `LitInput.hlsl.txt` | **SRP Batcher 的 `CBUFFER` 写法**、属性声明、纹理与采样器命名规范。自己写时照着抄 | `CBUFFER_START`, `TEXTURE2D` |
| `Core.hlsl.txt` | URP 的工具箱总入口。里面有 `TransformObjectToWorldNormal` 等你现在就需要用的函数 | `TransformObjectToWorldNormal` |

### 阶段 2 · PBR

| 文件 | 看什么 | 搜索关键词 |
|---|---|---|
| **`BRDF.hlsl.txt`** | 阶段 2 的核心。`D_GGX`、`V_SmithGGXCorrelated`、`F_Schlick`、`DirectBRDF`、`EnvironmentBRDF` 全在这 | `D_GGX`, `V_SmithGGX`, `F_Schlick` |
| `Lighting.hlsl.txt` | 这几个 BRDF 项是怎么被组装成一次完整光照的：`UniversalFragmentPBR` 主循环 | `UniversalFragmentPBR`, `InitializeBRDFData` |
| `GlobalIllumination.hlsl.txt` | 环境光 / IBL：球谐求值 `SampleSH`、`GlossyEnvironmentReflection` | `SampleSH`, `GlossyEnvironment` |
| `RealtimeLights.hlsl.txt` | 光源数据从哪来：`Light` 结构、`GetMainLight`、附加光循环 | `GetMainLight`, `GetAdditionalLightsCount` |

### 阶段 3 · 阴影与 GI

| 文件 | 看什么 | 搜索关键词 |
|---|---|---|
| **`Shadows.hlsl.txt`** | 阶段 3 的核心。级联怎么选、`TransformWorldToShadowCoord`、PCF/软阴影采样、`SampleShadowmap` | `cascade`, `SampleShadowmap`, `ShadowCoord` |
| `GlobalIllumination.hlsl.txt` | 间接光的处理方式 | `SAMPLE_GI`, `indirect` |
| `ShadowCasterPass.hlsl.txt` | 投射阴影的 Pass：为什么需要一个「只写深度」的 Pass | `ShadowCaster`, `SV_Target` |
| `LitMetaPass.hlsl.txt` | Meta Pass（烘焙用）：理解光照贴图为什么需要额外一趟 | `MetaPass` |

### 阶段 4 · 渲染管线工程

| 文件 | 看什么 | 搜索关键词 |
|---|---|---|
| `LitForwardPass.hlsl.txt` | 重新读一遍，这次关注 **Pass 的组织方式** 而不是光照 | `#pragma`, `Pass` |
| `Core.hlsl.txt` | 它 include 了什么，说明 URP 的文件分层思路 | 文件顶部 `#include` |

> 阶段 4 真正的主角不是 HLSL 而是 C#：`ScriptableRenderPass` / `RendererFeature`。
> 官方示例在 `Library/PackageCache/com.unity.render-pipelines.universal@*/Samples~/` 里
> （`URPPackageSamples`、`URPRenderGraphSamples`、`RendererShaderUserValueSamples`），
> 也可以在 Package Manager 里点 URP → Samples → Import 导入到工程。

---

## 编辑器自带的调试工具（免费，且比多数插件强）

这三个是 Unity 官方内置的，**不需要装任何东西**，但很多人不知道它们能干什么：

| 工具 | 怎么开 | 学习时用它看什么 |
|---|---|---|
| **Rendering Debugger** | 运行时：`Window ▸ Analysis ▸ Rendering Debugger` | Lighting/Material 分类里能直接看到 **NdotL、基础色、法线、金属度、粗糙度、环境光、间接光**这些中间量。等于把 URP 的 Lit 拆开给你看 |
| **Frame Debugger** | `Window ▸ Analysis ▸ Frame Debugger` | 一帧里到底有几次 Draw Call、每次画的什么、当前渲染目标的绑定与 shader 属性。**写阴影 Pass 时用它看深度图是怎么来的** |
| **Render Graph Viewer** | `Window ▸ Analysis ▸ Render Graph Viewer`（URP 17 起） | 每个 Render Pass 的输入输出资源。阶段 4 自己写 Renderer Feature 时用它验证顺序对不对 |

另外加上你已经有的那个：

| 工具 | 怎么开 | 干什么 |
|---|---|---|
| **Shader 学习检视器** | `Window ▸ Shader Learning ▸ Shader Inspector` | 看**预处理后的代码**（`#include` 展开成什么）、编译器生成的 HLSL、逐 Pass 的 stage 与关键字、指定关键字组合**单独编译**一次并看消息。这是上面三个内置工具都没有的角度 |

---

## 关于第三方插件

**结论：现阶段一个都不装。** 理由不是「插件不好」，而是**你现在缺的是「自己写一遍」，不是放大器**。

具体判断：

| 插件类型 | 例子 | 为什么现在不装 |
|---|---|---|
| 可视化 Shader 编辑器 | [Amplify Shader Editor](https://assetstore.unity.com/packages/tools/visual-scripting/amplify-shader-editor-68570)、Shader Graph | 你是「零基础 + 要能白板手写」，先连节点会绕开你真正要练的那部分。**Shader Graph 其实已经装好了**（URP 的传递依赖，17.5.0），想用随时能用 |
| Shader 参考库 / 导航器 | [URPShaderViewer](https://github.com/Xibanya/URPShaderViewer) | 功能与本目录 `urp-shaders/` 高度重叠，而本地副本可搜索、可版本管理、AI 能直接读，更实用 |
| 美术向检视器 | ShaderGraph Markdown | 面向「调效果的美术」，对「搞懂原理」帮助有限 |

**什么时候再回来看这节**：阶段 2 结束、你能自己写出 Cook-Torrance 之后。
那时候如果觉得手写效率低，再考虑 ASE 之类的工具才有意义——那时你是「用工具加速」，而不是「用工具替代学习」。

---

## 更新方法

Unity 升级 URP 后，重新复制一遍即可（在仓库根目录执行）：

```powershell
# 见下方脚本；它会自动定位带哈希的 PackageCache 路径
pwsh -NoProfile -File LEARNING/reference/refresh-urp-reference.ps1
```
