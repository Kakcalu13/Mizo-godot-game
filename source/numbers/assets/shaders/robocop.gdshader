shader_type sky;

// Converted ED-209 Robocop shader by dean_the_coder for Sky shader
// Original: https://www.shadertoy.com/view/wsGczG
// License: Creative Commons Attribution-NonCommercial-ShareAlike 3.0

// Animation control uniforms
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;
uniform float scene_time : hint_range(0.0, 55.0) = 0.0;
uniform bool use_custom_time = false;
uniform bool enable_antialiasing = false;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;

struct MarchData {
    float d;
    vec3 mat; // RGB material color
    float specPower; // 0: None, 30.0: Shiny
};

// 2D rotation matrix
mat2 rot(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(vec2(c, s), vec2(-s, c));
}

float remap(float f, float in1, float in2, float out1, float out2) {
    return mix(out1, out2, clamp((f - in1) / (in2 - in1), 0.0, 1.0));
}

// SDF primitive functions
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdChamferedCube(vec3 p, vec3 r, float c) {
    float cube = sdBox(p, r);
    p.xz *= rot(0.78525);
    r.xz *= -c / 1.41 + 1.41;
    return max(cube, sdBox(p, r));
}

float sdTriPrism(vec3 p, vec2 h) {
    vec3 q = abs(p);
    return max(q.z - h.y, max(q.x * 0.866025 + p.y * 0.5, -p.y) - h.x * 0.5);
}

float sdCappedCone(vec3 p, vec3 a, vec3 b, float ra, float rb) {
    float rba = rb - ra;
    float baba = dot(b - a, b - a);
    float papa = dot(p - a, p - a);
    float paba = dot(p - a, b - a) / baba;
    float x = sqrt(papa - paba * paba * baba);
    float cax = max(0.0, x - ((paba < 0.5) ? ra : rb));
    float cay = abs(paba - 0.5) - 0.5;
    float f = clamp((rba * (x - ra) + paba * baba) / (rba * rba + baba), 0.0, 1.0);
    float cbx = x - ra - f * rba;
    float cby = paba - f;
    return ((cbx < 0.0 && cay < 0.0) ? -1.0 : 1.0) * sqrt(min(cax * cax + cay * cay * baba, cbx * cbx + cby * cby * baba));
}

float sdCappedCylinder(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xy), p.z)) - vec2(h, r);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)) - r;
}

float sdOctogon(vec2 p, float r) {
    const vec3 k = vec3(-0.92387953, 0.38268343, 0.41421356);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= 2.0 * min(dot(vec2(-k.x, k.y), p), 0.0) * vec2(-k.x, k.y);
    p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}

vec3 getRayDir(vec3 ro, vec3 lookAt, vec2 uv) {
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(vec3(0, 1, 0), forward));
    return normalize(forward + right * uv.x + cross(forward, right) * uv.y);
}

MarchData minResult(MarchData a, MarchData b) {
    if (a.d < b.d) return a;
    return b;
}

void setBodyMaterial(inout MarchData mat) {
    mat.mat = vec3(0.36, 0.45, 0.5);
    mat.specPower = 30.0;
}

float legWalkAngle(float f, float edWalk) {
    return sin(edWalk * 3.141 * 6.0 * f) * 0.2;
}

float edZ(float edWalk) {
    return mix(5.0, -2.0, edWalk);
}

float fireShock(float localEdShoot) {
    return abs(sin(localEdShoot * 78.5375));
}

float headSphere(vec3 p) {
    return (length(p / vec3(1, 0.8, 1)) - 1.0) * 0.8;
}

MarchData headVisor(vec3 p, float h, float bump) {
    bump *= sin(p.x * 150.0) * sin(p.y * 150.0) * 0.002;
    MarchData result;
    result.d = sdBox(p, vec3(1, h, 2));
    result.d = max(mix(result.d, headSphere(p), 0.57), -p.y) - bump;
    result.mat = vec3(0.05);
    result.specPower = 30.0;
    return result;
}

