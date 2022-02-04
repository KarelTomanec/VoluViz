using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VolumeObjectCreator
{

    public static VolumeObject CreateObject(VolumeData dataset)
    {
        GameObject outerObject = new GameObject("VolumeRenderedObject_" + dataset.dataName);
        VolumeObject volObj = outerObject.AddComponent<VolumeObject>();

        GameObject meshContainer = GameObject.Instantiate((GameObject)Resources.Load("VolumeContainer"));
        meshContainer.transform.parent = outerObject.transform;
        meshContainer.transform.localScale = Vector3.one;
        meshContainer.transform.localPosition = Vector3.zero;
        meshContainer.transform.parent = outerObject.transform;
        outerObject.transform.localRotation = Quaternion.Euler(90.0f, 0.0f, 0.0f);

        MeshRenderer meshRenderer = meshContainer.GetComponent<MeshRenderer>();
        meshRenderer.sharedMaterial = new Material(meshRenderer.sharedMaterial);
        volObj.meshRenderer = meshRenderer;
        volObj.data = dataset;
        
        Debug.Log(dataset.GetDataTexture().ToString());
        meshRenderer.sharedMaterial.SetTexture("_DataTex", dataset.GetDataTexture());
        meshRenderer.sharedMaterial.SetTexture("_GradientTex", dataset.GetGradientTexture());
        meshRenderer.sharedMaterial.EnableKeyword("MODE_MIP");

        if(dataset.scaleX != 0.0f && dataset.scaleY != 0.0f && dataset.scaleZ != 0.0f)
        {
            float maxScale = Mathf.Max(dataset.scaleX, dataset.scaleY, dataset.scaleZ);
            volObj.transform.localScale = new Vector3(dataset.scaleX / maxScale, dataset.scaleY / maxScale, dataset.scaleZ / maxScale);
        }

        return volObj;
    }
}
