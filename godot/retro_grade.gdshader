shader_type canvas_item;
render_mode unshaded;

// More pronounced pixel art on geometry, but retain the previously-lit sky.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height : hint_range(240.0, 1080.0) = 320.0;
uniform float pixel_mix : hint_range(0.0, 1.0) = 0.94;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.34;
uniform float poster_levels : hint_range(4.0, 32.0) = 18.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.14;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    float h = min(virtual_height, 1.0 / SCREEN_PIXEL_SIZE.y);
    vec2 grid = vec2(h * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, h);
    vec2 pixel_uv = (floor(SCREEN_UV * grid) + 0.5) / grid;

    vec3 original = texture(scene_color, SCREEN_UV).rgb;
    vec3 pixelated = texture(scene_color, pixel_uv).rgb;

    vec2 offset = SCREEN_PIXEL_SIZE * 1.5;
    float center_l = luminance(original);
    float right_l = luminance(texture(scene_color, SCREEN_UV + vec2(offset.x, 0.0)).rgb);
    float up_l = luminance(texture(scene_color, SCREEN_UV + vec2(0.0, offset.y)).rgb);
    float contrast = abs(center_l - right_l) + abs(center_l - up_l);
    float sky_blue = original.b - max(original.r, original.g);
    float sky_mask = smoothstep(0.012, 0.055, sky_blue)
        * (1.0 - smoothstep(0.012, 0.055, contrast))
        * (1.0 - smoothstep(0.64, 0.88, SCREEN_UV.y));

    // Sky is mostly the untouched procedural gradient; houses keep hard pixels.
    vec3 scene = mix(original, pixelated, pixel_mix);
    scene = mix(scene, mix(original, pixelated, 0.26), sky_mask);

    // Modest posterization and cel shading on solid objects.
    vec3 poster = floor(scene * poster_levels + 0.5) / poster_levels;
    scene = mix(scene, poster, cel_strength * mix(0.50, 0.06, sky_mask));
    float band = floor(luminance(scene) * 5.0) / 5.0;
    scene *= mix(1.0, 0.86 + band * 0.24, cel_strength * (1.0 - 0.96 * sky_mask));

    float edge = smoothstep(0.05, 0.17, contrast);
    scene *= 1.0 - edge * edge_strength * (1.0 - sky_mask);

    vec2 corners = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - 0.10 * smoothstep(0.35, 1.85, dot(corners, corners));
    scene *= mix(vignette, 1.0, sky_mask);

    COLOR = vec4(clamp(scene, 0.0, 1.0), 1.0);
}
