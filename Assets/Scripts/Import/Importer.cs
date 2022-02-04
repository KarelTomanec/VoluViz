using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class Importer
{
    private string path;

    private string[] imageType = {"*.png"};

    public Importer(string path)
    {
        this.path = path;
    }
    
    public VolumeData Import()
    {
        if (!Directory.Exists(path))
        {
            throw new NullReferenceException("No directory found: " + path);
        }

        List<string> imagePaths = GetImagePaths();

        if (!CheckImageSize(imagePaths))
        {
            throw new IndexOutOfRangeException("Image sequence has non-uniform dimensions");
        }
        
        

        Vector3Int dimensions = GetVolumeSize(imagePaths);
        int[] data = FillSequentialData(dimensions, imagePaths);
        VolumeData dataset = FillVolumeDataset(data, dimensions);

        return dataset;
    }
    
    private List<string> GetImagePaths()
    {
        var imagePaths = new List<string>();

        foreach (var type in imageType)
        {
            imagePaths.AddRange(Directory.GetFiles(path, type));
        }

        imagePaths.Sort();

        return imagePaths;
    }
    
    private bool CheckImageSize(List<string> imagePaths)
    {
        
        bool hasUniformDimension = true;

        Vector2Int previous, current;
        previous = GetImageSize(imagePaths[0]);

        foreach (var path in imagePaths)
        {
            current = GetImageSize(path);

            if (current.x != previous.x || current.y != previous.y)
            {
                hasUniformDimension = false;
                break;
            }

            previous = current;
        }

        return hasUniformDimension;
    }
    
    private Vector2Int GetImageSize(string path)
    {
        byte[] bytes = File.ReadAllBytes(path);

        Texture2D texture = new Texture2D(1, 1);
        texture.LoadImage(bytes);

        Vector2Int dimensions = new Vector2Int()
        {
            x = texture.width,
            y = texture.height
        };

        return dimensions;
    }
    
    private Vector3Int GetVolumeSize(List<string> paths)
    {
        Vector2Int imageSize = GetImageSize(paths[0]);
        
        return new Vector3Int(imageSize.x, imageSize.y, paths.Count);
    }
    
    private int[] FillSequentialData(Vector3Int dimensions, List<string> paths)
    {
        var data = new List<int>(dimensions.x * dimensions.y * dimensions.z);
        var texture = new Texture2D(1, 1);

        foreach (var path in paths)
        {
            byte[] bytes = File.ReadAllBytes(path);
            texture.LoadImage(bytes);

            Color[] pixels = texture.GetPixels();
            int[] imageData = ConvertColorsToDensities(pixels);

            data.AddRange(imageData);
        }

        return data.ToArray();
    }
    
    private VolumeData FillVolumeDataset(int[] data, Vector3Int dimensions)
    {
        string name = Path.GetFileName(path);

        VolumeData dataset = new VolumeData()
        {
            name = name,
            dataName = name,
            data = data,
            sizeX = dimensions.x,
            sizeY = dimensions.y,
            sizeZ = dimensions.z,
            scaleX = 1.0f,
            scaleY = (float)dimensions.y / (float)dimensions.x,
            scaleZ = (float)dimensions.z / (float)dimensions.x
        };

        return dataset;
    }
    
    public static int[] ConvertColorsToDensities (Color[] colors)
    {
        int[] densities = new int[colors.Length];
        for (int i = 0; i < densities.Length; i++)
            densities[i] = Mathf.RoundToInt(colors[i].r * 255f);
        return densities;
    }

}
