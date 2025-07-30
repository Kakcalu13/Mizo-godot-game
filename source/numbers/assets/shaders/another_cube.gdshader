shader_type canvas_item;

// Converted from Shadertoy "Just another cube" by CC0
// Uniforms (adjustable parameters)
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float scale_factor : hint_range(0.01, 1.0) = 0.02;

// Global constants
const float M = 1e-3;

// Distance Function (SDF - Signed Distance Field)
float sdf_scene(vec3 p, float time, inout float glow_accumulator) {
    // Apply two rotations to the point's coordinates
    mat2 rotation_matrix = mat2(vec2(cos(0.3 * time), sin(0.3 * time)),
                               vec2(-sin(0.3 * time), cos(0.3 * time)));

    p.xy *= rotation_matrix;
    p.xz *= rotation_matrix;

    // Create surface detail patterns
    vec3 surface_detail = sin(123.0 * p);

    // Calculate the main object distance (superquadric/rounded cube)
    vec3 p_powered = p * p * p * p;
    float main_distance = pow(dot(p_powered, p_powered), 0.125) - 0.5;

    // Add surface detail subtraction
    main_distance -= pow(1.0 + surface_detail.x * surface_detail.y * surface_detail.z, 8.0) / 1e5;

    // Update glow effect by tracking minimum distance to glowing shell
    float glow_shell = max(abs(length(p) - 0.6), main_distance);
    glow_accumulator = min(glow_accumulator, glow_shell);

    return main_distance;
}

// Raymarching function
float raymarch(vec3 ray_origin, vec3 ray_direction, float time, inout float glow_accumulator) {
    float total_distance = 0.0;
    float surface_distance = 1.0;

    glow_accumulator = 9.0; // Initialize glow tracking

    // Raymarching loop
    for (int i = 0; i < 64 && total_distance < 9.0 && surface_distance > M; i++) {
        vec3 current_position = ray_origin + ray_direction * total_distance;
        surface_distance = sdf_scene(current_position, time, glow_accumulator);
        total_distance += surface_distance;
    }

    return total_distance;
}

// Calculate surface normal using gradient estimation
vec3 calculate_normal(vec3 p, float time) {
    float temp_glow = 9.0;
    vec2 epsilon = vec2(M, 0.0);

    return normalize(vec3(
        sdf_scene(p + epsilon.xyy, time, temp_glow) - sdf_scene(p - epsilon.xyy, time, temp_glow),
        sdf_scene(p + epsilon.yxy, time, temp_glow) - sdf_scene(p - epsilon.yxy, time, temp_glow),
        sdf_scene(p + epsilon.yyx, time, temp_glow) - sdf_scene(p - epsilon.yyx, time, temp_glow)
    ));
}

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

    // Convert screen coordinates to ray direction
    vec3 ray_direction = normalize(vec3(FRAGCOORD.xy - 0.5 * resolution.xy, resolution.y));
    vec3 ray_origin = vec3(0.0, 0.0, -2.0);

    // Base glow color (dark bluish tint)
    vec3 base_glow = vec3(2.0, 100.0, 9.0) * M;

    float scene_glow = 9.0;
    float total_distance = raymarch(ray_origin, ray_direction, TIME, scene_glow);

    vec3 final_color = vec3(100.0);

    // Check if ray hit something
    if (total_distance < 9.0) {
        vec3 hit_point = ray_origin + ray_direction * total_distance;
        vec3 surface_normal = calculate_normal(hit_point, TIME);

        // Calculate fresnel factor for edge brightness
        float fresnel = 1.0 + dot(surface_normal, ray_direction);

        // Calculate reflection vector
        vec3 reflection = reflect(ray_direction, surface_normal);

        // Calculate reflection color based on direction
        vec3 reflection_color;
        if (reflection.y > 0.0) {
            // Sky reflection - procedural sky with radial gradient
            vec2 sky_coord = (hit_point + reflection * (5.0 - hit_point.y) / abs(reflection.y)).xz;
            float sky_distance = sqrt(dot(sky_coord, sky_coord)) + 1.0;
            reflection_color = 500.0 * smoothstep(5.0, 4.0, sky_distance) * sky_distance * base_glow;
        } else {
            // Floor reflection - deep blue exponential falloff
            vec2 floor_coord = (hit_point + reflection * (5.0 - hit_point.y) / abs(reflection.y)).xz;
            reflection_color = exp(-2.0 * length(floor_coord)) * (base_glow / M - 1.0);
        }

        // Combine fresnel and reflection
        final_color = fresnel * fresnel * reflection_color;

        // Add rim lighting
        final_color += pow(1.0 + surface_normal.y, 5.0) * base_glow;
    }

    // Add glow contribution and apply tonemapping
    final_color += base_glow * glow_intensity / scene_glow;

    // Apply scale factor and square root tone mapping
    COLOR = vec4(sqrt(final_color * scale_factor), 1.0);
}
