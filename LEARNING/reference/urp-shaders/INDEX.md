# URP 参考副本清单

来源包：com.unity.render-pipelines.universal@e38be786c41e
刷新时间：2026-10-11 11:47:06

| 文件 | 包内路径 | 说明 |
|---|---|---|
| `BRDF.hlsl.txt` | `ShaderLibrary\BRDF.hlsl` | PBR 核心：D_GGX / V_SmithGGXCorrelated / F_Schlick / DirectBRDF |
| `Lighting.hlsl.txt` | `ShaderLibrary\Lighting.hlsl` | 光照入口：UniversalFragmentPBR / Lambert / BlinnPhong，含 GI 与阴影混合 |
| `Shadows.hlsl.txt` | `ShaderLibrary\Shadows.hlsl` | 阴影：主光与附加光采样、级联选择、PCF、ShadowCoord 变换 |
| `GlobalIllumination.hlsl.txt` | `ShaderLibrary\GlobalIllumination.hlsl` | GI + 环境光：SH 求值、GlossyEnvironment、SampleSH |
| `RealtimeLights.hlsl.txt` | `ShaderLibrary\RealtimeLights.hlsl` | 光源数据结构：Light / AdditionalLightData / GetMainLight |
| `Core.hlsl.txt` | `ShaderLibrary\Core.hlsl` | URP 通用工具箱（内含大量 include，是查函数的地方） |
| `Unlit.hlsl.txt` | `ShaderLibrary\Unlit.hlsl` | 最简顶点/片元流程，适合对照自己写的第一个 shader |
| `LitForwardPass.hlsl.txt` | `Shaders\LitForwardPass.hlsl` | URP Lit 的前向 Pass：Varyings 结构、逐片元光照调用 |
| `LitInput.hlsl.txt` | `Shaders\LitInput.hlsl` | Lit 的属性与纹理声明、关键词、SRP Batcher 的 CBUFFER 写法 |
| `LitMetaPass.hlsl.txt` | `Shaders\LitMetaPass.hlsl` | Meta Pass（烘焙用），理解光照贴图为何需要额外 Pass |
| `ShadowCasterPass.hlsl.txt` | `Editor\ShaderGraph\Includes\ShadowCasterPass.hlsl` | 投射阴影的 Pass：为什么需要一个只写深度的 Pass |