MarchData headLower(vec3 p, float gunsUp) {
    vec3 op = p;

    // Start by mirroring the visor
    MarchData r = headVisor(p * vec3(0.95, -1.4, 0.95), 1.0, 0.0);

    // Add the side panels
    r.d = min(r.d, max(max(headVisor((p + vec3(0, 0.01, 0)) * vec3(0.95), 1.0, 0.0).d, p.y - 0.35), p.y * 0.625 - p.z - 0.66));

    // Wings
    p.xy *= rot(0.075 * (gunsUp - 1.0) * sign(p.x));
    p.x = abs(p.x) - 1.33;
    p.y -= 0.1 - p.x * 0.1;
    r.d = min(r.d, sdBox(p, vec3(0.4, 0.06 * (1.0 - p.x), 0.3 - p.x * 0.2)));
    p = op;

    // Cut out mouth grill
    p.y = abs(abs(p.y + 0.147) - 0.0556) - 0.0278;
    r.d = max(r.d, -sdBox(p + vec3(0, 0, 1.5), vec3(mix(0.25, 0.55, -op.y), 0.015, 0.1)));

    // Cheeks
    p = op;
    p.y = abs(p.y + 0.16) - 0.06;
    p.z -= -1.1;
    r.d = max(r.d, -max(max(sdCappedCylinder(p.xzy, 1.0, 0.03), -sdCappedCylinder(p.xzy, 0.55, 1.0)), p.z + 0.2));
    setBodyMaterial(r);
    return r;
}

MarchData gunPod(vec3 p, float localEdShoot, inout float glow) {
    MarchData r;
    setBodyMaterial(r);
    p.yz += vec2(0.1, 0.45);

    // Carousel
    vec3 pp = p;
    pp.z = abs(pp.z) - 0.5;
    r.d = sdCappedCone(pp, vec3(0), vec3(0, 0, -0.1), 0.35 - 0.1, 0.35);
    r.d = min(r.d, sdCappedCylinder(p, 0.35, 0.4));

    // Triangle nobble
    pp = vec3(p.x, 0.28 - p.y, p.z);
    r.d = min(r.d, sdTriPrism(pp, vec2(0.1, 0.5)));

    // Square outriggers
    pp = p;
    pp.x = abs(p.x);
    pp.xy *= rot(0.78525);
    float fs;
    float bump = sign(sin(pp.z * 33.3)) * 0.003;
    float d = sdBox(pp, vec3(0.1 - bump, 0.38 - bump, 0.34)) - 0.02;

    // Barrels
    pp = p - vec3(0, 0, -0.6);
    pp.x = abs(pp.x) - 0.1;
    d = min(min(min(d, sdCappedCylinder(pp, 0.06, 0.15)), sdCappedCylinder(pp + vec3(0, 0.12, -0.05), 0.06, 0.05)), sdBox(p + vec3(0, 0, 0.54), vec3(0.1, 0.06, 0.04)));
    if (d < r.d) {
        d = max(d, -sdCappedCylinder(pp + vec3(0, 0, 0.1), 0.03, 0.2));
        r.d = d;
        r.mat = vec3(0.02);
    }

    // Muzzle flash
    fs = fireShock(localEdShoot);
    if (fs > 0.5) {
        d = sdCappedCylinder(pp, 0.01 + pp.z * 0.05, fract(fs * 3322.423) * 0.5 + 0.9);
        if (d < r.d) {
            r.d = d;
            r.mat = vec3(1);
            glow += 0.1 / (0.01 + d * d * 400.0) * glow_intensity;
        }
    }

    return r;
}

