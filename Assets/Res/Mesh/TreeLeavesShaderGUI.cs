using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class TreeLeavesShaderGUI : ShaderGUI
{
    enum DebugOption
    {
        AO = 0,
        SubSurfacePart = 1,
        DarkPart = 2,
        lightColor = 3,
        LightProbes = 4,
        DebugWind = 5,
        TreeHeight = 6,
        HardRimIntensity = 7,
        VertexColorR = 8,
        VertexColorG = 9,
        VertexColorB = 10,
        VertexColorA = 11

    }

    private DebugOption debugOption;

    public bool isFirstTimeApply = true;

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material targetMat = materialEditor.target as Material;

        // 首次应用
        if (isFirstTimeApply)
        {
            targetMat.SetShaderPassEnabled("ShadowCaster", true);

            isFirstTimeApply = false;
        }

        EditorGUILayout.LabelField("Debug");

        bool useDebugMode = targetMat.IsKeywordEnabled("_DEBUGMODE");

        EditorGUI.BeginChangeCheck();

        useDebugMode = EditorGUILayout.Toggle("开启测试模式", useDebugMode);

        if(EditorGUI.EndChangeCheck())
        {
            if(useDebugMode)
            {
                targetMat.EnableKeyword("_DEBUGMODE");
            }
            else
            {
                targetMat.DisableKeyword("_DEBUGMODE");
            }
        }

        debugOption = (DebugOption)targetMat.GetInt("_Debug");

        EditorGUI.BeginChangeCheck();

        debugOption = (DebugOption)EditorGUILayout.EnumPopup("Debug选项：", debugOption);

        if(EditorGUI.EndChangeCheck())
        {
            targetMat.SetInt("_Debug", (int)debugOption);
        }

        base.OnGUI(materialEditor, properties);
    }
}
