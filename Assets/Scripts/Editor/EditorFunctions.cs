using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

public class EditorFunctions
{
    [MenuItem("Volume Rendering/Load Image Sequence")]
    static void ShowSequenceImporter()
    {
        string dir = EditorUtility.OpenFolderPanel("Select folder", "", "");
        if (Directory.Exists(dir))
        {
            Importer importer = new Importer(dir);
            VolumeData dataset = importer.Import();
            if (dataset != null)
            {
                VolumeObjectCreator.CreateObject(dataset);
            }
        }
        else
        {
            Debug.LogError("Directory does not exist: " + dir);
        }
    }
}
