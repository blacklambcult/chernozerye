extends Node
## Optional screen-grid effects for the Compatibility renderer.

const JITTER_GROUP := &"ps1_jitter_foliage"
const JITTER_VERTEX := """
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    if (clip.w > 0.75) {
        vec2 grid = max(VIEWPORT_SIZE * 0.5, vec2(1.0));
        vec2 ndc = clip.xy / clip.w;
        vec2 snapped = floor(ndc * grid + 0.5) / grid;
        clip.xy += (snapped - ndc) * clip.w * 0.65 * smoothstep(0.75, 3.0, clip.w) * (1.0 - smoothstep(30.0, 80.0, clip.w));
    }
    POSITION = clip;
"""
const SURFACE_SHADER := """
shader_type spatial;
render_mode OPTIONS;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, FILTERING, repeat_enable;
uniform bool textured = false;
uniform bool vertex_color = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform vec3 emission : source_color;
void vertex() {
    JITTER
}
void fragment() {
    vec4 surface = base_color;
    if (textured) {
        surface *= texture(base_texture, UV * uv_scale + uv_offset);
    }
    if (vertex_color) {
        surface *= COLOR;
    }
    ALBEDO = surface.rgb;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    EMISSION = emission;
}
"""
var pixels_enabled := false
var jitter_enabled := false
var pixel_strength := 55.0
var grade_material: ShaderMaterial
var _originals: Dictionary = {}
var _materials: Dictionary = {}
var _shaders: Dictionary = {}


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func set_pixels(value: bool) -> void:
    pixels_enabled = value
    if grade_material != null:
        grade_material.set_shader_parameter("ps1_pixels_enabled", value)


func set_pixel_strength(value: float) -> void:
    pixel_strength = clampf(value, 0.0, 100.0)
    if grade_material != null:
        grade_material.set_shader_parameter("ps1_pixel_strength", pixel_strength / 100.0)


func set_jitter(value: bool) -> void:
    if value == jitter_enabled:
        return
    jitter_enabled = value
    if value:
        for node in get_tree().get_nodes_in_group(JITTER_GROUP):
            _apply_jitter(node)
        return
    for instance_id in _originals.keys():
        _restore(instance_from_id(instance_id) as GeometryInstance3D, instance_id)
    _materials.clear()


func _on_node_added(node: Node) -> void:
    if jitter_enabled and node is GeometryInstance3D and node.is_in_group(JITTER_GROUP):
        _apply_jitter.call_deferred(node, false)


func _on_node_removed(node: Node) -> void:
    if node is GeometryInstance3D:
        _restore(node, node.get_instance_id())


func _restore(node: GeometryInstance3D, id: int) -> void:
    var original: Variant = _originals.get(id)
    if original == null:
        return
    _originals.erase(id)
    if node == null:
        return
    node.material_override = original["override"]
    if node is MeshInstance3D:
        for surface in original["surfaces"]:
            if surface < node.get_surface_override_material_count():
                node.set_surface_override_material(surface, original["surfaces"][surface])


func _apply_jitter(node: GeometryInstance3D, cache_material := true) -> void:
    if not jitter_enabled or not is_instance_valid(node) or not get_parent().is_ancestor_of(node) \
            or not node.is_in_group(JITTER_GROUP):
        return
    # Camera-attached viewmodels use finely layered meshes and authored materials.
    var ancestor := node.get_parent()
    while ancestor != null:
        if ancestor is Camera3D:
            return
        ancestor = ancestor.get_parent()
    var id := node.get_instance_id()
    if _originals.has(id):
        return
    var surfaces := {}
    var override := node.material_override
    if override != null:
        var replacement := _jitter_material(override, cache_material)
        if replacement != override:
            node.material_override = replacement
    elif node is MeshInstance3D and node.mesh != null:
        for surface in node.get_surface_override_material_count():
            var source: Material = node.get_active_material(surface)
            var replacement := _jitter_material(source, cache_material)
            if replacement != source:
                surfaces[surface] = node.get_surface_override_material(surface)
                node.set_surface_override_material(surface, replacement)
    elif node is MultiMeshInstance3D and node.multimesh != null:
        _apply_single_surface(node, node.multimesh.mesh, cache_material)
    if node.material_override != override or not surfaces.is_empty():
        _originals[id] = {"override": override, "surfaces": surfaces}


func _apply_single_surface(node: GeometryInstance3D, mesh: Mesh, cache_material: bool) -> void:
    if mesh != null and mesh.get_surface_count() == 1:
        node.material_override = _jitter_material(mesh.surface_get_material(0), cache_material)


func _jitter_material(source: Material, cache_material: bool) -> Material:
    if source is BaseMaterial3D and (source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
            or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or source.no_depth_test):
        return source
    if _materials.has(source):
        return _materials[source]
    var shader: Shader
    var converted := ShaderMaterial.new()
    if source is ShaderMaterial:
        shader = source.shader
        if shader == null or shader.resource_path != "res://cabin_wood.gdshader":
            return source
        var wood_code := shader.code.replace("local_normal = NORMAL;", "local_normal = NORMAL;\n" + JITTER_VERTEX)
        converted.shader = _cached_shader(wood_code)
    elif source == null or source is BaseMaterial3D:
        var base: BaseMaterial3D = source
        converted.shader = _cached_shader(_surface_code(base))
        if base != null:
            converted.render_priority = base.render_priority
            converted.set_shader_parameter("base_color", base.albedo_color)
            converted.set_shader_parameter("base_texture", base.albedo_texture)
            converted.set_shader_parameter("textured", base.albedo_texture != null)
            converted.set_shader_parameter("vertex_color", base.vertex_color_use_as_albedo)
            converted.set_shader_parameter("uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
            converted.set_shader_parameter("uv_offset", Vector2(base.uv1_offset.x, base.uv1_offset.y))
            converted.set_shader_parameter("roughness", base.roughness)
            converted.set_shader_parameter("metallic", base.metallic)
            if base.emission_enabled:
                var color := base.emission * base.emission_energy_multiplier
                converted.set_shader_parameter("emission", Vector3(color.r, color.g, color.b))
    else:
        return source
    if cache_material:
        _materials[source] = converted
    return converted


func _cached_shader(code: String) -> Shader:
    if not _shaders.has(code):
        var shader := Shader.new()
        shader.code = code
        _shaders[code] = shader
    return _shaders[code]


func _surface_code(base: BaseMaterial3D) -> String:
    var options := ["cull_back"]
    var filtering := "filter_nearest_mipmap"
    if base != null:
        options[0] = ["cull_back", "cull_front", "cull_disabled"][base.cull_mode]
        if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
            options.append("unshaded")
        if base.no_depth_test:
            options.append("depth_test_disabled")
        if base.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_LINEAR, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]:
            filtering = "filter_linear_mipmap"
    return SURFACE_SHADER.replace("OPTIONS", ", ".join(options)).replace("FILTERING", filtering) \
        .replace("JITTER", JITTER_VERTEX)
