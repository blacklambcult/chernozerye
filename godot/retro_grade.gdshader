shader_type canvas_item;
render_mode unshaded;

// Stable pixel grid + restrained cel color bands for a crunchy, sharp night.
// Pixelation never rescales the whole 3D render: HUD remains native resolution.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height : hint_range(240.0, 1080.0) = 420.0;
uniform float pixel_mix : hint_range(0.0, 1.0) = 0.90;
uniform float poster_strength : hint_range(0.0, 1.0) = 0.55;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.42;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.23;

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    float h = min(virtual_height, 1.0 / SCREEN_PIXEL_SIZE.y);
    vec2 grid = vec2(h * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, h);
    vec2 pixel = floor(SCREEN_UV * grid);
    vec2 snapped_uv = (pixel + 0.5) / grid;
    vec3 fine = texture(scene_color, SCREEN_UV).rgb;
    vec3 coarse = texture(scene_color, snapped_uv).rgb;

    // Mostly snapped samples: sharp pixels, not a blurry low-res overlay.
    vec3 color = mix(fine, coarse, pixel_mix);
    float tone = luma(color);
    // 18 palette steps per channel with mild ordered dithering at grid scale.
    vec2 phase = mod(pixel, 2.0);
    float bayer = (2.0 * mod(phase.x + phase.y, 2.0) + phase.y) * 0.25;
    vec3 poster = floor(color * 18.0 + 0.35 + bayer * 0.30) / 18.0;
    color = mix(color, poster, poster_strength);

    // Gentle luminance bands evoke toon/self shading on existing geometry.
    float stepped = floor(tone * 6.0 + 0.50) / 6.0;
    float band = clamp(stepped / max(tone, 0.065), 0.78, 1.15);
    color *= mix(1.0, band, cel_strength);

    // Screen-space contour at true pixel boundaries; prevents thick black halos.
    vec2 offset_uv = SCREEN_PIXEL_SIZE * 1.55;
    float gradient = max(abs(luma(texture(scene_color, SCREEN_UV + vec2(offset_uv.x, 0.0)).rgb) - luma(fine)),
                         abs(luma(texture(scene_color, SCREEN_UV + vec2(0.0, offset_uv.y)).rgb) - luma(fine)));
    float edge = smoothstep(0.055, 0.18, gradient);
    color *= 1.0 - outline_strength * edge;

    vec2 radial = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - 0.10 * smoothstep(0.28, 1.9, dot(radial, radial));
    COLOR = vec4(clamp(color * vignette, 0.0, 1.0), 1.0);
}