MarchData arms(vec3 p, float gunsUp, float gunsForward, float localEdShoot, inout float glow) {
    const vec3 wrist = vec3(1.5, 0, 0) - vec3(0, 0, 0.3);
    MarchData r;
    setBodyMaterial(r);

    // Position origin
    p.x = abs(p.x);
    p.yz += vec2(0.24, 0);
    p.xy *= rot(0.15 * (gunsUp - 1.0));

    // Shoulder and forearm
    r.d = min(sdCapsule(p, vec3(0), vec3(1.5, 0, 0), 0.2), sdCapsule(p, vec3(1.5, 0, 0), wrist, 0.2));

    // Guns
    p -= wrist;
    p.z -= gunsForward * 0.15;
    return minResult(r, gunPod(p, localEdShoot, glow));
}

float toe(vec3 p) {
    p.yz += vec2(0.1, 0.32);
    return max(sdBox(p, vec3(0.3 + 0.2 * (p.z - 0.18) - p.y * 0.228, 0.3 + 0.2 * cos((p.z - 0.18) * 3.69), 0.35)), 0.1 - p.y);
}

float foot(vec3 p) {
    p.z += 0.8;
    p.yz *= rot(0.86);
    float d = toe(p);
    p.xz *= rot(1.57);
    p.x -= 0.43;
    p.z = 0.25 - abs(p.z);
    return min(d, toe(p));
}

MarchData waist(vec3 p, float edWalk) {
    MarchData r;
    setBodyMaterial(r);
    p.y += 0.65;
    p.yz *= rot(-0.2);
    float bump, d;
    float legAngle = legWalkAngle(1.0, edWalk);
    p.xy *= rot(legAngle * 0.3);
    vec3 pp = p;
    pp.y += 0.3;
    r.d = max(sdCappedCylinder(pp.zyx, 0.5, 0.5), p.y + 0.15);

    // Thorax
    bump = 0.5 - abs(sin(p.y * 40.0)) * 0.03;
    d = sdBox(p, vec3(bump, 0.15, bump));

    // Leg joins
    bump = 0.3 - abs(sin(p.x * 40.0)) * 0.03;
    pp.y += 0.18;
    d = min(d, sdCappedCylinder(pp.zyx, bump, 0.75));

    // Hips
    pp.x = abs(pp.x);
    pp.yz *= rot(-0.58525 + legAngle * sign(p.x));
    pp.x -= 0.98;
    r.d = min(r.d, max(sdCappedCylinder(pp.zyx, 0.4, 0.24), -pp.y));
    r.d = min(r.d, sdBox(pp, vec3(0.24, 0.2, 0.14 + 0.2 * pp.y)));

    // Thigh pistons
    p = pp;
    pp.xz = abs(pp.xz) - vec2(0.12, 0.25);
    r.d = min(r.d, max(min(sdCappedCylinder(pp.xzy, 0.1, 0.325), sdCappedCylinder(pp.xzy, 0.05, 0.5)), pp.y));

    // Knees
    p.y += 0.68;
    r.d = min(r.d, sdBox(p, vec3(sign(abs(p.y) - 0.04) * 0.005 + 0.26, 0.2, 0.34)));
    if (d < r.d) {
        // Black segments
        r.d = d;
        r.mat = vec3(0.02);
    }

    return r;
}

MarchData legs(vec3 p, float edWalk) {
    MarchData r;
    setBodyMaterial(r);
    float silver;
    float legAngle = legWalkAngle(1.0, edWalk);
    p.z += 0.27;
    p.yz *= rot(legAngle * sign(p.x));
    p.z -= 0.27;
    p.y += 0.65;
    p.yz *= rot(-0.2);
    p.xy *= rot(legAngle * 0.3);
    vec3 cp;
    vec3 pp = p;
    pp.x = abs(pp.x);
    pp.y += 0.48;
    pp.yz *= rot(-0.58525);
    pp.x -= 0.98;
    cp = pp;
    p = pp;
    pp.xz = abs(pp.xz) - vec2(0.12, 0.25);
    p.y += 0.68;

    // Thighs
    p.xy = abs(p.xy) - 0.12;
    silver = sdBox(p, vec3(0.07, 0.05, 1.2));

    // Leg end cap
    cp -= vec3(0, -0.7, 0);
    r.d = sdBox(cp - vec3(0, 0, 1.15), vec3(0.17, 0.17, 0.07)) - 0.04;

    // Shin
    cp.z++;
    r.d = min(r.d, sdChamferedCube(cp.xzy, vec2(0.28 - sign(abs(cp.z) - 0.3) * 0.01, 0.5).xyx, 0.18));

    // Feet
    r.d = min(r.d, foot(cp));
    if (silver < r.d) {
        r.d = silver;
        r.mat = vec3(0.8);
    }

    return r;
}

