shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool ps1_pixels_enabled = false;
uniform float ps1_pixel_strength : hint_range(0.0, 1.0) = 0.55;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.34;
uniform float poster_levels : hint_range(4.0, 32.0) = 18.0;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.14;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float blue_excess(vec3 c) {
    return c.b - max(c.r, c.g);
}

void fragment() {
    vec2 scene_uv = SCREEN_UV;
    if (ps1_pixels_enabled && ps1_pixel_strength > 0.0) {
        float screen_height = 1.0 / SCREEN_PIXEL_SIZE.y;
        float block_size = mix(1.0, max(1.0, screen_height / 160.0), ps1_pixel_strength);
        vec2 block_uv = SCREEN_PIXEL_SIZE * block_size;
        scene_uv = (floor(SCREEN_UV / block_uv) + 0.5) * block_uv;
    }

    vec3 original = texture(scene_color, scene_uv).rgb;

    vec2 offset = SCREEN_PIXEL_SIZE * 1.5;
    float center_l = luminance(original);
    float right_l = luminance(texture(scene_color, scene_uv + vec2(offset.x, 0.0)).rgb);
    float up_l = luminance(texture(scene_color, scene_uv + vec2(0.0, offset.y)).rgb);
    float contrast = abs(center_l - right_l) + abs(center_l - up_l);
    float sky_blue = blue_excess(original);
    float sky_mask = smoothstep(0.012, 0.055, sky_blue)
        * (1.0 - smoothstep(0.012, 0.055, contrast))
        * (1.0 - smoothstep(0.64, 0.88, scene_uv.y));

    vec3 scene = original;
    if (ps1_pixels_enabled && ps1_pixel_strength > 0.0) {
        // Use the native sample when snapping crosses a contrasting twilight silhouette.
        vec3 native_color = texture(scene_color, SCREEN_UV).rgb;
        float native_blue = blue_excess(native_color);
        float twilight = smoothstep(0.012, 0.04, max(sky_blue, native_blue))
            * (1.0 - smoothstep(0.64, 0.88, SCREEN_UV.y));
        float silhouette = smoothstep(0.014, 0.042, abs(sky_blue - native_blue));
        float edge_keep = twilight * silhouette;
        scene = mix(scene, native_color, edge_keep);
        sky_mask = mix(sky_mask, smoothstep(0.012, 0.055, native_blue), edge_keep);
    }

    // Modest posterization and cel shading on solid objects.
    vec3 poster = floor(scene * poster_levels + 0.5) / poster_levels;
    scene = mix(scene, poster, cel_strength * mix(0.50, 0.06, sky_mask));
    float band = floor(luminance(scene) * 5.0) / 5.0;
    scene *= mix(1.0, 0.86 + band * 0.24, cel_strength * (1.0 - 0.96 * sky_mask));

    float edge = smoothstep(0.05, 0.17, contrast);
    scene *= 1.0 - edge * edge_strength * (1.0 - sky_mask);

    vec2 corners = scene_uv * 2.0 - 1.0;
    float vignette = 1.0 - 0.10 * smoothstep(0.35, 1.85, dot(corners, corners));
    scene *= mix(vignette, 1.0, sky_mask);

    COLOR = vec4(clamp(scene, 0.0, 1.0), 1.0);
}
