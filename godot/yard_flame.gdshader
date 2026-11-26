shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// One small cutout sprite. Keep the shape readable on the pixel grid.
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
        INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
    vec2 pixel = (floor(UV * vec2(18.0, 24.0)) + 0.5) / vec2(18.0, 24.0);
    float high = 1.0 - pixel.y;
    float pulse = floor(TIME * 12.0) / 12.0;
    float tip = 0.9 + 0.1 * sin(pulse * 7.0);
    float sway = sin(high * 7.0 - pulse * 6.0) * high * 0.16;
    float center = abs(pixel.x - 0.5 - sway);
    float width = (1.0 - high / tip) * 0.38;
    if (high > tip || center > width) {
        discard;
    }
    ALBEDO = mix(vec3(0.95, 0.23, 0.035), vec3(1.0, 0.76, 0.34),
        (1.0 - smoothstep(0.02, 0.95, center / max(width, 0.001))) * (1.0 - high * 0.65));
}
