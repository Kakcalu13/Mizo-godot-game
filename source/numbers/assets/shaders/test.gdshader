shader_type canvas_item;

// Converted Rainbow Ripple Shader from Shadertoy
// Creates animated concentric rainbow circles expanding outward

// User controls
uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float outline_thickness : hint_range(0.001, 0.01) = 0.002;
uniform float center_offset_x : hint_range(-1.0, 1.0) = 0.0;
uniform float center_offset_y : hint_range(-1.0, 1.0) = 0.0;


// Rainbow colors array (7 colors)
const vec3 rainbow_colors[7] = {
    vec3(1.0, 0.0, 0.0),  // Red
    vec3(1.0, 0.5, 0.0),  // Orange
    vec3(1.0, 1.0, 0.0),  // Yellow
    vec3(0.0, 1.0, 0.0),  // Green
    vec3(0.0, 0.0, 1.0),  // Blue
    vec3(0.3, 0.0, 0.5),  // Indigo
    vec3(0.5, 0.0, 1.0)   // Violet
};

void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    float time = TIME;
    
    // Calculate animated radius values for 7 circles (plus one zero radius)
    float radius[8];
    radius[0] = 0.0;
    radius[1] = exp2(log(mod(time * (0.5 * speed), 10.0 / speed) / 9.0));
    radius[2] = exp2(log(mod(time * (1.0 * speed), 10.0 / speed) / 9.0));
    radius[3] = exp2(log(mod(time * (1.5 * speed), 10.0 / speed) / 9.0));
    radius[4] = exp2(log(mod(time * (2.0 * speed), 10.0 / speed) / 9.0));
    radius[5] = exp2(log(mod(time * (2.5 * speed), 10.0 / speed) / 9.0));
    radius[6] = exp2(log(mod(time * (3.0 * speed), 10.0 / speed) / 9.0));
    radius[7] = exp2(log(mod(time * (3.5 * speed), 10.0 / speed) / 9.0));
    
    // Initialize color indices
    int ids[7];
    ids[0] = 0; ids[1] = 1; ids[2] = 2; ids[3] = 3; ids[4] = 4; ids[5] = 5; ids[6] = 6;
    
    // Bubble sort to order circles by radius (maintaining color associations)
    float aux;
    int auxi;
    for (int a = 1; a < 8; a++) {
        for (int b = 1; b < 8; b++) {
            if (radius[a] < radius[b]) {
                // Swap radius values
                aux = radius[a];
                radius[a] = radius[b];
                radius[b] = aux;
                
                // Swap corresponding color indices
                auxi = ids[a - 1];
                ids[a - 1] = ids[b - 1];
                ids[b - 1] = auxi;
            }
        }
    }
    
    // Normalized pixel coordinates (centered)
    vec2 uv = FRAGCOORD.xy / resolution.y - 0.5 * vec2(resolution.x / resolution.y, 1.0);
	uv += vec2(center_offset_x, center_offset_y); // Allow center adjustment
    
    // Start with the outermost color
    vec3 col = rainbow_colors[6];
    
    // Calculate distance from center
    float dist = length(uv);
    
    // Determine which color ring we're in
    int idx;
    for (float z = 0.5; z < 4.0; z += 0.5) {
        idx = int(z * 2.0);
        if ((radius[idx - 1] <= dist) && (dist <= radius[idx])) {
            col = rainbow_colors[ids[idx - 1]];
        }
        
        // Draw white outlines around each expanding circle
        float current_radius = exp2(log(mod(time * z * speed, 10.0 / speed) / 9.0));
        if (abs(dist - current_radius) < outline_thickness) {
            col = vec3(1.0); // White outline
        }
    }
    
    COLOR = vec4(col, 1.0);
}
