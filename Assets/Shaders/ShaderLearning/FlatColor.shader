Shader "ShaderLearning/FlatColor"
{
    Properties
    {
        // T0.2 先不引入属性：颜色仍然算出来直接输出，
        // 这样「画面变化」的原因只有一个——光照方向在变。
        // 环境光那一项是刻意加的常量偏置，没有它背光侧会全黑，看不出结构。
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 lightDirWS  : TEXCOORD1;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);

                // 法线必须转到世界空间：光源方向是世界空间的量，
                // 两个向量只有在同一个坐标系里做点乘才有意义。
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

                // URP 的主光方向是全局量。这里在顶点阶段取一次即可，
                // 因为它对一个 Pass 内所有像素都相同（平行光）。
                OUT.lightDirWS = _MainLightPosition.xyz;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half3 N = normalize(IN.normalWS);
                half3 L = normalize(IN.lightDirWS);

                // ═══════════════════════════════════════════════════════════
                // TODO(YG): 用点乘算出一个标量，再把它当灰度输出。
                //
                // 步骤：
                //   1. 先写 half ndotl = dot(N, L);  —— 判断它是什么、取值范围是多少
                //   2. 先把 ndotl 原样写到三个通道，看背光侧会出现什么
                //   3. 再用 saturate(ndotl) 包一层，对比两张图的差别
                //
                // 提示：saturate(x) 帮你把值限制在 0 到 1 之间。
                //       第 2 步故意不做限制，就是为了让你亲眼看到「没限制会怎样」。
                // ═══════════════════════════════════════════════════════════

                half ndotl = dot(N, L);          // ← 先原样用，看看会出什么
                // half ndotl = saturate(dot(N, L));   // ← 第 3 步把上面一行换成这一行

                half3 color = half3(ndotl, ndotl, ndotl);   // 灰度：三个通道同一个值

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
