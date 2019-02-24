#version 330

#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float4x4 mat4
#define float3x3 mat3

#define SPHERE 0

in float2 fragmentTexCoord;

layout(location = 0) out vec4 fragColor;

uniform int g_screenWidth;
uniform int g_screenHeight;

uniform float3 g_bBoxMin   = float3(-1,-1,-1);
uniform float3 g_bBoxMax   = float3(+1,+1,+1);

uniform float4x4 g_rayMatrix;

uniform float4   g_bgColor = float4(0,0,1,1);

struct Primitive
{
    float3 a;
    float b;
    int type;
};

uniform Primitive objects[1] = Primitive[1](
        Primitive(float3(-0.4, 0.0, 4.0), 0.05, SPHERE));

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;

struct Light {
    float3 position;
    float intensity;
};

float sphereSDF(float3 samplePoint, float radius)
{
    return distance(samplePoint, objects[0].a) - radius;
}

float shortestDistanceToSurface(float3 orig, float3 marchingDirection,
                                float start, float end)
{
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist;
        
        switch (objects[0].type) {
        case SPHERE:
            dist = sphereSDF(orig + marchingDirection * depth, objects[0].b);
            break;
        }
        
        if (dist < EPSILON) {
            return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}

bool ray_intersect(const float3 orig, const float3 dir)
{
  float dist = shortestDistanceToSurface(orig, dir, MIN_DIST, MAX_DIST);

  if (dist > MAX_DIST - EPSILON) {
      return false;
  
  } else {
      return true;
  }
}

float4 cast_ray(const float3 orig, const float3 dir) {
    if (!ray_intersect(orig, dir)) {
        return float4(0.2, 0.7, 0.8, 1.0); // background color
    }

    return float4(0.4, 0.4, 0.3, 1.0);
}

float3 EyeRayDir(float x, float y, float w, float h)
{
    float fov = 3.141592654f/(2.0f); 
    float3 ray_dir;
  
    ray_dir.x = x+0.5f - (w/2.0f);
    ray_dir.y = y+0.5f - (h/2.0f);
    ray_dir.z = -(w)/tan(fov/2.0f);
    
  return normalize(ray_dir);
}

void main(void)
{

  float w = float(g_screenWidth);
  float h = float(g_screenHeight);
  
  // get curr pixelcoordinates
  //
  float x = fragmentTexCoord.x*w; 
  float y = fragmentTexCoord.y*h;
  
  // generate initial ray
  //
  float3 ray_pos = float3(0.0, 0.0, 0.0);
  float3 ray_dir = EyeRayDir(x,y,w,h);
 
  // transorm ray with matrix
  //
  ray_pos = (g_rayMatrix*float4(ray_pos,1)).xyz;
  ray_dir = float3x3(g_rayMatrix)*ray_dir;
 
  // intersect bounding box of the whole scene, if no intersection found return background color
  // 
  float tmin = 1e38f;
  float tmax = 0;

  fragColor = cast_ray(ray_pos, ray_dir);
}
