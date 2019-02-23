#version 330

#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float4x4 mat4
#define float3x3 mat3

in float2 fragmentTexCoord;

layout(location = 0) out vec4 fragColor;

uniform int g_screenWidth;
uniform int g_screenHeight;

uniform float3 g_bBoxMin   = float3(-1,-1,-1);
uniform float3 g_bBoxMax   = float3(+1,+1,+1);

uniform float4x4 g_rayMatrix;

uniform float4   g_bgColor = float4(0,0,1,1);

float3 EyeRayDir(float x, float y, float w, float h)
{
	float fov = 3.141592654f/(2.0f); 
  float3 ray_dir;
  
	ray_dir.x = x+0.5f - (w/2.0f);
	ray_dir.y = y+0.5f - (h/2.0f);
	ray_dir.z = -(w)/tan(fov/2.0f);
	
  return normalize(ray_dir);
}

bool RayBoxIntersection(float3 ray_pos, float3 ray_dir, float3 boxMin, float3 boxMax, inout float tmin, inout float tmax)
{
  ray_dir.x = 1.0f/ray_dir.x;
  ray_dir.y = 1.0f/ray_dir.y;
  ray_dir.z = 1.0f/ray_dir.z; 

  float lo = ray_dir.x*(boxMin.x - ray_pos.x);
  float hi = ray_dir.x*(boxMax.x - ray_pos.x);
  
  tmin = min(lo, hi);
  tmax = max(lo, hi);

  float lo1 = ray_dir.y*(boxMin.y - ray_pos.y);
  float hi1 = ray_dir.y*(boxMax.y - ray_pos.y);

  tmin = max(tmin, min(lo1, hi1));
  tmax = min(tmax, max(lo1, hi1));

  float lo2 = ray_dir.z*(boxMin.z - ray_pos.z);
  float hi2 = ray_dir.z*(boxMax.z - ray_pos.z);

  tmin = max(tmin, min(lo2, hi2));
  tmax = min(tmax, max(lo2, hi2));
  
  return (tmin <= tmax) && (tmax > 0.f);
}


float3 RayMarchConstantFog(float tmin, float tmax, inout float alpha)
{
  float dt = 0.05f;
	float t  = tmin;
	
	alpha  = 1.0f;
	float3 color = float3(0,0,0);
	
	while(t < tmax && alpha > 0.01f)
	{
	  float a = 0.05f;
	  color += a*alpha*float3(1.0f,1.0f,0.0f);
	  alpha *= (1.0f-a);
	  t += dt;
	}
	
	return color;
}

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;

float sphereSDF(float3 samplePoint, float radius)
{
    return length(samplePoint) - radius;
}

float shortestDistanceToSurface(float3 orig, float3 marchingDirection,
                                float start, float end)
{
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sphereSDF(orig + marchingDirection * depth, 0.05);
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

struct Sphere {
    float3 center;
    float radius;

    /*Sphere(const float3 &c, const float &r)
    {
      center = c;
      radius = r;
    }*/
};

bool ray_intersect(const float3 orig, const float3 dir)
{
  float dist = shortestDistanceToSurface(orig, dir, MIN_DIST, MAX_DIST);

  if (dist > MAX_DIST - EPSILON) {
      return false;
  
  } else {
      return true;
  }
}

float3 cast_ray(const float3 orig, const float3 dir) {
    if (!ray_intersect(orig, dir)) {
        return float3(0.2, 0.7, 0.8); // background color
    }

    return float3(0.4, 0.4, 0.3);
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
  float3 ray_pos = float3(0,0,-4); 
  float3 ray_dir = EyeRayDir(x,y,w,h);
 
  // transorm ray with matrix
  //
  ray_pos = (g_rayMatrix*float4(ray_pos,1)).xyz;
  ray_dir = float3x3(g_rayMatrix)*ray_dir;
 
  // intersect bounding box of the whole scene, if no intersection found return background color
  // 
  float tmin = 1e38f;
  float tmax = 0;
 
  /*if(!RayBoxIntersection(ray_pos, ray_dir, g_bBoxMin, g_bBoxMax, tmin, tmax))
  {
    fragColor = g_bgColor;
    return;
  }
	
	float alpha = 1.0f;
	float3 color = RayMarchConstantFog(tmin, tmax, alpha);
	fragColor = float4(color,0)*(1.0f-alpha) + g_bgColor*alpha;*/

  fragColor = float4(cast_ray(ray_pos, ray_dir), 1);
}