MarchData ed209(vec3 p, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float localEdShoot, inout float glow) {
    p.yz += vec2(legWalkAngle(2.0, edWalk) * 0.2 + 0.1, -edZ(edWalk));
    MarchData r = legs(p, edWalk);
    float f = min(stretch * 2.0, 1.0);
    float slide = f < 0.5 ? smoothstep(0.0, 0.5, f) : (1.0 - smoothstep(0.5, 1.0, f) * 0.2);
    p.yz -= slide * 0.5;
    r = minResult(r, waist(p, edWalk));
    p.yz *= rot(0.1 * (-edDown + legWalkAngle(2.0, edWalk) + smoothstep(0.0, 1.0, clamp((stretch - 0.5) * 6.0, 0.0, 1.0)) - 1.0));
    p.xz *= rot(edTwist * 0.2);
    return minResult(minResult(minResult(r, headLower(p, gunsUp)), headVisor(p, 0.8, 1.0)), arms(p, gunsUp, gunsForward, localEdShoot, glow));
}

MarchData room(vec3 p, float doorOpen) {
    const vec3 frameInner = vec3(2.8, 2.6, 0.1);
    MarchData r;
    r.mat = vec3(0.4);
    r.specPower = 1e7;
    vec2 xy = p.xy - vec2(0, 2);
    p.x = abs(p.x);
    p.yz += vec2(0.5, -3.4);
    float doorFrame, doorWidth, door, d;
    float doorHole = sdBox(p, frameInner + vec3(0, 0, 1));
    float backWall = length(p.z - 8.0);
    r.d = min(backWall, max(length(p.z), -doorHole + 0.1));
    if (r.d == backWall) {
        float ocp = min(abs(sdOctogon(xy, 2.6)), abs(sdOctogon(xy, 1.9)));
        ocp = min(max(ocp, min(0.7 - abs(xy.x + 1.2), -xy.y)), max(abs(sdOctogon(xy, 1.2)), min(xy.x, 0.7 - abs(xy.y))));
        if (ocp < 0.3) r.mat = vec3(0.39, 0.57, 0.71);
    }

    doorFrame = max(sdBox(p, frameInner + vec3(0.4, 0.4, 0.1)), -doorHole);
    doorWidth = frameInner.x * 0.5;
    p.x -= frameInner.x;
    p.xz *= rot(doorOpen * 2.1);
    p.x += doorWidth;
    door = sdBox(p, vec3(doorWidth, frameInner.yz));
    p = abs(p) - vec3(doorWidth * 0.5, 1.1, 0.14);
    d = min(doorFrame, max(door, -max(sdBox(p, vec3(0.45, 0.9, 0.1)), -sdBox(p, vec3(0.35, 0.8, 1)))));
    if (d < r.d) {
        r.d = d;
        r.mat = vec3(0.02, 0.02, 0.024);
        r.specPower = 10.0;
    }

    return r;
}

// Map the scene using SDF functions
MarchData map(vec3 p, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot, inout float glow) {
    MarchData r = minResult(room(p, doorOpen), ed209(p, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, localEdShoot, glow));
    float gnd = length(p.y + 3.0);
    if (gnd < r.d) {
        r.d = gnd;
        r.mat = vec3(0.1);
    }
    return r;
}

