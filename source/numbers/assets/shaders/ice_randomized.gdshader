shader_type canvas_item;

// Converted from Shadertoy 3D Fractal Tunnel with Phantom Mode Rendering
// Original uses IFS (Iterated Function System) fractals with volumetric effects

// User controls
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float tunnel_speed : hint_range(0.5, 5.0) = 3.0;
uniform float fractal_rotation_speed : hint_range(0.0, 2.0) = 1.0;
uniform int ray_steps : hint_range(50, 150) = 99;
uniform float density_multiplier : hint_range(0.5, 5.0) = 1.0;
uniform vec3 color_tint : source_color = vec3(1.0, 1.1, 1.2);

// Constants
const float pi = 3.141592653589793;  // acos(-1.0) equivalent
const float pi2 = 6.283185307179586; // pi * 2.0

// 2D rotation matrix function
mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

// Polar modulus function for radial repetition
vec2 pmod(vec2 p, float r) {
    float a = atan(p.x, p.y) + pi / r;
    float n = pi2 / r;
    a = floor(a / n) * n;
    return p * rot(-a);
}

// Box SDF (Signed Distance Function)
float box(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// IFS Box - creates fractal through iterative transformations
float ifsBox(vec3 p, float time) {
    for (int i = 0; i < 5; i++) {
        p = abs(p) - 1.0;
        p.xy *= rot(time * 0.3 * fractal_rotation_speed);
        p.xz *= rot(time * 0.1 * fractal_rotation_speed);
    }
    p.xz *= rot(time * fractal_rotation_speed);
    return box(p, vec3(0.4, 0.8, 0.3));
}

// Scene mapping function with repetition and modulation
float map(vec3 p, vec3 cPos, float time) {
    vec3 p1 = p;
    // Create repeating cells in 3D space
    p1.x = mod(p1.x - 5.0, 10.0) - 5.0;
    p1.y = mod(p1.y - 5.0, 10.0) - 5.0;
    p1.z = mod(p1.z, 16.0) - 8.0;

    // Apply polar modulus for radial repetition
    p1.xy = pmod(p1.xy, 5.0);

    return ifsBox(p1, time);
}

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 p = (FRAGCOORD.xy * 2.0 - resolution.xy) / min(resolution.x, resolution.y);

    float time = TIME * time_scale;

    // Camera setup - moves through the tunnel
    vec3 cPos = vec3(0.0, 0.0, -tunnel_speed * time);
    vec3 cDir = normalize(vec3(0.0, 0.0, -1.0));
    vec3 cUp = vec3(sin(time), 1.0, 0.0);
    vec3 cSide = cross(cDir, cUp);

    // Ray direction calculation
    vec3 ray = normalize(cSide * p.x + cUp * p.y + cDir);

    // Phantom Mode Ray Marching - accumulates density instead of finding surfaces
    float acc = 0.0;   // Main accumulator
    float acc2 = 0.0;  // Secondary accumulator for enhanced effects
    float t = 0.0;     // Distance along ray

    for (int i = 0; i < ray_steps; i++) {
        vec3 pos = cPos + ray * t;
        float dist = map(pos, cPos, time);

        // Ensure minimum step size to prevent infinite loops
        dist = max(abs(dist), 0.02);

        // Calculate density contribution
        float a = exp(-dist * 3.0) * density_multiplier;

        // Enhanced glow effect with time-based modulation
        if (mod(length(pos) + 24.0 * time, 30.0) < 3.0) {
            a *= 2.0;
            acc2 += a;
        }

        acc += a;
        t += dist * 0.5;
    }

    // Color composition with phantom mode effects
    vec3 col = vec3(
        acc * 0.01,
        acc * 0.011 + acc2 * 0.002,
        acc * 0.012 + acc2 * 0.005
    ) * color_tint;

    // Output with alpha based on ray travel distance for depth effect
    COLOR = vec4(col, 1.0 - t * 0.03);
}
