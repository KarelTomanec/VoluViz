using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class VolumeObject : MonoBehaviour
{
    [HideInInspector]
    public VolumeData data;
    
    [HideInInspector]
    public MeshRenderer meshRenderer;

    private RenderMode renderMode = RenderMode.MAXIMUM_INTENSITY_PROJECTION;

    public CustomGradient transferFunction1D;

    public GameObject focusCenter;

    [Range(0.0f, 1.0f)]
    public float minValue = 0.0f;

    [Range(0.0f, 1.0f)]
    public float maxValue = 1.0f;

    [Range(0.0f, 1.0f)]
    public float focusValue = 0.5f;
    
    [Range(0.0f, 1.0f)]
    public float focusRadius = 0.2f;
    
    public bool focusBorder = false;

    public RenderMode GetRenderMode()
    {
        return renderMode;
    }
    public void SetRenderMode(RenderMode mode)
    {
        if (mode != renderMode)
        {
            renderMode = mode;
            SetShaderRenderModeFlags(mode);
        }
    }

    private void Update()
    {
        if (focusCenter != null)
        {
            meshRenderer.sharedMaterial.SetVector("_FocusCenter", focusCenter.transform.position);
        }
        meshRenderer.sharedMaterial.SetFloat("_FocusRadius", focusRadius);
        meshRenderer.sharedMaterial.SetFloat("_MinVal", minValue);
        meshRenderer.sharedMaterial.SetFloat("_MaxVal", maxValue);
        meshRenderer.sharedMaterial.SetFloat("_FocusVal", focusValue);
        if (focusBorder)
        {
            meshRenderer.sharedMaterial.SetInt("_FocusBorder", 1);
        }
        else
        {
            meshRenderer.sharedMaterial.SetInt("_FocusBorder", 0);
        }
    }

    private void SetShaderRenderModeFlags(RenderMode mode)
    {
        meshRenderer.sharedMaterial.DisableKeyword("MODE_DVR");
        meshRenderer.sharedMaterial.DisableKeyword("MODE_MIP");
        meshRenderer.sharedMaterial.DisableKeyword("MODE_SURF");
        meshRenderer.sharedMaterial.DisableKeyword("MODE_CBI");
        meshRenderer.sharedMaterial.DisableKeyword("MODE_DBI");
        meshRenderer.sharedMaterial.DisableKeyword("MODE_VDBI");
        
        switch (mode)
        {
            case RenderMode.DIRECT_VOLUME_RENDERING:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_DVR");
                break;
            }
            case RenderMode.MAXIMUM_INTENSITY_PROJECTION:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_MIP");
                break;
            }
            case RenderMode.ISOSURFACE:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_SURF");
                break;
            }
            case RenderMode.CURVATRE_BASED_IMPORTANCE:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_CBI");
                break;
            }
            case RenderMode.DISTANCE_BASED_IMPORTANCE:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_DBI");
                break;
            }
            case RenderMode.VIEW_DISTANCE_BASED_IMPORTANCE:
            {
                meshRenderer.sharedMaterial.EnableKeyword("MODE_VDBI");
                break;
            }
        }
    }
}

[CustomEditor(typeof(VolumeObject))]
[CanEditMultipleObjects]
public class VolumeObjectEditor : Editor 
{
    public override void OnInspectorGUI()
    {
        VolumeObject vo = (VolumeObject)target;
            
        DrawDefaultInspector ();

        RenderMode oldRenderMode = vo.GetRenderMode();
        RenderMode newRenderMode = (RenderMode)EditorGUILayout.EnumPopup("Render mode", oldRenderMode);
        if (newRenderMode != oldRenderMode)
        {
            vo.SetRenderMode(newRenderMode);
        }

        if (GUILayout.Button("Apply transfer function changes"))
        {
            vo.meshRenderer.sharedMaterial.SetTexture("_TransferFunctionTex", vo.transferFunction1D.GetTexture(512));
        }
        
        
    }
}
