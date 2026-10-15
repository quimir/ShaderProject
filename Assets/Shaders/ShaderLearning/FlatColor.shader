Shader "ShaderLearning/FlatColor"
{
    Properties
    {
        // T0.2 先不引入属性：颜色仍然算出来直接输出，
        // 这样「画面变化」的原因只有一个——光照方向在变。
        // 也刻意不加环境光项：背光侧就该是全黑——
        // 否则「负数写进颜色通道被截断成 0」这条结论会被偏置盖住，看不见。
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
                // T0.2 已完成（2026-10-12 收尾，四条判据全部亲手验证过，详见
                // LEARNING/notes/shader-math.md 的「T0.2 已验证」一节）：
                //   · dot(N, L) = +1 正对光源，0 是明暗交界线（球面上的大圆），-1 完全背光
                //   · 不做 saturate：背光侧的负数写进颜色通道被截断成 0，画面纯黑
                //   · 加 saturate：与上一条的截图完全一样（两边都是 0），但值域当场干净
                //   · abs(dot) 没有恢复任何信息，只是在交界线处留下一道缝
                // 收尾截图：LEARNING/shots/T0.2-04-saturate-final.png
                // ═══════════════════════════════════════════════════════════

                half ndotl = saturate(dot(N, L));   // ← 纪律：就地 saturate。下面当占位用，T0.3 写完就替换

                // ═══════════════════════════════════════════════════════════
                // T0.3 —— TODO(YG)：伪造一组切线空间的轴，把 T / B / N 染成 红 / 绿 / 蓝
                //
                // 胶水（我已经写好，不用动）：
                //   half3 up = half3(0, 1, 0);   // 一条固定的世界参考轴，只用来和 N 叉出切线
                //
                // 你要写的三行：
                //   1) half3 T = ____;      // 用 cross 造一条垂直于 N 的切线
                //                           //   想清楚：cross(N, up) 与 cross(up, N) 差在哪？哪个才像"切线"？
                //   2) half3 B = ____;      // 第三条轴由已知两条轴得到（还是 cross，自己挑顺序）
                //   3) half3 color = ____;  // T→红、B→绿、N→蓝（这个映射是约定，照抄）
                //
                // 两个坑，自己撞，撞完再说：
                //   · 轴的分量可能是负的，而颜色通道不收负数 —— 你打算怎么处理？
                //   · 球体两极 N 与 up 平行，cross 出来是零向量 —— 对它 normalize 会发生什么？
                //     先猜，再看画面和 Console。
                // ═══════════════════════════════════════════════════════════

                half3 up = half3(0, 1, 0);

                half3 color = half3(ndotl, ndotl, ndotl);   // ← 占位：T0.2 的灰度。你写完上面三行就换掉它

                return half4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
