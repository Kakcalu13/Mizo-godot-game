shader_type canvas_item;

// Converted from Shadertoy refraction shader
// Features: Icosahedral refraction shell with animated inner object

// Uniforms for user control
uniform float time_scale : hint_range(0.1, 3.0) = 2.336;
uniform float camera_distance : hint_range(2.0, 8.0) = 6.382;
uniform float camera_height : hint_range(-2.0, 2.0) = -0.2;
uniform float rotation_speed : hint_range(0.0, 2.0) = 0.45;
uniform vec2 mouse_override = vec2(0.0, 0.0);
uniform bool use_mouse_override = false;

// Constants and globals
//const float PI = 3.141592653589793;
const float MAX_DIST = 20.0;
const float PRECISION = 0.001;

// Icosahedral normals - precomputed for performance
const vec3 n4 = vec3(0.577, 0.577, 0.577);
const vec3 n5 = vec3(-0.577, 0.577, 0.577);
const vec3 n6 = vec3(0.577, -0.577, 0.577);
const vec3 n7 = vec3(0.577, 0.577, -0.577);
const vec3 n8 = vec3(0.000, 0.357, 0.934);
const vec3 n9 = vec3(0.000, -0.357, 0.934);
const vec3 n10 = vec3(0.934, 0.000, 0.357);
const vec3 n11 = vec3(-0.934, 0.000, 0.357);
const vec3 n12 = vec3(0.357, 0.934, 0.000);
const vec3 n13 = vec3(-0.357, 0.934, 0.000);

// Utility Functions
vec2 rotate2D(vec2 p, float a) {
    return p * mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
}

float random(vec2 co) {
    float a = 12.9898;
    float b = 78.233;
    float c = 43758.5453;
    float dt = dot(co.xy, vec2(a, b));
    float sn = mod(dt, 3.14);
    return fract(sin(sn) * c);
}

