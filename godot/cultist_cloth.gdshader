shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform float motion_phase = 0.0;
uniform float walk_blend = 0.0;
uniform float breath_time = 0.0;
void vertex() {
    // Source GLB is Z-up. Weight the deformation toward the free lower hem.
    float hem = 1.0 - smoothstep(0.25, 1.15, VERTEX.z);
    float chest = smoothstep(1.30, 1.70, VERTEX.z) * (1.0 - smoothstep(1.8, 2.15, VERTEX.z));
    VERTEX.x += hem * (0.023 * sin(motion_phase + VERTEX.z * 4.0) * walk_blend + 0.007 * sin(breath_time * 1.8 + VERTEX.y * 5.0));
    VERTEX.y += hem * 0.029 * sin(motion_phase * 2.0 + VERTEX.x * 6.0) * walk_blend;
    VERTEX.y += chest * sign(VERTEX.y) * 0.005 * sin(breath_time * 1.7);
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.96;
    METALLIC = 0.0;
    SPECULAR = 0.18;
}
