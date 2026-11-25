shader_type sky;

// Static blue-hour sky. The horizon is diffuse in all directions.
uniform vec3 zenith : source_color = vec3(0.026, 0.040, 0.076);
uniform vec3 horizon : source_color = vec3(0.113, 0.145, 0.207);

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
    vec3 base = mix(horizon, zenith, pow(clamp(altitude, 0.0, 1.0), 0.55));
    float bank = noise_field(EYEDIR.xz * 4.8 + EYEDIR.y * vec2(1.0, 3.0));
    COLOR = base * mix(0.86, 1.0, bank);
}
