shader_type canvas_item;
render_mode unshaded;

uniform sampler2D frame : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    float height = min(240.0, 1.0 / SCREEN_PIXEL_SIZE.y);
    vec2 grid = vec2(height * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, height);
    vec2 pixel_uv = (floor(SCREEN_UV * grid) + 0.5) / grid;
    COLOR = texture(frame, pixel_uv);
}
