#ifndef WINDTREELEAVESINPUT
#define WINDTREELEAVESINPUT   
    
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

	//#if HEIGHT_FOG | _ENABLE_BILINEAR_FOG | ATMOSPHERIC_FOG_DAY | ATMOSPHERIC_FOG_NIGHT
	//#include "Packages/com.pwrd.time-of-day/Resources/Shader/Include/FogCore.hlsl"
	//#endif

	#define UNITY_PI            3.14159265359f

	CBUFFER_START(UnityPerMaterial)
    half _VI;
    half4 _Tint;
	half4 _BaseColor;
    half4 _LerpColor;
    half _TreeLerpTop;
    half _TreeLerpRoot;
    half _Cutoff;
    // wind
	half _Magnitude;
	half _Frequency;
	half _WindSineIntensity;
    half _WindTexScale;
    half _WindTexIntensity;
    half _WindTexMoveSpeed;
    half4 _WindDirection;
	half _ModelScaleCorrection;

    // half _AoIntensity;
    half _AORange;
    half _SubSurfaceGain;
    half _Debug;
    float _CustomBloomIntensity;
    float _CustomBloomAlphaOffset;

    // 增加局部控制
	half _LocalShadowDepthBias;

    // float _RootDis;
    // float4 _RootCenter;
    half4 _BaseMap_ST;
    float _HardRimDistanceIntensity;
    float _HardRimWidth;
    float _LodMask;
    half _TreeLerpIntensity;
    half4 _HardRimTint;
    half _CutIntensity;
    half _SubSurfaceScale;
    half4 _DarkColor;
    half _LightIntensity;
    // half _brightness;
    // half _brightnessDarkness;
    // half _ToonCutSharpness;
    half _ToonCutPos;
    half _SHIntensity;
    half _SHDarkPart;
    half4 _AOTint;
    half _saturate;
    // dither
    half _DitherAmountMax;
    half _DitherAmountMin;
    half _FaceLightGrayIntensity;
    half _FaceLightGrayScale;
    // half _FaceLightGrayScale;
    half4 _brightnessTint;
	CBUFFER_END

    TEXTURE2D(_WindTex);
    SAMPLER(sampler_WindTex);
    TEXTURE2D(_CameraDepthTexture);
    SAMPLER(sampler_CameraDepthTexture);

    #include "WindOfFoliage.hlsl"

    struct appdata
    {
        float4 positionOS           : POSITION;
        float3 normalOS             : NORMAL;
        float3 tangentOS            : TANGENT;
        half4 color                 : COLOR;
        float2 uv                   : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2f
    {
        float4 positionHCS			: SV_POSITION;
        float2 uv                   : TEXCOORD0;
        float3 positionWS	    	: TEXCOORD1;
        float3 normalWS	            : TEXCOORD2;
        half treeParam              : TEXCOORD3;
        half4 ambient               : TEXCOORD4;       
        float3 baseNormal           : TEXCOORD5;        // 目前是把模型平滑前的法线存进了切线中
        //HEIGHT_FOG_COORDS(7)
		half  fogCoord		        : TEXCOORD6;
        #if _NeedScreenPos
            half2 screenUV          : TEXCOORD7;
        #endif
        #if _DEBUGMODE
            half debugWind          : TEXCOORD8;
            half4 VertexColor       : TEXCOORD9;
        #endif
        UNITY_VERTEX_INPUT_INSTANCE_ID
		UNITY_VERTEX_OUTPUT_STEREO
    };

//* wanghaoyu 用到的函数
    void Unity_Dither(float In, float2 ScreenPosition, out float Out)
    {
        float2 SCREEN_PARAM = float2(1, 1);
        float2 uv = ScreenPosition.xy * SCREEN_PARAM;
        float DITHER_THRESHOLDS[16] = {
            1.0 / 17.0, 9.0 / 17.0, 3.0 / 17.0, 11.0 / 17.0,
            13.0 / 17.0, 5.0 / 17.0, 15.0 / 17.0, 7.0 / 17.0,
            4.0 / 17.0, 12.0 / 17.0, 2.0 / 17.0, 10.0 / 17.0,
            16.0 / 17.0, 8.0 / 17.0, 14.0 / 17.0, 6.0 / 17.0
        };
        uint index = (uint(uv.x) % 4) * 4 + uint(uv.y) % 4;
        Out = In - DITHER_THRESHOLDS[index];
    }

#endif