// Box SDF
float sdBox(vec3 position, vec3 dimensions) {
    vec3 d = abs(position) - dimensions;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// Icosahedral SDF
float icosahedral(vec3 p, float r) {
    float s = abs(dot(p, n4));
    s = max(s, abs(dot(p, n5)));
    s = max(s, abs(dot(p, n6)));
    s = max(s, abs(dot(p, n7)));
    s = max(s, abs(dot(p, n8)));
    s = max(s, abs(dot(p, n9)));
    s = max(s, abs(dot(p, n10)));
    s = max(s, abs(dot(p, n11)));
    s = max(s, abs(dot(p, n12)));
    s = max(s, abs(dot(p, n13)));
    return s - r;
}

// Distance functions
vec2 mapRefract(vec3 p) {
    float d = icosahedral(p, 1.0);
    float id = 0.0;
    return vec2(d, id);
}

vec2 mapSolid(vec3 p, float time) {
    p.xz = rotate2D(p.xz, time * 1.25);
    p.yx = rotate2D(p.yx, time * 1.85);
    p.y += sin(time) * 0.25;
    p.x += cos(time) * 0.25;

    float d = length(p) - 0.25;
    float id = 1.0;
    float pulse = pow(sin(time * 2.0) * 0.5 + 0.5, 9.0) * 2.0;

    d = mix(d, sdBox(p, vec3(0.175)), pulse);
    return vec2(d, id);
}

// Raymarching for refraction shell
vec2 calcRayIntersectionRefract(vec3 rayOrigin, vec3 rayDir, float maxd, float precis) {
    float latest = precis * 2.0;
    float dist = 0.0;
    float type = -1.0;
    vec2 res = vec2(-1.0, -1.0);

    for (int i = 0; i < 50; i++) {
        if (latest < precis || dist > maxd) break;

        vec2 result = mapRefract(rayOrigin + rayDir * dist);
        latest = result.x;
        type = result.y;
        dist += latest;
    }

    if (dist < maxd) {
        res = vec2(dist, type);
    }
    return res;
}

// Raymarching for solid inner object
vec2 calcRayIntersectionSolid(vec3 rayOrigin, vec3 rayDir, float maxd, float precis, float time) {
    float latest = precis * 2.0;
    float dist = 0.0;
    float type = -1.0;
    vec2 res = vec2(-1.0, -1.0);

    for (int i = 0; i < 60; i++) {
        if (latest < precis || dist > maxd) break;

        vec2 result = mapSolid(rayOrigin + rayDir * dist, time);
        latest = result.x;
        type = result.y;
        dist += latest;
    }

    if (dist < maxd) {
        res = vec2(dist, type);
    }
    return res;
}

// Normal calculation for refraction shell
vec3 calcNormalRefract(vec3 pos, float eps) {
    const vec3 v1 = vec3(1.0, -1.0, -1.0);
    const vec3 v2 = vec3(-1.0, -1.0, 1.0);
    const vec3 v3 = vec3(-1.0, 1.0, -1.0);
    const vec3 v4 = vec3(1.0, 1.0, 1.0);

    return normalize(
        v1 * mapRefract(pos + v1 * eps).x +
        v2 * mapRefract(pos + v2 * eps).x +
        v3 * mapRefract(pos + v3 * eps).x +
        v4 * mapRefract(pos + v4 * eps).x
    );
}

// Normal calculation for solid object
vec3 calcNormalSolid(vec3 pos, float eps, float time) {
    const vec3 v1 = vec3(1.0, -1.0, -1.0);
    const vec3 v2 = vec3(-1.0, -1.0, 1.0);
    const vec3 v3 = vec3(-1.0, 1.0, -1.0);
    const vec3 v4 = vec3(1.0, 1.0, 1.0);

    return normalize(
        v1 * mapSolid(pos + v1 * eps, time).x +
        v2 * mapSolid(pos + v2 * eps, time).x +
        v3 * mapSolid(pos + v3 * eps, time).x +
        v4 * mapSolid(pos + v4 * eps, time).x
    );
}

// Beckmann distribution for Cook-Torrance BRDF
float beckmannDistribution(float x, float roughness) {
    float NdotH = max(x, 0.0001);
    float cos2Alpha = NdotH * NdotH;
    float tan2Alpha = (cos2Alpha - 1.0) / cos2Alpha;
    float roughness2 = roughness * roughness;
    float denom = PI * roughness2 * cos2Alpha * cos2Alpha;
    return exp(tan2Alpha / roughness2) / denom;
}

// Cook-Torrance specular BRDF
float cookTorranceSpecular(
    vec3 lightDirection,
    vec3 viewDirection,
    vec3 surfaceNormal,
    float roughness,
    float fresnel
) {
    float VdotN = max(dot(viewDirection, surfaceNormal), 0.0);
    float LdotN = max(dot(lightDirection, surfaceNormal), 0.0);

    vec3 H = normalize(lightDirection + viewDirection);
    float NdotH = max(dot(surfaceNormal, H), 0.0);
    float VdotH = max(dot(viewDirection, H), 0.000001);
    float LdotH = max(dot(lightDirection, H), 0.000001);

    float G1 = (2.0 * NdotH * VdotN) / VdotH;
    float G2 = (2.0 * NdotH * LdotN) / LdotH;
    float G = min(1.0, min(G1, G2));

    float D = beckmannDistribution(NdotH, roughness);
    float F = pow(1.0 - VdotN, fresnel);

    return G * F * D / max(PI * VdotN, 0.000001);
}

// Screen space conversion
vec2 squareFrame(vec2 screenSize, vec2 coord) {
    vec2 position = 2.0 * (coord.xy / screenSize.xy) - 1.0;
    position.x *= screenSize.x / screenSize.y;
    return position;
}

// Camera matrix calculation
mat3 calcLookAtMatrix(vec3 origin, vec3 target, float roll) {
    vec3 rr = vec3(sin(roll), cos(roll), 0.0);
    vec3 ww = normalize(target - origin);
    vec3 uu = normalize(cross(ww, rr));
    vec3 vv = normalize(cross(uu, ww));
    return mat3(uu, vv, ww);
}

// Ray generation
vec3 getRay(mat3 camMat, vec2 screenPos, float lensLength) {
    return normalize(camMat * vec3(screenPos, lensLength));
}

// Fog calculation
float fogFactorExp2(float dist, float density) {
    const float LOG2 = -1.442695;
    float d = density * dist;
    return 1.0 - clamp(exp2(d * d * LOG2), 0.0, 1.0);
}

// Plane intersection
float intersectPlane(vec3 ro, vec3 rd, vec3 nor, float dist) {
    float denom = dot(rd, nor);
    float t = -(dot(ro, nor) + dist) / denom;
    return t;
}

// Color palette function
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Background generation
vec3 bg(vec3 ro, vec3 rd, float time) {
    vec3 col = 0.1 + palette(
        clamp((random(rd.xz + sin(time * 0.1)) * 0.5 + 0.5) * 0.035 - rd.y * 0.5 + 0.35, -1.0, 1.0),
        vec3(0.5, 0.45, 0.55),
        vec3(0.5, 0.5, 0.5),
        vec3(1.05, 1.0, 1.0),
        vec3(0.275, 0.2, 0.19)
    );

    float t = intersectPlane(ro, rd, vec3(0, 1, 0), 4.0);
    if (t > 0.0) {
        vec3 p = ro + rd * t;
        float g = (1.0 - pow(abs(sin(p.x) * cos(p.z)), 0.25));
        col += (1.0 - fogFactorExp2(t, 0.04)) * g * vec3(5, 4, 2) * 0.075;
    }

    return col;
}

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 uv = squareFrame(resolution, FRAGCOORD.xy);

    float time = TIME * time_scale;

    // Camera setup
    float rotation = use_mouse_override ?
        6.0 * mouse_override.x :
        time * rotation_speed;
    float height = use_mouse_override ?
        5.0 * (mouse_override.y * 2.0 - 1.0) :
        camera_height;

    vec3 ro = vec3(
        camera_distance * sin(rotation),
        height,
        camera_distance * cos(rotation)
    );

    vec3 rayTarget = vec3(0.0);
    mat3 camMat = calcLookAtMatrix(ro, rayTarget, 0.0);
    vec3 rd = getRay(camMat, uv, 2.0);

    vec3 color = bg(ro, rd, time);

    // Raymarch the refraction shell
    vec2 t = calcRayIntersectionRefract(ro, rd, MAX_DIST, PRECISION);

    if (t.x > -0.5) {
        vec3 pos = ro + rd * t.x;
        vec3 nor = calcNormalRefract(pos, 0.002);

        // Light setup
        vec3 ldir1 = normalize(vec3(0.8, 1, 0));
        vec3 ldir2 = normalize(vec3(-0.4, -1.3, 0));
        vec3 lcol1 = vec3(0.6, 0.5, 1.1);
        vec3 lcol2 = vec3(1.4, 0.9, 0.8) * 0.7;

        // Refraction through the shell
        vec3 ref = refract(rd, nor, 0.97);
        vec2 u = calcRayIntersectionSolid(ro + ref * 0.1, ref, MAX_DIST, PRECISION, time);

        if (u.x > -0.5) {
            // Hit the inner object
            vec3 pos2 = ro + ref * u.x;
            vec3 nor2 = calcNormalSolid(pos2, 0.002, time);

            float spec = cookTorranceSpecular(ldir1, -ref, nor2, 0.6, 0.95) * 2.0;
            float diff1 = 0.05 + max(0.0, dot(ldir1, nor2));
            float diff2 = max(0.0, dot(ldir2, nor2));

            color = spec + (diff1 * lcol1 + diff2 * lcol2);
        } else {
            // No inner object hit, show refracted background
            color = bg(ro + ref * 0.1, ref, time) * 1.1;
        }

        // Add specular highlight on the outer shell
        color += color * cookTorranceSpecular(ldir1, -rd, nor, 0.2, 0.9) * 2.0;
        color += 0.05;
    }

    // Vignette effect
    float vignette = 1.0 - max(0.0, dot(uv * 0.155, uv));

    // Color grading
    color.r = smoothstep(0.05, 0.995, color.r);
    color.b = smoothstep(-0.05, 0.95, color.b);
    color.g = smoothstep(-0.1, 0.95, color.g);
    color.b *= vignette;

    COLOR = vec4(color, clamp(t.x, 0.5, 1.0));
}
