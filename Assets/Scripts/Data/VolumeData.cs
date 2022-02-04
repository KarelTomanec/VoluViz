using System;
using UnityEngine;

[Serializable]
public class VolumeData : ScriptableObject
{
    [SerializeField] 
    public int[] data;

    [SerializeField] 
    public int sizeX;
    
    [SerializeField] 
    public int sizeY;
    
    [SerializeField] 
    public int sizeZ;
    
    [SerializeField] 
    public float scaleX;
    
    [SerializeField] 
    public float scaleY;
    
    [SerializeField] 
    public float scaleZ;

    [SerializeField]
    public string dataName;
    
    private int minDataValue = int.MaxValue;
    
    private int maxDataValue = int.MinValue;
    
    private Texture3D dataTexture = null;
    
    private Texture3D gradientTexture = null;

    private Texture2D transferFunctionTexture = null;

    public Texture3D GetDataTexture()
    {
        if (dataTexture == null)
        {
            dataTexture = CreateDataTexture();
        }
        return dataTexture;
    }
    
    public Texture3D GetGradientTexture()
    {
        if (gradientTexture == null)
        {
            gradientTexture = CreateGradientTexture();
        }
        return gradientTexture;
    }
    
    public int GetMinDataValue()
    {
        if (minDataValue == int.MaxValue)
            ComputeBounds();
        return minDataValue;
    }
    
    public int GetMaxDataValue()
    {
        if (maxDataValue == int.MinValue)
            ComputeBounds();
        return maxDataValue;
    }
    
    private void ComputeBounds()
    {
        minDataValue = int.MaxValue;
        maxDataValue = int.MinValue;
        int size = sizeX * sizeY * sizeZ;
        for (int i = 0; i < size; i++)
        {
            int val = data[i];
            minDataValue = Math.Min(minDataValue, val);
            maxDataValue = Math.Max(maxDataValue, val);
        }
    }

    private Texture3D CreateDataTexture()
    {

        TextureFormat format = SystemInfo.SupportsTextureFormat(TextureFormat.RHalf) ? TextureFormat.RHalf : TextureFormat.RFloat;
        Texture3D texture = new Texture3D(sizeX, sizeY, sizeZ, format, false);
        texture.wrapMode = TextureWrapMode.Clamp;

        int min = GetMinDataValue();
        int max = GetMaxDataValue();

        int range = max - min;


        Color[] colorBuffer = new Color[data.Length];

        for (int x = 0; x < sizeX; x++)
        {
            for (int y = 0; y < sizeY; y++)
            {
                for (int z = 0; z < sizeZ; z++)
                {
                    int index = x + y * sizeX + z * sizeX * sizeY;
                    float value = (float)(data[index] - min) / range;
                    colorBuffer[index] = new Color(value, 0.0f, 0.0f, 0.0f);
                }
            }
        }
        
        texture.SetPixels(colorBuffer);
        texture.Apply();

        return texture;
    }

    private Texture3D CreateGradientTexture()
    {
        TextureFormat format = SystemInfo.SupportsTextureFormat(TextureFormat.RGBAHalf) ? TextureFormat.RGBAHalf : TextureFormat.RGBAFloat;
        
        Texture3D texture = new Texture3D(sizeX, sizeY, sizeZ, format, false);
        
        texture.wrapMode = TextureWrapMode.Clamp;
        
        int min = GetMinDataValue();
        int max = GetMaxDataValue();

        int range = max - min;
        
        Color[] colorBuffer = new Color[data.Length];

        for (int x = 0; x < sizeX; x++)
        {
            for (int y = 0; y < sizeY; y++)
            {
                for (int z = 0; z < sizeZ; z++)
                {
                    int index = x + y * sizeX + z * sizeX * sizeY;
                    
                    int x1 = data[Math.Min(x + 1, sizeX - 1) + y * sizeX + z * (sizeX * sizeY)] - min;
                    int x2 = data[Math.Max(x - 1, 0) + y * sizeX + z * (sizeX * sizeY)] - min;
                    int y1 = data[x + Math.Min(y + 1, sizeY - 1) * sizeX + z * (sizeX * sizeY)] - min;
                    int y2 = data[x + Math.Max(y - 1, 0) * sizeX + z * (sizeX * sizeY)] - min;
                    int z1 = data[x + y * sizeX + Math.Min(z + 1, sizeZ - 1) * (sizeX * sizeY)] - min;
                    int z2 = data[x + y * sizeX + Math.Max(z - 1, 0) * (sizeX * sizeY)] - min;

                    Vector3 grad = new Vector3((x2 - x1) / (float) range, (y2 - y1) / (float) range, (z2 - z1) / (float) range);

                    colorBuffer[index] = new Color(grad.x, grad.y, grad.z, (float)(data[index] - min) / range);
                }
            }
        }
        
        texture.SetPixels(colorBuffer);
        texture.Apply();

        return texture;
        
    }
}
