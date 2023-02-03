#ifndef WINDTREELEAVESPASS
#define WINDTREELEAVESPASS

/// 储存树叶的渲染PASS
#include "WindTreeLeavesInput.hlsl"
//* shadowPass里好像某个include会采样这张图造成重复定义
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

v2f vert(appdata v)
{
    v2f o;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    o.uv = v.uv;
    o.normalWS = TransformObjectToWorldNormal(v.normalOS);
    o.baseNormal = TransformObjectToWorldNormal(v.tangentOS);

    float3 v_posWorld;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
    v_posWorld = vertexInput.positionWS;

    //* wanghaoyu 计算垂直颜色变化,这里改成local的变化,场景里的树难免会有高有低
    half height = v.positionOS.y;// - objectPivot.y;
    o.treeParam = saturate((height - _TreeLerpRoot) / (_TreeLerpTop - _TreeLerpRoot) * _TreeLerpIntensity);

    float2 worldRotUV;
    half debug = 1;
    float windSpeed;
    half windSineOffset = 0;
    //* wanghaoyu
    #ifdef _VERTEXANIMTION
        // 增加风的影响
        v_posWorld.xyz = ApplyWind(v.color.r, v_posWorld.xyz, windSineOffset, worldRotUV, windSpeed, debug);
    #endif
    #if _DEBUGMODE
        o.debugWind = debug;
        o.VertexColor = v.color;
    #endif
    o.ambient.rgb = 0;
    #ifdef _LIGHTPROBE
        // 计算环境光
        o.ambient.rgb = SampleSH(o.normalWS);
    #endif
    // 环境光的A通道存入顶点色的R通道，作为模拟AO，但是对于海贼王项目来说可能不需要。
    o.ambient.a = pow(v.color.r,_VI);
    o.positionWS = v_posWorld;
    o.positionHCS = mul(UNITY_MATRIX_VP, float4(v_posWorld, 1));
    return o;
}

struct LitFragmentOutput
{
    #if _MRTEnable
        half4 color0: SV_Target0;
        half4 color1: SV_Target1;
    #else
        half4 color0: SV_Target0;
    #endif
};

