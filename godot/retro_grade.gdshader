shader_type canvas_item;
render_mode unshaded;

// Deliberately visible low-resolution texture, with the original image
// retained slightly so fine roof silhouettes do not turn into blur.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height : hint_range(240.0, 1080.0) = 420.0;
uniform float pixel_mix : hint_range(0.0, 1.0) = 0.88;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.58;
uniform float poster_levels : hint_range(4.0, 32.0) = 16.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.26;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    float h = min(virtual_height, 1.0 / SCREEN_PIXEL_SIZE.y);
    vec2 grid = vec2(h * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, h);
    vec2 snapped = (floor(SCREEN_UV * grid) + 0.5) / grid;
    vec3 original = texture(scene_color, SCREEN_UV).rgb;
    vec3 scene = mix(original, texture(scene_color, snapped).rgb, pixel_mix);

    // Quantize luminance more than chroma to preserve the murky dusk palette.
    float lum = luminance(scene);
    float quantized = floor(lum * poster_levels + 0.5) / poster_levels;
    scene *= mix(1.0, quantized / max(lum, 0.018), 0.52 * cel_strength);
    scene = mix(scene, floor(scene * poster_levels + 0.5) / poster_levels, 0.45 * cel_strength);

    // Stylized lighting bands: gentle self-shading without flattening textures.
    float band = floor(luminance(scene) * 5.0) / 5.0;
    scene *= mix(1.0, 0.83 + band * 0.27, cel_strength);

    // Edge darkening from the *unpixelated* source avoids chunky halos.
    vec2 texel = SCREEN_PIXEL_SIZE * 1.5;
    float center_l = luminance(original);
    float dx = abs(center_l - luminance(texture(scene_color, SCREEN_UV + vec2(texel.x, 0.0)).rgb));
    float dy = abs(center_l - luminance(texture(scene_color, SCREEN_UV + vec2(0.0, texel.y)).rgb));
    float edge = smoothstep(0.045, 0.18, dx + dy);
    scene *= 1.0 - edge * edge_strength;

    vec2 corners = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - 0.12 * smoothstep(0.3, 1.9, dot(corners, corners));
    COLOR = vec4(clamp(scene * vignette, 0.0, 1.0), 1.0);
}
