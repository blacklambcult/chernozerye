shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_nearest;

float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
    vec2 grid = vec2(360.0 * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 360.0);
    vec2 pixel = floor(SCREEN_UV * grid);
    vec2 uv = (pixel + 0.5) / grid;
    vec3 scene = texture(scene_color, uv).rgb;

    // A short dark rim on the lit side of a strong edge.
    float lightness = luminance(scene);
    float neighbor = min(luminance(texture(scene_color, uv - vec2(1.0 / grid.x, 0.0)).rgb),
                         luminance(texture(scene_color, uv + vec2(0.0, 1.0 / grid.y)).rgb));
    scene *= 1.0 - 0.23 * smoothstep(0.065, 0.19, lightness - neighbor);

    // Ordered dithering anchors the color steps to the virtual pixels.
    vec2 phase = mod(pixel, 2.0);
    float threshold = (2.0 * mod(phase.x + phase.y, 2.0) + phase.y) / 4.0;
    scene = floor(scene * 35.0 + 0.55 * threshold + 0.24) / 35.0;
    vec2 corners = SCREEN_UV * 2.0 - 1.0;
    float vignette = 1.0 - 0.2 * smoothstep(0.25, 1.85, dot(corners, corners));
    COLOR = vec4(scene * vignette, 1.0);
}
