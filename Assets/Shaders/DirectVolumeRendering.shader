Shader "Unlit/DirectVolumeRendering"
{
    Properties
    {
        _DataTex("Data texture", 3D) = "" {}
        _GradientTex("Gradient texture", 3D) = "" {}
        _TransferFunctionTex("Transfer Function texture", 2D) = "" {}
        _MinVal("Min val", Range(0.0, 1.0)) = 0.0
        _MaxVal("Max val", Range(0.0, 1.0)) = 1.0
        _FocusVal("Focus value", Range(0.0, 1.0)) = 0.5
        _FocusCenter("Focus Center", Vector) = (0.0, 0.0, 0.0)
        _FocusRadius("Focus Radius", float) = 0.2
        _FocusBorder("Focus Border", int) = 0
        
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType"="Transparent" }

        LOD 100
        Cull Front
        ZTest LEqual
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha
        
        
        Pass 
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #pragma multi_compile MODE_DVR MODE_MIP MODE_SURF MODE_CBI MODE_DBI MODE_VDBI
            
            
            #include "UnityCG.cginc"

            struct VertIn
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct V2F
            {
                
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 vertexLocal: TEXCOORD1;
                float3 normal : NORMAL;
            };

            struct FragOut
            {
                float4 color : SV_TARGET;
                float depth : SV_DEPTH;
            };

            sampler3D _DataTex;
            sampler3D _GradientTex;

            float _MinVal;
            float _MaxVal;
            float _FocusVal;

            float3 getGradient(float3 pos)
            {
                return tex3Dlod(_GradientTex, float4(pos.x, pos.y, pos.z, 0.0f)).rgb;
            }
            
            float getDensity(float3 pos)
            {
                return tex3Dlod(_DataTex, float4(pos.x, pos.y, pos.z, 0.0f)).r;
            }

            float localToDepth(float3 localPos)
            {
                float4 clipPos = UnityObjectToClipPos(float4(localPos, 1.0f));

#if defined(SHADER_API_GLCORE) || defined(SHADER_API_OPENGL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
                return (clipPos.z / clipPos.w) * 0.5 + 0.5;
#else
                return clipPos.z / clipPos.w;
#endif
            }

            FragOut createCurvatureTexture(V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += stepSize * rayDir * NUM_STEPS;

                rayDir = -rayDir;
                
                float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);


                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x >= 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        continue;
                    }
                    
                    float density = getDensity(currPos);
                    
                    if(density > _MinVal && density < _MaxVal)
                    {
                        float3 normal = normalize(getGradient(currPos));
                        color = float4(normal, 1.0f);
                        break;
                    }
                }

                // Write fragment output
                FragOut output;
                output.color = color;
                output.depth = 0;
                return output;
            }

            V2F vert (VertIn v)
            {
                V2F o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.vertexLocal = v.vertex;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            FragOut frag (V2F input)
            {
#if MODE_CBI
                return createCurvatureTexture(input);
#else
        
                FragOut output;
                output.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
                output.depth = 0;
                return output;
#endif
            }
            
            ENDCG
        }
        
        GrabPass { "_GrabTexture" } 
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile MODE_DVR MODE_MIP MODE_SURF MODE_CBI MODE_DBI MODE_VDBI

            #include "UnityCG.cginc"

            struct VertIn
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct V2F
            {
                
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 vertexLocal: TEXCOORD1;
                float3 normal : NORMAL;
            };

            struct FragOut
            {
                float4 color : SV_TARGET;
                float depth : SV_DEPTH;
            };

            sampler3D _DataTex;
            sampler3D _GradientTex;
            sampler2D _TransferFunctionTex;

            
            sampler2D _GrabTexture;
            float4 _GrabTexture_TexelSize;

            float3 _FocusCenter;

            int _FocusBorder;
            
            float _FocusRadius;

            float _MinVal;
            float _MaxVal;
            float _FocusVal;

            float3 getGradient(float3 pos)
            {
                return tex3Dlod(_GradientTex, float4(pos.x, pos.y, pos.z, 0.0f)).rgb;
            }
            
            float getDensity(float3 pos)
            {
                return tex3Dlod(_DataTex, float4(pos.x, pos.y, pos.z, 0.0f)).r;
            }

            float4 getColorFromDensity(float density)
            {
                return tex2Dlod(_TransferFunctionTex, float4(density, 0.0f, 0.0f, 0.0f));
            }

            float3 calculateLighting(float3 color, float3 N, float3 L, float3 V)
            {
                float3 diffuse = color * max(lerp(0.0f, 1.5f, dot(N, L)), 0.5f);;
                float3 R = normalize(reflect(-L, N));
                float3 specular = float3(1.0f, 1.0f, 1.0f) * pow(max(dot(R, V), 0.0f), 32.0f) * 0.28f;
                return diffuse + specular;
            }

            float localToDepth(float3 localPos)
            {
                float4 clipPos = UnityObjectToClipPos(float4(localPos, 1.0f));

#if defined(SHADER_API_GLCORE) || defined(SHADER_API_OPENGL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
                return (clipPos.z / clipPos.w) * 0.5 + 0.5;
#else
                return clipPos.z / clipPos.w;
#endif
            }

            FragOut directVolumeRendering (V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 lightDir = normalize(ObjSpaceViewDir(float4(0.0f, 0.0f, 0.0f, 0.0f)));
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                // TODO: ADD NOISE
                //rayStartPos = rayStartPos + (2.0f * rayDir / NUM_STEPS) * tex2D(_NoiseTex, float2(i.uv.x, i.uv.y)).r;
                rayPos += (2.0f * rayDir / NUM_STEPS);
                
                float4 col = float4(0.0f, 0.0f, 0.0f, 0.0f);
                uint iDepth = 0;


                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x >= 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f)
                        break;


                    const float density = getDensity(currPos);

                    float4 src = getColorFromDensity(density);
                    
                    float3 gradient = getGradient(currPos);
                    src.rgb = calculateLighting(src.rgb, normalize(gradient), lightDir, rayDir);

                    if (density < _MinVal || density > _MaxVal)
                        src.a = 0.0f;

                    col.rgb = src.a * src.rgb + (1.0f - src.a) * col.rgb;
                    col.a = src.a + (1.0f - src.a) * col.a;
                    
                    if (src.a > 0.15f)
                        iDepth = i;

                    if (col.a > 1.0f)
                        break;
                }

                // Write fragment output
                FragOut output;
                output.color = col;
                
                if(iDepth != 0)
                {
                    output.depth = localToDepth(rayPos + rayDir * (iDepth * stepSize) - float3(0.5f, 0.5f, 0.5f));
                } else
                {
                    output.depth = 0;
                }

                return output;
            }

            FragOut maximumIntensityProjection(V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += (2.0f * rayDir / NUM_STEPS);
                
                float3 color = float3(1.0f, 1.0f, 1.0f);

                float maximumDensity = 0.0f;

                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x >= 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        break;
                    }
                    
                    float density = getDensity(currPos);
                    
                    if(density > _MinVal && density < _MaxVal)
                    {
                        maximumDensity = max(density, maximumDensity);
                    }
                }

                // Write fragment output
                FragOut output;
                output.color = float4(color, maximumDensity);
                output.depth = localToDepth(input.vertexLocal);

                return output;
            }

            FragOut isoSurfaceRendering(V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 lightDir = normalize(ObjSpaceViewDir(float4(0.0f, 0.0f, 0.0f, 0.0f)));
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += stepSize * rayDir * NUM_STEPS;

                rayDir = -rayDir;
                
                float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);


                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x >= 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        continue;
                    }
                    
                    float density = getDensity(currPos);
                    
                    if(density > _MinVal && density < _MaxVal)
                    {
                        float3 normal = normalize(getGradient(currPos));
                        color = float4(getColorFromDensity(density).rgb, 1.0f);
                        color.rgb = calculateLighting(color.rgb, normal, lightDir, -rayDir);
                        break;
                    }
                }

                // Write fragment output
                FragOut output;
                output.color = color;
                output.depth = localToDepth(input.vertexLocal);
                return output;
            }

            FragOut distanceBasedImportance(V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 lightDir = normalize(ObjSpaceViewDir(float4(0.0f, 0.0f, 0.0f, 0.0f)));
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += stepSize * rayDir * NUM_STEPS;
                rayDir = -rayDir;
                
                float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);

                
                float3 focusCenter = mul(unity_WorldToObject, _FocusCenter) + float3(0.5f, 0.5f, 0.5f);

                float luminance = 1.0f;

                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x >= 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        continue;
                    }
                    
                    float density = getDensity(currPos);
                    
                    
                    if(density > _MinVal && density < _MaxVal)
                    {

                        if(_FocusBorder)
                        {
                            float d = distance(focusCenter, currPos);
                            if(d > 0.98 * _FocusRadius && d < _FocusRadius)
                            {
                                luminance = 0.0f;
                                break;
                            }
                        }
                        
                        float3 normal = normalize(getGradient(currPos));
                        
                        float4 contextColor = getColorFromDensity(density);
                        
                        contextColor.rgb = calculateLighting(contextColor.rgb, normal, lightDir, -rayDir);
                        color = float4(contextColor.rgb , 1.0f);
                        
                        rayDir = -normal;
                        rayPos = currPos;
                       
                        float transparency = 0.0f;
                        for (uint j = 0; j < NUM_STEPS; j++)
                        {
                            const float t = j * stepSize;
                            const float3 currPos = rayPos + rayDir * t;

                            if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                                continue;
                            }

                            float density = getDensity(currPos);

                            if(density > _FocusVal && density < _MaxVal)
                            {
                                transparency = 1 - saturate(max(distance(focusCenter, rayPos) / _FocusRadius, 15.0f * distance(rayPos, currPos)));
                                break;
                            }
                        }

                        rayDir = -normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));
                        for (uint j = 0; j < NUM_STEPS; j++)
                        {
                            const float t = j * stepSize;
                            const float3 currPos = rayPos + rayDir * t;

                            if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                                continue;
                            }

                            float density = getDensity(currPos);

                            if(density > _FocusVal && density < _MaxVal)
                            {
                                float4 focusColor = getColorFromDensity(density);
                                contextColor.rgb = transparency * calculateLighting(focusColor.rgb, normalize(getGradient(currPos)), lightDir, -rayDir) + (1 - transparency) * contextColor.rgb;
                                color = float4(contextColor.rgb , 1.0f);
                                break;
                            }
                        }
                        break;
                    }
                }
                

                // Write fragment output
                FragOut output;
                output.color = color * luminance;
                output.depth = localToDepth(input.vertexLocal);

                return output;
            }

            FragOut viewDistanceBasedImportance(V2F input)
            {
                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 lightDir = normalize(ObjSpaceViewDir(float4(0.0f, 0.0f, 0.0f, 0.0f)));
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += stepSize * rayDir * NUM_STEPS;
                rayDir = -rayDir;
                
                float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);
                float3 focusCenter = mul(unity_WorldToObject, _FocusCenter) + float3(0.5f, 0.5f, 0.5f);

                float luminance = 1.0f;

                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        continue;
                    }
                    
                    float density = getDensity(currPos);
                    
                    
                    if(density > _MinVal && density < _MaxVal)
                    {

                        if(_FocusBorder)
                        {
                            float d = distance(focusCenter, currPos);
                            if(d > 0.98 * _FocusRadius && d < _FocusRadius)
                            {
                                luminance = 0.0f;
                                break;
                            }
                        }
                        float4 contextColor = getColorFromDensity(density);
                        
                        contextColor.rgb = calculateLighting(contextColor.rgb, normalize(getGradient(currPos)), lightDir, -rayDir);
                        color = float4(contextColor.rgb , 1.0f);
                        rayPos = currPos;

                        color.a = 1.0f;
                        
                        
                        for (uint j = 0; j < NUM_STEPS; j++)
                        {
                            const float t = j * stepSize;
                            const float3 currPos = rayPos + rayDir * t;

                            if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                                continue;
                            }

                            float density = getDensity(currPos);

                            if(density > _FocusVal && density < _MaxVal)
                            {
                                
                                float4 focusColor = getColorFromDensity(density);
                                float transparent = 1 - saturate(max(distance(focusCenter, rayPos) / _FocusRadius, 10.0f * distance(rayPos, currPos)));
                                contextColor.rgb = transparent * calculateLighting(focusColor.rgb, normalize(getGradient(currPos)), lightDir, -rayDir) + (1 - transparent) * contextColor.rgb;    
                                color = float4(contextColor.rgb , 1.0f);
                                break;
                            }
                        }
                        break;
                    }
                }
                

                // Write fragment output
                FragOut output;
                output.color = color * luminance;
  
                output.depth = localToDepth(input.vertexLocal);

                return output;
            }

            float getCurvature(float4 texelPos)
            {
                float3 l = tex2Dproj(_GrabTexture, texelPos - float4(_GrabTexture_TexelSize.x, 0.0f, 0.0f, 0.0f)); 
                float3 r = tex2Dproj(_GrabTexture, texelPos + float4(_GrabTexture_TexelSize.x, 0.0f, 0.0f, 0.0f));
                float3 b = tex2Dproj(_GrabTexture, texelPos - float4(0.0f, _GrabTexture_TexelSize.y, 0.0f, 0.0f)); 
                float3 t = tex2Dproj(_GrabTexture, texelPos + float4(0.0f, _GrabTexture_TexelSize.y, 0.0f, 0.0f));

                float3 m = tex2Dproj(_GrabTexture, texelPos).xyz;
                
                float curvature = distance(m, l) + distance(m, r) + distance(m, b) + distance(m, t);
                
                return curvature;
            }
            
            FragOut curvatureBasedImportance(V2F input)
            {
                float4 screenPos = UnityObjectToClipPos(input.vertexLocal);
                float4 grabScreenPos = ComputeGrabScreenPos(screenPos);
                
                float curvature = getCurvature(grabScreenPos);

                #define NUM_STEPS 512

                const float stepSize = 1.732f / NUM_STEPS;

                float3 rayPos = input.vertexLocal + float3(0.5f, 0.5f, 0.5f);
                float3 lightDir = normalize(ObjSpaceViewDir(float4(0.0f, 0.0f, 0.0f, 0.0f)));
                float3 rayDir = normalize(ObjSpaceViewDir(float4(input.vertexLocal, 0.0f)));

                rayPos += stepSize * rayDir * NUM_STEPS;
                rayDir = -rayDir;
                
                float4 color = float4(0.0f, 0.0f, 0.0f, 0.0f);
                float3 focusCenter = mul(unity_WorldToObject, _FocusCenter) + float3(0.5f, 0.5f, 0.5f);

                float luminance = 1.0f;

                for (uint i = 0; i < NUM_STEPS; i++)
                {
                    const float t = i * stepSize;
                    const float3 currPos = rayPos + rayDir * t;
                    if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                        continue;
                    }
                    
                    float density = getDensity(currPos);
                    
                    
                    if(density > _MinVal && density < _MaxVal)
                    {

                        if(_FocusBorder)
                        {
                            float d = distance(focusCenter, currPos);
                            if(d > 0.98 * _FocusRadius && d < _FocusRadius)
                            {
                                luminance = 0.0f;
                                break;
                            }
                        }
                        float4 contextColor = getColorFromDensity(density);
                        
                        contextColor.rgb = calculateLighting(contextColor.rgb, normalize(getGradient(currPos)), lightDir, -rayDir);
                        color = float4(contextColor.rgb , 1.0f);
                        rayPos = currPos;

                        color.a = 1.0f;
                        //color.rgb = float3(curvature, curvature, curvature);
                        //break;
                        
                        for (uint j = 0; j < NUM_STEPS; j++)
                        {
                            const float t = j * stepSize;
                            const float3 currPos = rayPos + rayDir * t;

                            if (currPos.x < 0.0f || currPos.x > 1.0f || currPos.y < 0.0f || currPos.y > 1.0f || currPos.z < 0.0f || currPos.z > 1.0f) {
                                continue;
                            }

                            float density = getDensity(currPos);

                            if(density > _FocusVal && density < _MaxVal)
                            {
                                
                                float4 focusColor = getColorFromDensity(density);
                                float transparent = 1 - saturate(max(distance(focusCenter, rayPos) / _FocusRadius, curvature));
                                contextColor.rgb = transparent * calculateLighting(focusColor.rgb, normalize(getGradient(currPos)), lightDir, -rayDir) + (1 - transparent) * contextColor.rgb;    
                                color = float4(contextColor.rgb , 1.0f);
                                break;
                            }
                        }
                        break;
                    }
                }
                

                // Write fragment output
                FragOut output;
                if(luminance == 0.0f)
                {
                    output.color = float4(0.0f, 0.0f, 0.0f, 1.0f);
                } else
                {
                    output.color = color;
                }
  
                output.depth = localToDepth(input.vertexLocal);

                return output;
            }

            V2F vert (VertIn v)
            {
                V2F o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.vertexLocal = v.vertex;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            FragOut frag (V2F input)
            {
#if MODE_DVR
                return directVolumeRendering(input);
#elif MODE_MIP
                return maximumIntensityProjection(input);
#elif MODE_SURF
                return isoSurfaceRendering(input);
#elif MODE_CBI
                return curvatureBasedImportance(input);
#elif MODE_DBI
                return distanceBasedImportance(input);
#elif MODE_VDBI
                return viewDistanceBasedImportance(input);          
#endif
            }
            ENDCG
        }
    }
}
