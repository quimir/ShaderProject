Shader "ShaderLearning/FlatColor"
{
    Properties
    {
        // T0.1 故意不给任何可调属性：这一段的重点是「片元输出的是一个数值」，
        // 先不引入材质面板这个变量。属性留到 T0.2 再上。
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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // ═══════════════════════════════════════════════════════════
                // TODO(YG): 返回一个常量颜色。
                //
                // 要求：
                //   1. 先用 half3(0.6, 0.8, 0.0) —— 观察它是什么颜色
                //   2. 然后把三个分量分别改成 0.0 和 1.0，各截一张图，回答：
                //      · 第三个分量恒为 0，为什么画面里完全没有蓝色？
                //      · 把第一个分量改大，画面往哪个方向变？
                //   3. 不要用 IN.uv —— 这一段的重点是「颜色是数值」，
                //      UV 讲的是「片元在表面的位置」，两个概念现在混在一起会互相干扰。
                //
                // 提示：返回值是 half4(r, g, b, a)，a 通道先固定写 1.0。
                // ═══════════════════════════════════════════════════════════

                half3 color = half3(0, 0, 0);   // ← 把这一行换成你要的颜色

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
