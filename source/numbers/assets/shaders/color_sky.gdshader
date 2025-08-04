shader_type sky;

uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float effect_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec3 color_tint = vec3(1.0, 1.0, 1.0);

// Mathematical noise functions to replace texture sampling
float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Simulate blur levels with mathematical functions
vec4 simulateBlurA(vec2 uv, int level) {
    float scale = pow(0.5, float(level));
    vec2 p = uv * scale;

    float r = fbm(p + TIME * 0.1);
    float g = fbm(p + vec2(1.7, 9.2) + TIME * 0.12);
    float b = fbm(p + vec2(8.3, 2.8) + TIME * 0.08);
    float a = fbm(p + vec2(5.2, 1.4) + TIME * 0.15);

    return vec4(r, g, b, a);
}

vec2 gradientA(vec2 uv, vec2 d, vec4 selector, int level) {
    vec4 dX = 0.5 * simulateBlurA(uv + vec2(1.0, 0.0) * d, level) -
              0.5 * simulateBlurA(uv - vec2(1.0, 0.0) * d, level);
    vec4 dY = 0.5 * simulateBlurA(uv + vec2(0.0, 1.0) * d, level) -
              0.5 * simulateBlurA(uv - vec2(0.0, 1.0) * d, level);
    return vec2(dot(dX, selector), dot(dY, selector));
}

void sky() {
    // Convert EYEDIR to UV-like coordinates
    vec2 uv = vec2(
        atan(EYEDIR.x, EYEDIR.z) / (2.0 * PI) + 0.5,
        acos(EYEDIR.y) / PI
    );

    vec2 pixelSize = vec2(0.002); // Approximate pixel size for sky

    // Apply the original algorithm with mathematical approximations
    vec2 d = pixelSize * 2.0;
    vec4 dx = (simulateBlurA(uv + vec2(1, 0) * d, 1) - simulateBlurA(uv - vec2(1, 0) * d, 1)) * 0.5;
    vec4 dy = (simulateBlurA(uv + vec2(0, 1) * d, 1) - simulateBlurA(uv - vec2(0, 1) * d, 1)) * 0.5;

    d = pixelSize * 1.0;
    dx += simulateBlurA(uv + vec2(1, 0) * d, 0) - simulateBlurA(uv - vec2(1, 0) * d, 0);
    dy += simulateBlurA(uv + vec2(0, 1) * d, 0) - simulateBlurA(uv - vec2(0, 1) * d, 0);

    vec2 lightSize = vec2(0.5);

    // Original color mixing logic with mathematical substitutions
    vec4 fragColor = simulateBlurA(uv + vec2(dx.x, dy.x) * pixelSize * 8.0, 0).x *
                     vec4(0.7, 1.66, 2.0, 1.0) - vec4(0.3, 1.0, 1.0, 1.0);

    fragColor = mix(fragColor, vec4(8.0, 6.0, 2.0, 1.0),
                   simulateBlurA(uv + vec2(dx.x, dy.x) * lightSize, 3).y * 0.4 * 0.75 *
                   vec4(1.0 - simulateBlurA(uv + vec2(dx.x, dy.x) * pixelSize * 8.0, 0).x));

    fragColor = mix(fragColor, vec4(0.1, 0.0, 0.4, 0.0),
                   simulateBlurA(uv, 1).a * length(gradientA(uv, pixelSize * 2.0, vec4(0.0, 0.0, 0.0, 1.0), 0)) * 5.0);

    fragColor = mix(fragColor, vec4(1.25, 1.35, 1.4, 0.0),
                   simulateBlurA(uv, 0).x *
                   simulateBlurA(uv + gradientA(uv, pixelSize * 2.5, vec4(-256.0, 32.0, -128.0, 32.0), 1) * pixelSize, 2).y);

    fragColor = mix(fragColor, vec4(0.25, 0.75, 1.0, 0.0),
                   simulateBlurA(uv, 1).x *
                   length(gradientA(uv + gradientA(uv, pixelSize * 2.0, vec4(0.0, 0.0, 128.0, 0.0), 1) * pixelSize,
                                   pixelSize * 2.0, vec4(0.0, 0.0, 0.0, 1.0), 0)) * 5.0);

    fragColor = mix(fragColor, vec4(1.0, 1.25, 1.5, 0.0),
                   0.5 * (1.0 - simulateBlurA(uv, 0) * 1.0).a *
                   length(gradientA(uv + gradientA(uv, pixelSize * 2.0, vec4(0.0, 128.0, 0.0, 0.0), 1) * pixelSize,
                                   pixelSize * 1.5, vec4(0.0, 0.0, 16.0, 0.0), 0)));

    // Apply user controls
    fragColor.rgb *= color_tint * effect_intensity;

    COLOR = fragColor.rgb;
}