LitFragmentOutput frag(v2f i)
{
    //* wanghaoyu 说是移动端dither不放在前面的话，着色部分也会计算
    half4 baseColor = _Tint;//SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
    baseColor.a = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a;
    half3 viewDir = SafeNormalize(GetCameraPositionWS() - i.positionWS.xyz);
    float clipPart = 1 - abs(dot(i.baseNormal, viewDir));
    // float3 posObj = TransformObjectToWorld(float3(0,0,0)); 整体dither
    float dis = distance(float3(_WorldSpaceCameraPos.x, 0, _WorldSpaceCameraPos.z), float3(i.positionWS.x, 0, i.positionWS.z)/*posObj*/);
    float clipValue = 0;
    Unity_Dither(smoothstep(_DitherAmountMin, _DitherAmountMax, dis), i.positionHCS.xy, clipValue);
    clip(min((baseColor.a * _CutIntensity - clipPart), clipValue)); // min 是为了处理Dither ,前面*强度是为了不做除法

    UNITY_SETUP_INSTANCE_ID(i);
    
    // Lerp Color
    half3 tintColorTop = lerp(half3(1, 1, 1), _BaseColor.rgb, _BaseColor.a);
    half3 tintColorRoot = lerp(half3(1, 1, 1), _LerpColor.rgb, _LerpColor.a);
    half3 tintColor = lerp(tintColorRoot, tintColorTop, i.treeParam);
    half3 baseTexColor = baseColor.rgb * tintColor;
    baseColor.rgb = baseTexColor;

    // 屏蔽逐instancing差异
    /*
    float4 tintColor = UNITY_ACCESS_INSTANCED_PROP(Props, _Color);
    baseColor.rgb *= tintColor;

    float4 fade = UNITY_ACCESS_INSTANCED_PROP(Props, _FadeTime);
    UnityApplyDitherCrossFade(i.positionHCS.xy, fade);
    */

    half4 shadowCoord = TransformWorldToShadowCoord(i.positionWS.xyz);
    Light light = GetMainLight(shadowCoord);
    half shadowAtten = light.shadowAttenuation;
    half3 lightColor = light.color.rgb;
    // 白糖的秘籍
    #ifdef _LIGHTPROBE
        half vertexNdotL = max(0, dot(i.normalWS, _MainLightPosition.xyz));
        vertexNdotL = lerp(vertexNdotL * _SHDarkPart,vertexNdotL,shadowAtten);
        i.ambient.rgb += vertexNdotL * _MainLightColor.rgb;// * _VertexLightIntensity;
    #endif
    
    half ao = saturate(i.ambient.a / _AORange);
    half NoL = dot(normalize(i.normalWS), light.direction);
    half positiveNL = saturate((NoL - _ToonCutPos) /** _ToonCutSharpness*/);   // 项目不需要调整边缘软硬
    half4 f_finalColor = half4(baseColor.rgb, 1);
    half darkPart = positiveNL * shadowAtten;
    half GrayPart = saturate(lerp(1, i.ambient.a, _FaceLightGrayScale));  // 亮部灰阶
    half subSurfaceTerm = 0;
    #ifdef _SUBSURFACE
        half VoL = saturate(-dot(light.direction, viewDir));
        VoL = saturate(VoL * VoL * VoL);    // 让vol变得更线性，这样算透光的时候接近0的时候有更多灰阶
        subSurfaceTerm = saturate(VoL * saturate(NoL - _SubSurfaceScale)) * _SubSurfaceGain * ao * shadowAtten; // *shadowAtten 是为了干掉被建筑挡住的树的ss,下同
    #endif
    GrayPart *= 1 - darkPart;                                           // 只想让这个叠加进 nol 小于0的部分

    f_finalColor.rgb *= lightColor;                                                     // 平行光叠加
    f_finalColor.rgb *= lerp(_DarkColor.rgb, _LightIntensity, min(darkPart + GrayPart * saturate(NoL * 0.5 + 0.5) * _FaceLightGrayIntensity * shadowAtten + subSurfaceTerm, 1)); // darkColor,这里*2是为了提亮暗部的亮叶
    f_finalColor.rgb += baseTexColor * i.ambient.rgb * _SHIntensity;                    // 环境光
    float gray = 0.21 * f_finalColor.x + 0.72 * f_finalColor.y + 0.072 * f_finalColor.z;
    f_finalColor.rgb = lerp(float3(gray, gray, gray), f_finalColor.rgb, _saturate);     // 饱和度
    // f_finalColor.rgb *= lerp(1,_brightnessTint.rgb,min(darkPart + subSurfaceTerm,1));              // 亮部亮度和暗部亮度分开调了
    f_finalColor.rgb *= lerp(_AOTint.rgb, 1, ao);                                           // AO 想让AO更可控一些
    f_finalColor.a = baseColor.a;


    // HardRim
    //* wanghaoyu HardRim好像暂时不打算用了,要调整的话可以试试把深度图往光源的反方向推

    float hardRimMask = 0;
    float hardRim = 0;
    #if defined(_HARDRIM)
        float2 HardRimScreenUV = (i.positionHCS.xy / _ScaledScreenParams  .xy - 0.5) * (1 + _HardRimWidth) + 0.5;
        float depthTex = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, HardRimScreenUV).r;
        hardRim = 1 - depthTex.xxx * max(0, _HardRimDistanceIntensity);
        hardRimMask = 1 - step(i.positionHCS.z * 100, _LodMask);
        float hardRimScale = saturate(hardRimMask * hardRim);
        f_finalColor.rgb = lerp(f_finalColor.rgb, _HardRimTint *  f_finalColor.rgb, hardRimScale);
        // f_finalColor.rgb += f_finalColor.rgb * max(0, hardRim) * hardRimMask * lerp(_HardRimIntensity2,_HardRimIntensity,NoL);
        // lod有具体米数么，如果有可以直接调_HardRimDistanceIntensity调到内个范围，主要这个确定了才好确定距离（现在想用step控制）怎么调整
        // hardrim是多远都有么，lod还没适配hardrim
    #endif

    // // 增加点光源
    // half4 shadowmask = half4(0, 0, 0, 0);
    // #ifdef _ADDITIONAL_LIGHTS
    //     uint pixelLightCount = GetAdditionalLightsCount();
    //     for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    //     {
    //         //* pwrd majiao: 支持Shadowmask //
    //         Light light = GetAdditionalLight(lightIndex, i.positionWS.xyz, shadowmask);
    //         //* pwrd majiao //

    //         // 增加普通的Lambert 光照模型计算点光源
    //         half3 lightColor = light.color * light.distanceAttenuation * light.shadowAttenuation;
    //         f_finalColor.rgb += saturate(dot(normalize(i.normalWS), light.direction)) * lightColor * baseColor.rgb;
    //     }
    // #endif

    //*	//在战斗时 会压暗场景 突出角色
    //f_finalColor.rgb *= _SceneFocusIntensity;
    
    // Debug 用
    #if _DEBUGMODE
        switch(_Debug)
        {
            case 0:
            f_finalColor.rgb = ao;
            break;
            case 1:
            f_finalColor.rgb = subSurfaceTerm;
            break;
            case 2:
            f_finalColor.rgb = darkPart + subSurfaceTerm;
            break;
            case 3:
            f_finalColor.rgb = lightColor;
            break;
            case 4:
            f_finalColor.rgb = i.ambient.rgb * _SHIntensity;
            break;
            case 5:
            f_finalColor.rgb = i.debugWind;
            break;
            case 6:
            f_finalColor.rgb = i.treeParam;
            break;
            case 7:
            f_finalColor.rgb = hardRimMask * hardRim;
            break;
            case 8:
            f_finalColor.rgb = pow(i.VertexColor.rrr,_VI);
            break;
            case 9:
            f_finalColor.rgb = i.VertexColor.ggg;
            break;
            case 10:
            f_finalColor.rgb = i.VertexColor.bbb;
            break;
            case 11:
            f_finalColor.rgb = i.VertexColor.aaa;
            break;
        }
    #endif
    
    LitFragmentOutput output = (LitFragmentOutput)0;
    
    output.color0 = f_finalColor;
    
    #if _MRTEnable
        //tree - bloom
        half expandBloomValue = 0;
        half bloomValue = _CustomBloomIntensity;
        bloomValue *= _SceneBloomIntensity;
        
        output.color1 = float4(expandBloomValue, bloomValue, 0, saturate(f_finalColor.a + _CustomBloomAlphaOffset));
        //output.color1 = float4(0, 0, 0, 0);
    #endif
    return output;
}

half4 fragDepth(v2f i): SV_Target
{
    half4 col = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
    half3 viewDir = SafeNormalize(GetCameraPositionWS() - i.positionWS.xyz);
    float clipPart = 1 - abs(dot(i.baseNormal, viewDir));
    float dis = distance(float3(_WorldSpaceCameraPos.x, 0, _WorldSpaceCameraPos.z), float3(i.positionWS.x, 0, i.positionWS.z)/*posObj*/);
    float clipValue = 0;
    Unity_Dither(smoothstep(_DitherAmountMin, _DitherAmountMax, dis), i.positionHCS.xy, clipValue);
    clip(min((col.a * _CutIntensity - clipPart), clipValue));

    return 0;
}

#endif
