#version 330

#define float2 vec2
#define float3 vec3
#define float4 vec4
#define float4x4 mat4
#define float3x3 mat3

#define SPHERE 0
#define TORUS 1
#define CAPSULE 2


in float2 fragmentTexCoord;

layout(location = 0) out vec4 fragColor;

uniform int g_screenWidth;
uniform int g_screenHeight;

uniform float4x4 g_rayMatrix;

uniform float4 g_bgColor = float4(0.05, 0.05, 0.05, 1.0);


const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
const int PRIMITIVES_NUMBER = 5;
const int LIGHTS_NUMBER = 2;


struct Material
{
    float4 diffuse_color;
    float2 albedo;
    float specular_exponent;
};

struct Primitive
{
    float3 center;
    float radius;
    float2 torus_par;
    float3 capsule_par1;
    float3 capsule_par2;
    Material material;
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
    Material material;
    float3 hit_point;
    float3 norm;
};


uniform Primitive objects[PRIMITIVES_NUMBER] = Primitive[PRIMITIVES_NUMBER](
        
        Primitive(float3(-1.9, -0.3, -1.0), // Red Sphere
                  0.9,
                  float2(0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  Material(float4(0.3, 0.1, 0.1, 1.0),
                           float2(0.3,  0.25),
                           8.0),
                  SPHERE),

        Primitive(float3(-0.75, 0.5, 0.1), // Blue Sphere.
                  0.25,
                  float2(0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  Material(float4(0.0, 0.169, 0.212, 1.0),
                           float2(0.7,  0.5),
                           20.0),
                  SPHERE),

        Primitive(float3(-2.4, -0.15, -5.25), // Green Sphere.
                  0.25,
                  float2(0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  Material(float4(0.023, 0.125, 0.047, 1.0),
                           float2(0.5,  0.5),
                           20.0),
                  SPHERE),

        Primitive(float3(-1.9, -0.3, -1.0), // Red Torus
                  0.0,
                  float2(1.2, 0.15),
                  float3(0.0, 0.0, 0.0),
                  float3(0.0, 0.0, 0.0),
                  Material(float4(0.3, 0.1, 0.1, 1.0),
                           float2(0.3,  0.25),
                           8.0),
                  TORUS),

        Primitive(float3(-3.5, 0.7, -3), // Grey Capsule
                  0.05,
                  float2(0.0, 0.0),
                  float3(0.25, 0.0, 0.0),
                  float3(0.0, 0.6, 0.4),
                  Material(float4(0.3, 0.3, 0.3, 1.0),
                           float2(0.45,  0.3),
                           10.0),
                  CAPSULE)
        );

uniform Light lights[LIGHTS_NUMBER] = Light[LIGHTS_NUMBER](
        
        Light(float3(1.75, 2.75, 3.5),
              7.0),

        Light(float3(-3.0, 0.5, -2.0),
              5.0)
        );


float sd_sphere(float3 samplePoint, int index)
{
    return distance(samplePoint, objects[index].center) -
            objects[index].radius;
}

float sd_torus(float3 samplePoint, int index)
{
    samplePoint = samplePoint - objects[index].center;
    float2 q = float2(length(samplePoint.xz) - objects[index].torus_par.x,
                      samplePoint.y);
    
    return length(q) - objects[index].torus_par.y;
}

float sd_capsule(float3 samplePoint, int index)
{
    samplePoint = samplePoint - objects[index].center;

    float3 pa = samplePoint - objects[index].capsule_par1;
    float3 ba = objects[index].capsule_par2 - objects[index].capsule_par1;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    
    return length(pa - ba * h) - objects[index].radius;
}

float shortest_distance_to_surface(float3 orig, float3 marchingDirection,
                                   float start, float end,
                                   int index)
{
    float depth = start;
    
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist;
        
        switch (objects[index].type) {
        case SPHERE:
            dist = sd_sphere(orig + marchingDirection * depth, index);
            break;

        case TORUS:
            dist = sd_torus(orig + marchingDirection * depth, index);
            break;

        case CAPSULE:
            dist = sd_capsule(orig + marchingDirection * depth, index);
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
    float dist = shortest_distance_to_surface(orig, dir,
                                              MIN_DIST, MAX_DIST,
                                              index);

    Hit hit;
    hit.distance = dist;

    if (dist > MAX_DIST - EPSILON) {
      hit.exist = false;

    } else {
      hit.exist = true;
    }

    hit.material = objects[index].material;

    return hit;
}

float3 reflect(const float3 light_dir, const float3 norm)
{
    return light_dir - norm * 2.0f * (light_dir * norm);
}

Hit scene_intersect(const float3 orig, const float3 dir)
{
    Hit hit;
    Hit ret_hit;
    ret_hit.distance = MAX_DIST;
    ret_hit.exist = false;

    for (int i = 0; i < PRIMITIVES_NUMBER; i++) {
        hit = ray_intersect(orig, dir, i);

        if (hit.exist && hit.distance < ret_hit.distance) {
            ret_hit = hit;
            ret_hit.hit_point = orig + dir * ret_hit.distance;
            ret_hit.norm = normalize(ret_hit.hit_point - objects[i].center);
        }
    }

    return ret_hit;
}

float4 cast_ray(const float3 orig, const float3 dir)
{
    Hit hit = scene_intersect(orig, dir);
    
    if (!hit.exist) {
        return g_bgColor;
    }

    float diffuse_light_intensity = 0;
    float specular_light_intensity = 0;
    
    for (int i = 0; i < LIGHTS_NUMBER; i++) {
        float3 light_dir = normalize(lights[i].position - hit.hit_point);

        float light_distance = length(lights[i].position - hit.hit_point);

        float3 shadow_orig = dot(light_dir, hit.norm) < 0 ? 
                             hit.hit_point - hit.norm * 1e-3 :
                             hit.hit_point + hit.norm * 1e-3;
        
        Hit shadow_hit = scene_intersect(shadow_orig, light_dir);

        if (shadow_hit.exist &&
                length(shadow_hit.hit_point - shadow_orig) < light_distance) {
            continue;
        }
        
        diffuse_light_intensity += lights[i].intensity *
                max(0.0f, dot(light_dir, hit.norm));
        
        specular_light_intensity += pow(
                max(0.0f, -dot(reflect(-light_dir, hit.norm), dir)),
                hit.material.specular_exponent) * lights[i].intensity;
    }

    return hit.material.diffuse_color *
           diffuse_light_intensity *
           hit.material.albedo[0]
           +
           float4(1.0, 1.0, 1.0, 1.0) *
           specular_light_intensity *
           hit.material.albedo[1];
}

float3 eye_ray_dir(float x, float y, float w, float h)
{
    float fov = 3.141592654f/(2.0f); 
    float3 ray_dir;
  
    ray_dir.x = x + 0.5f - w / 2.0f;
    ray_dir.y = y + 0.5f - h / 2.0f;
    ray_dir.z = -w / tan(fov / 2.0f);
    
    return normalize(ray_dir);
}


void main(void)
{
    float w = float(g_screenWidth);
    float h = float(g_screenHeight);

    // Get current pixel coordinates.
    float x = fragmentTexCoord.x * w; 
    float y = fragmentTexCoord.y * h;

    // Generate initial ray.
    float3 ray_pos = float3(0.8, 2.25, 3.0);
    float3 ray_dir = eye_ray_dir(x, y, w, h);

    // Transorm ray with matrix.
    ray_pos = (g_rayMatrix * float4(ray_pos, 1.0)).xyz;
    ray_dir = float3x3(g_rayMatrix) * ray_dir;

    fragColor = cast_ray(ray_pos, ray_dir);
}
