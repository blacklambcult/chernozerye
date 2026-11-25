shader_type sky;

// Directional, static cloud banks. No time input or volumetric pass.
uniform vec3 zenith : source_color = vec3(0.055, 0.071, 0.125);
uniform vec3 horizon : source_color = vec3(0.26, 0.29, 0.39);
uniform vec3 afterglow : source_color = vec3(0.51, 0.32, 0.27);
uniform vec3 cloud_color : source_color = vec3(0.095, 0.103, 0.165);

float hash_point(vec2 p) {
    vec3 a = fract(vec3(p.xyx) * 0.1031);
    a += dot(a, a.yzx + 33.33);
    return fract((a.x + a.y) * a.z);
}

float noise_field(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash_point(i), hash_point(i + vec2(1.0, 0.0)), w.x),
        mix(hash_point(i + vec2(0.0, 1.0)), hash_point(i + 1.0), w.x), w.y);
}

void sky() {
    float altitude = max(EYEDIR.y, 0.0);
    float east = max(dot(EYEDIR.xz, vec2(0.90, -0.44)), 0.0);
    float glow = east * east * exp(-altitude * 7.0);
    vec3 lit_horizon = mix(horizon, afterglow, glow * 0.64);
    vec3 base = mix(lit_horizon, zenith, smoothstep(0.0, 0.72, altitude));
    vec2 p = EYEDIR.xz * (2.8 / (altitude + 0.26)) + vec2(5.5, 11.0);
    p *= vec2(0.57, 1.36);
    float cloud = noise_field(p) * 0.72 + noise_field(p * 2.17 + 3.2) * 0.28;
    float coverage = smoothstep(0.35, 0.67, cloud) * smoothstep(0.0, 0.11, altitude);
    vec3 bank = mix(cloud_color, horizon * 0.75, glow * 0.22);
    COLOR = mix(base, bank, coverage * 0.86);
}
