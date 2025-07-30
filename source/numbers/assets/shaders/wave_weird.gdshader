shader_type spatial;
render_mode unshaded;

// Controls the frequency of the waves
uniform float amount : hint_range(0.0, 100.0, 0.01) = 20.0;

// Controls the overall distortion intensity
uniform float move = 1.0;

// Base height of the sinusoidal bands
uniform float bandsize = 0.1;

// Speed of wave movement
uniform float speed = 1.0;

void vertex() {
    // Center UV to create symmetrical effect
    vec2 uv = UV - 0.5;

    // Adds movement with time
    uv.y += TIME * speed;

    // Calculates animated sinusoidal value
    float wave = sin(uv.y * amount) + bandsize;

    // Applies distortion along the sphere normal
    VERTEX += NORMAL * wave * move;
}

void fragment() {
    // Center UV to keep the same pattern as vertex shader
    vec2 uv = UV - 0.5;

    // Animates the waves on the Y axis
    uv.y += TIME * speed;

    // Creates the same sinusoidal function to draw the pattern
    float wave = sin(uv.y * amount) + bandsize;

    // Sets the band color based on the sinusoidal value
    ALBEDO = vec3(wave);
}
