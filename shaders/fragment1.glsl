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

uniform float4 g_bgColor = float4(0.2, 0.7, 0.8, 1.0);


struct Primitive
{
    float3 a;
    float b;
    float4 color;
    int type;
};

struct Light {
    float3 position;
    float intensity;
};

struct Hit
{
    bool exist;
    float distance;
    float4 color;
};


const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const int PRIMIRIVES_NUMBER = 1;


uniform Primitive objects[PRIMIRIVES_NUMBER] = Primitive[PRIMIRIVES_NUMBER](
        Primitive(float3(-0.4, 0.0, 4.0),
                  0.05,
                  float4(0.4, 0.4, 0.3, 1.0),
                  SPHERE));


float sphereSDF(float3 samplePoint, int index)
{
    return distance(samplePoint, objects[index].a) - objects[index].b;
}

float shortestDistanceToSurface(float3 orig, float3 marchingDirection,
                                float start, float end,
                                int index)
{
    float depth = start;
    
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist;
        
        switch (objects[0].type) {
        case SPHERE:
            dist = sphereSDF(orig + marchingDirection * depth, index);
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

Hit ray_intersect(const float3 orig, const float3 dir, int index)
{
    float dist = shortestDistanceToSurface(orig, dir,
                                           MIN_DIST, MAX_DIST,
                                           index);

    Hit hit;
    hit.distance = dist;

    if (dist > MAX_DIST - EPSILON) {
      hit.exist = false;

    } else {
      hit.exist = true;
    }

    hit.color = objects[0].color;

    return hit;
}

Hit scene_intersect(const float3 orig, const float3 dir)
{
    Hit hit;
    float spheres_dist = MAX_DIST;

    for (int i = 0; i < PRIMIRIVES_NUMBER; i++) {
        float dist_i = 0;

        hit = ray_intersect(orig, dir, i);

        if (hit.exist && hit.distance < spheres_dist) {
            spheres_dist = dist_i;
            /*float3 hit_point = orig + dir * dist_i;
            N = (hit - spheres[i].center).normalize();*/
        }
    }
    return hit;
}

float4 cast_ray(const float3 orig, const float3 dir) {
    Hit hit = scene_intersect(orig, dir);
    
    if (!hit.exist) {
        return g_bgColor;
    }

    return hit.color;
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