float calcShadow(vec3 p, vec3 lightPos, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot) {
    vec3 rd = normalize(lightPos - p);
    float res = 1.0;
    float t = 0.1;
    for (float i = 0.0; i < 30.0; i++) {
        float tmpGlow = 0.0; // temporary glow for shadow calc
        float h = map(p + rd * t, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d;
        res = min(res, 12.0 * h / t);
        t += h;
        if (res < 0.001 || t > 25.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

vec3 calcNormal(vec3 p, float t, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot) {
    float d = 0.01 * t * 0.33;
    vec2 e = vec2(1, -1) * 0.5773 * d;
    float tmpGlow = 0.0; // temporary glow for normal calc
    return normalize(e.xyy * map(p + e.xyy, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d +
                     e.yyx * map(p + e.yyx, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d +
                     e.yxy * map(p + e.yxy, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d +
                     e.xxx * map(p + e.xxx, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d);
}

float ao(vec3 p, vec3 n, float h, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot) {
    float tmpGlow = 0.0; // temporary glow for AO calc
    return clamp(map(p + h * n, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, tmpGlow).d / h, 0.0, 1.0);
}

vec3 vignette(vec3 col, vec2 screen_uv) {
    col *= 0.5 + 0.5 * pow(16.0 * screen_uv.x * screen_uv.y * (1.0 - screen_uv.x) * (1.0 - screen_uv.y), 0.4);
    return col;
}

vec3 applyLighting(vec3 p, vec3 rd, float d, MarchData data, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot) {
    vec3 sunP = vec3(10, 10, -10);
    vec3 sunDir = normalize(sunP - p);
    vec3 n = calcNormal(p, d, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot);

    // Primary light
    float primary = max(0.0, dot(sunDir, n));
    float bounce = max(0.0, dot(-sunDir, n)) * 0.3;
    float spe = pow(max(0.0, dot(rd, reflect(sunDir, n))), data.specPower) * 2.0;
    float fre = smoothstep(0.7, 1.0, 1.0 + dot(rd, n));
    float fog = exp(-length(p) * 0.05);

    primary /= pow(length(sunP - p) / 15.0, 3.0);
    if (data.specPower > 1e6) spe *= 0.0;

    // Combine
    primary *= mix(0.2, 1.0, calcShadow(p, vec3(10, 10, -10), stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot));
    return mix(data.mat * ((primary + bounce) * ao(p, n, 0.33, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot) + spe) * vec3(2, 1.6, 1.7), vec3(0.01), fre) * fog;
}

vec3 getSceneColor(vec3 ro, vec3 rd, float stretch, float gunsUp, float gunsForward, float edWalk, float edTwist, float edDown, float doorOpen, float localEdShoot, inout float glow) {
    // Raymarch
    vec3 p;
    float d = 0.01;
    MarchData h;
    for (float steps = 0.0; steps < 120.0; steps++) {
        p = ro + rd * d;
        h = map(p, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, glow);
        if (abs(h.d) < 0.0015 * d) break;
        if (d > 64.0) return vec3(0); // Distance limit reached
        d += h.d;
    }

    // Lighting
    return applyLighting(p, rd, d, h, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot) + fireShock(localEdShoot) * 0.3 + glow;
}

void sky() {
    // Animation state variables (local scope)
    float stretch = 0.0;
    float gunsUp = 0.0;
    float gunsForward = 0.0;
    float edWalk = 0.0;
    float edTwist = 0.0;
    float edDown = 0.0;
    float localEdShoot = 0.0;
    float doorOpen = 0.0;
    float glow = 0.0;

    // Initialize animation variables
    edWalk = 1.0;
    edTwist = 0.0;
    edDown = 0.0;
    localEdShoot = 0.0;
    doorOpen = 1.0;
    stretch = 1.0;

    // Camera setup
    vec3 ro, lookAt, col;
    float startScene, endScene, dim;
    float time = use_custom_time ? scene_time : mod(TIME * time_scale, 55.0);

    // Scene 1: Door opening and robot emergence
    if (time < 12.0) {
        startScene = 0.0;
        endScene = 12.0;
        edWalk = 0.0;
        ro = vec3(0, -1.5, -0.625);
        lookAt = vec3(0, -1, edZ(edWalk));
        doorOpen = smoothstep(0.0, 1.0, time / 5.0);
        stretch = remap(time, 7.0, 10.0, 0.0, 1.0);
    }
    // Scene 2: Walking sequence
    else if (time < 25.0) {
        startScene = 12.0;
        endScene = 25.0;
        float t = time - startScene;
        edWalk = smoothstep(0.0, 1.0, remap(t, 3.0, 8.0, 0.0, 1.0));
        ro = vec3(-0.5 * cos(t * 0.7), 0.5 - t * 0.1, edZ(edWalk) - 3.0);
        lookAt = vec3(0, 0, edZ(edWalk));
    }
    // Scene 3: Side view
    else if (time < 29.0) {
        startScene = 25.0;
        endScene = 29.0;
        ro = vec3(-2, 0.5 + (time - startScene) * 0.1, edZ(edWalk) - 3.0);
        lookAt = vec3(0, 0, edZ(edWalk));
    }
    // Scene 4: Robot lowering
    else if (time < 37.0) {
        startScene = 29.0;
        endScene = 37.0;
        float t = time - startScene;
        ro = vec3(1.5, -1.0 - t * 0.05, edZ(edWalk) - 5.0);
        lookAt = vec3(0, -1, edZ(edWalk));
        stretch = remap(t, 2.0, 5.0, 1.0, 0.0);
    }
    // Scene 5: Final shooting sequence
    else if (time < 55.0) {
        startScene = 37.0;
        endScene = 55.0;
        float t = time - startScene;
        ro = vec3(-1.8, -0.5, edZ(edWalk) - 2.5);
        stretch = remap(t, 2.0, 3.0, 0.0, 1.0) - remap(t, 11.5, 14.5, 0.0, 1.0);
        lookAt = vec3(0, stretch * 0.5 - 0.5, edZ(edWalk));
        edTwist = remap(t, 3.0, 3.2, 0.0, 1.0) * stretch;
        edDown = remap(t, 3.2, 3.4, 0.0, 1.0) * stretch;
        localEdShoot = t <= 9.5 ? remap(t, 4.0, 9.5, 0.0, 1.0) : 0.0;
    }

    // Calculate derived animation values
    gunsUp = smoothstep(0.0, 1.0, clamp((stretch - 0.66) * 6.0, 0.0, 1.0));
    gunsForward = smoothstep(0.0, 1.0, clamp((stretch - 0.83) * 6.0, 0.0, 1.0)) + fireShock(localEdShoot) * 0.5;

    dim = 1.0 - cos(min(1.0, 2.0 * min(abs(time - startScene), abs(time - endScene))) * 1.5705);
    col = vec3(0);

    // Use EYEDIR as the ray direction (this is what sky shaders provide)
    vec3 rd = EYEDIR;

    // Anti-aliasing
    if (enable_antialiasing) {
        // Note: For sky shaders, we can't do manual anti-aliasing easily
        // since we don't have FRAGCOORD, so we'll skip this for sky version
        col = getSceneColor(ro, rd, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, glow);
    } else {
        col = getSceneColor(ro, rd, stretch, gunsUp, gunsForward, edWalk, edTwist, edDown, doorOpen, localEdShoot, glow);
    }

    // Apply post-processing
    col = vignette(pow(col * dim, vec3(0.4545)), SCREEN_UV);

    // Output to sky
    COLOR = col;
}
