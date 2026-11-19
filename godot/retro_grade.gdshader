shader_type canvas_item;
render_mode unshaded;

// Preserve fine silhouettes; pixel structure is a texture, not the entire image.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height : hint_range(360.0, 1080.0) = 640.0;
uniform float pixel_mix : hint_range(0.0, 1.0) = 0.48;
uniform float cel_strength : hint_range(0.0, 1.0) = 0.36;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    float h = min(virtual_height, 1.0 / SCREEN_PIXEL_SIZE.y);
    vec2 grid = vec2(h * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, h);
    vec2 px = floor(SCREEN_UV * grid);
    vec2 snapped = (px + 0.5) / grid;
    vec3 original = texture(scene_color, SCREEN_UV).rgb;
    vec3 coarse = texture(scene_color, snapped).rgb;
    vec3 scene = mix(original, coarse, pixel_mix);

    // Soft posterization without destroying distant roof lines or tree branches.
    vec3 stepped = floor(scene * 42.0 + 0.5) / 42.0;
    scene = mix(scene, stepped, cel_strength);

    // Stylized dark contour only where the original image has strong contrast.
    vec2 step_uv = SCREEN_PIXEL_SIZE * 1.35;
    float lum = luminance(original);
    float neighbor = min(luminance(texture(scene_color, SCREEN_UV + vec2(step_uv.x, 0.0)).rgb),
                         luminance(texture(scene_color, SCREEN_UV + vec2(0.0, step_uv.y)).rgb));
    float contour = smoothstep(0.075, 0.23, lum - neighbor);
    scene *= 1.0 - 0.17 * cel_strength * contour;

    vec2 corners = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - 0.13 * smoothstep(0.36, 1.88, dot(corners, corners));
    COLOR = vec4(scene * vignette, 1.0);
}
