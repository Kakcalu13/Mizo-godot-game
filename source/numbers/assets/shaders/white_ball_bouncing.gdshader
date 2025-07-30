shader_type canvas_item;

uniform float animation_speed : hint_range(0.1, 3.0) = 1.587;
uniform float ball_radius : hint_range(0.1, 1.0) = 0.33;
uniform vec3 ball_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 background_color : source_color = vec3(0.0, 0.0, 0.0);

void fragment() {
    // Get screen resolution
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;

    // Normalized coordinates centered
    vec2 uv = FRAGCOORD.xy / resolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;

    float t = mod(TIME * animation_speed, 2.0); // 2-second loop

    // Vertical bouncing motion (parabolic bounce)
    float bounce_time = fract(t); // [0,1]
    float y = abs(sin(bounce_time * 3.1415)); // Arc motion

    // Ball position
    vec2 ball_pos = vec2(0.0, -0.7 + y * 1.4); // From bottom to top

    // Distance from pixel to ball center
    float d = length(uv - ball_pos);

    // Ball color with smooth edges (white on black background)
    vec3 col = mix(ball_color, background_color, smoothstep(ball_radius - 0.01, ball_radius, d));

    COLOR = vec4(col, 1.0);
}
