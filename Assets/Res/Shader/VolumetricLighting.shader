Shader "Unlit/VolumetricLightingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "black" {}
        [HDR]_Tint("Tint",color) = (1,1,1,1)
        _Intensity("Intensity",range(0,2)) = 1
        _SceneColor("_SceneColor",range(0,1)) = 0.5
        // _SunPos("SunPos",vector) = (1,1,1,1)
        // _depthFix("_depthFix",float) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue"="Transparent" "RenderPipeline" = "UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
            ZWrite off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define MAIN_LIGHT_CALCULATE_SHADOWS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #define STEP_TIME 256
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos:TEXCOORD1;
                float4 screenPos :TEXCOORD2;
            };

            TEXTURE2D_X_FLOAT(_CameraDepthTexture); SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            float _Intensity;
            float _depthFix;
            float4 _Tint;
            float4 _SunPos;
            float _SceneColor;
            v2f vert (appdata v)
            {
                v2f o;
                
                o.vertex = TransformObjectToHClip(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half2 screenPos = i.screenPos.xy / i.screenPos.w;
                //rebuild world position according to depth
                float depth = SAMPLE_TEXTURE2D_X(_CameraDepthTexture,sampler_CameraDepthTexture, screenPos).r;
                depth = Linear01Depth(depth, _ZBufferParams) ;
                float2 positionNDC = screenPos * 2 - 1;
                float3 farPosNDC = float3(positionNDC.xy,1)*_ProjectionParams.z;
                float4 viewPos = mul(unity_CameraInvProjection,farPosNDC.xyzz);
                viewPos.xyz *= depth;
                float4 worldPos = mul(UNITY_MATRIX_I_V,viewPos);
                
                float noise = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, screenPos*3).r;
                float3 startPos = i.worldPos;
                float3 dir = normalize(worldPos - startPos);
                startPos += dir * noise;
                worldPos.xyz += dir * noise;
                float len = length(worldPos - startPos);
                float3 stepLen = dir * len / STEP_TIME;
                half3 color = 0;

                half3 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenPos).rgb;
                
                UNITY_LOOP
                for (int i = 0; i < STEP_TIME; i++)
                {
                    startPos += stepLen;
                    float4 shadowPos = TransformWorldToShadowCoord(startPos);
                    // shadowPos.xz *= _depthFix;
                    float intensity = (1-step(MainLightRealtimeShadow(shadowPos),0.5))*_Intensity;
                    color += saturate(intensity*_MainLightColor.rgb);
                }

                color /= STEP_TIME;
                //color += sceneColor;
                color = lerp(color,color * sceneColor/2,_SceneColor);
                //color = saturate(color);
                return half4(saturate(color.xyz * _Tint.xyz),color.r );
            }
            ENDHLSL
        }
    }
}