﻿Shader "NeilyodogTreeDemo"
{
    Properties
    {
        _VI("colorInten",float) = 1
        _Tint("Tint",color) = (1,1,1,1)
        [HideInInspector]_MainTex ("", 2D) = "white" {}
        _BaseColor ("Color", Color) = (1,1,1,1)
        _LerpColor ("垂直染色", Color) = (1,1,1,1)
        _TreeLerpTop("树冠染色顶端高度", Range(0,100)) = 20
        _TreeLerpRoot("树冠染色底端高度", Range(0,40)) = 1
        _TreeLerpIntensity("树冠染色强度",range(1,3000)) = 20
		[MainTexture]_BaseMap ("Albedo", 2D) = "white" {}
        _Cutoff("Alpha Cutoff(阴影)", Range(0.0, 1.0)) = 0.5    
        _CutIntensity("立面剔除强度", Range(0, 1)) = 0.95
		_LocalShadowDepthBias("影子偏移值", float) = 0.25

		[Header(NPR)]
        _saturate("饱和度",range(0,1)) = 1
        _LightIntensity("亮部强度",range(1,5)) = 2
        _FaceLightGrayScale("亮部灰阶范围",range(0,7)) = 5
        _FaceLightGrayIntensity("亮部灰阶强度",range(0,7)) = 1
        _DarkColor ("暗部颜色", Color) = (0,0,0,1)
        _ToonCutPos("明暗交界线位置",range(-1,1)) = 0
        _SHDarkPart("阴影中环境光强度",range(0,2)) = 1
        _SHIntensity("LightProbes强度",range(0,10)) = 1

        [Header(AO)]
        _AOTint("AO颜色",color) = (1,1,1,1)
        _AORange("AO范围", Range(0.1,1)) = 1

        [Header(Subsurface)]
        _SubSurfaceGain("透光强度", Range(0,5)) = 1
        [HideInInspector]_SubSurfaceScale("透光范围", Range(-1,1)) = -1

        [HideInInspector][Toggle(_DEBUGMODE)]_DebugMode("Debug Mode", Float) = 0
        [HideInInspector]_Debug("Debug AO", Float) = 1

        [Space(20)]
        [Header(HardRim)]
        [Toggle(_HARDRIM)] _UsingHardRim("使用HardRim",int) = 0
        [HDR]_HardRimTint ("HardRimColor", Color) = (1,1,1,1)
        _LodMask("LodMask",range(0,1)) = 0.5       
        _HardRimDistanceIntensity("HardRim距离颜色变化 ",float) = 2000  
        _HardRimWidth("HardRim宽度",range(0,0.05)) = 0.01

        [Header(Wind)]
		_Magnitude("随风漂移强度", float) = .5
		_Frequency("随风飘动频率", float) = .5
		_WindSineIntensity("风的规律波动强度", Range(0,2)) = 0.5
		_WindDirection("风向 (x,y,z))",Vector) = (1,0,1,0)
		_WindTex("风的波动贴图", 2D) = "black" {}
		_WindTexScale("风的波动图的大小", float) = 1
		_WindTexIntensity("风的波动贴图的强度", Range(0,2)) = 1
		_WindTexMoveSpeed("风的波动贴图的速度", float) = 0.1
		[HideInInspector]_ModelScaleCorrection("ModelScaleCorrection ",Float) = 0.2

        [Space(20)]
        _CustomBloomIntensity("_CustomBloomIntensity", Range(0, 2)) = 1.0
        _CustomBloomAlphaOffset("_CustomBloomAlphaOffset", Range(-1, 1)) = 0

        [Space(20)]
        [Header(Dither)]
        _DitherAmountMax("DitherMax", Range(0, 25)) = 0
        _DitherAmountMin("DitherMin", Range(0, 25)) = 0

    }
    SubShader
    {
        Tags {	"RenderType"="AlphaTest"
                "Queue" = "AlphaTest"
				"PerformanceChecks"="False"
				"RenderPipeline" = "UniversalPipeline"
				"IgnoreProjector" = "True" }

        Pass
        {
			Name "ForwardLitTreeLeaves"
            Tags {"LightMode"="UniversalForward"}
            Cull Off

            HLSLPROGRAM


            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_instancing  

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS

            // #pragma multi_compile _ _ADDITIONAL_LIGHTS
            // #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma shader_feature _ _DEBUGMODE
            
            #define _LIGHTPROBE 1
            #define _SUBSURFACE 1
            #define _VERTEXANIMTION 1
            #pragma shader_feature_local _HARDRIM


            #include "WindTreeLeavesPassNew.hlsl"
            ENDHLSL
        }

        Pass
        {
			Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragDepth
            #pragma target 3.0
            #pragma multi_compile_instancing  
            #define _VERTEXANIMTION 1


			#include "WindTreeLeavesPassNew.hlsl"
            ENDHLSL
        }

		Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0
            // -------------------------------------
            // Material Keywords
			#define _ALPHATEST_ON 1
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertexTreeLeaves
            #pragma fragment ShadowPassFragmentTreeLeaves

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #define _VERTEXANIMTION 1

            #include "WindTreeLeavesInput.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 texcoord     : TEXCOORD0;
            #ifdef _VERTEXANIMTION
                float4 color        : COLOR;
            #endif

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 positionCS   : SV_POSITION;
            #if _TEXTURE_ATLASING_ON
                TEXTURE_ATLASING_COORDS(1)
            #endif

            };

			Varyings ShadowPassVertexTreeLeaves(Attributes input)
			{
				Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                // 扩展影子
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                // 应用影子偏移
                worldPos -= _LightDirection * _LocalShadowDepthBias;
                #ifdef _VERTEXANIMTION
                    // 增加风的影响
                    float2 worldRotUV;
                    half debug = 1;
                    float windSpeed;
                    half windSineOffset = 0;
                    worldPos.xyz = ApplyWind(input.color.r, worldPos.xyz, windSineOffset, worldRotUV, windSpeed, debug);
                #endif
                float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldPos, 1));
                #if UNITY_REVERSED_Z
                    clipPos.z = min(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    clipPos.z = max(clipPos.z, clipPos.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                output.positionCS = clipPos;
				return output;
			}
            half4 ShadowPassFragmentTreeLeaves(Varyings input) : SV_TARGET
            {

                Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }
	CustomEditor "TreeLeavesShaderGUI"
}
