extends Node
## Optional screen-grid effects for the Compatibility renderer.

const ROAD_GROUP := &"ps1_jitter_road"
const NATURE_GROUP := &"ps1_jitter_foliage"
const JITTER_CONTROLS := {
    &"viewmodel": "Руки и оружие",
    &"objects": "Постройки и объекты",
    &"road": "Дорога",
    &"nature": "Природа",
}
const JITTER_UNIFORMS := """
global uniform float ps1_jitter_strength;
uniform vec2 jitter_axes = vec2(1.0);
uniform vec2 jitter_near = vec2(0.75, 3.0);
"""

const JITTER_VERTEX := """
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    if (clip.w > jitter_near.x) {
        vec2 grid = max(VIEWPORT_SIZE * 0.25, vec2(1.0));
        vec2 ndc = clip.xy / clip.w;
        vec2 snapped = floor(ndc * grid + 0.5) / grid;
        clip.xy += (snapped - ndc) * clip.w * ps1_jitter_strength * jitter_axes * smoothstep(jitter_near.x, jitter_near.y, clip.w) * (1.0 - smoothstep(30.0, 80.0, clip.w));
    }
    POSITION = clip;
"""
const SURFACE_SHADER := """
shader_type spatial;
render_mode OPTIONS;
JITTER_UNIFORMS
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, FILTERING, repeat_enable;
uniform bool textured = false;
uniform bool vertex_color = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
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
    SPECULAR = specular;
    EMISSION = emission;
}
"""
var pixels_enabled := true
var jitter_enabled := true
var pixel_strength := 55.0
var jitter_strength := 50.0
var jitter_targets := {&"viewmodel": true, &"objects": true, &"road": false, &"nature": true}
var grade_material: ShaderMaterial
var _originals: Dictionary = {}
var _materials: Dictionary = {}
var _shaders: Dictionary = {}


func _ready() -> void:
    _update_jitter_uniform()
    set_pixels(pixels_enabled)
    set_pixel_strength(pixel_strength)
    _refresh_jitter()
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
    _refresh_jitter()


func set_jitter_strength(value: float) -> void:
    var was_active := jitter_strength > 0.0
    jitter_strength = clampf(value, 0.0, 100.0)
    _update_jitter_uniform()
    if jitter_enabled and was_active != (jitter_strength > 0.0):
        _refresh_jitter()


func set_jitter_target(target: StringName, enabled: bool) -> void:
    if not jitter_targets.has(target) or jitter_targets[target] == enabled:
        return
    jitter_targets[target] = enabled
    if jitter_enabled and jitter_strength > 0.0:
        _refresh_jitter()


func _update_jitter_uniform() -> void:
    RenderingServer.global_shader_parameter_set(&"ps1_jitter_strength", jitter_strength / 100.0)


func _refresh_jitter() -> void:
    for instance_id in _originals.keys():
        _restore(instance_from_id(instance_id) as GeometryInstance3D, instance_id)
    _materials.clear()
    if not jitter_enabled or jitter_strength <= 0.0:
        return
    for node in get_parent().find_children("*", "GeometryInstance3D", true, false):
        _apply_jitter(node)


func _on_node_added(node: Node) -> void:
    if jitter_enabled and jitter_strength > 0.0 and node is GeometryInstance3D:
        _apply_jitter.call_deferred(node, node is MultiMeshInstance3D)


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


func _jitter_target(node: GeometryInstance3D) -> StringName:
    var ancestor: Node = node
    while ancestor != get_parent():
        if ancestor.is_in_group(&"ps1_jitter_stable"):
            return &""
        if ancestor is Camera3D:
            return &"viewmodel"
        if ancestor.is_in_group(ROAD_GROUP):
            return &"road"
        if ancestor.is_in_group(NATURE_GROUP):
            return &"nature"
        ancestor = ancestor.get_parent()
    return &"objects"


func _apply_jitter(node: GeometryInstance3D, cache_material := true) -> void:
    if not jitter_enabled or jitter_strength <= 0.0 or not is_instance_valid(node) \
            or not get_parent().is_ancestor_of(node):
        return
    if not (node is MeshInstance3D or node is MultiMeshInstance3D):
        return
    var target := _jitter_target(node)
    if not jitter_targets.get(target, false):
        return
    var id := node.get_instance_id()
    if _originals.has(id):
        return
    var surfaces := {}
    var override := node.material_override
    if override != null:
        var replacement := _jitter_material(override, target, cache_material)
        if replacement != override:
            node.material_override = replacement
    elif node is MeshInstance3D and node.mesh != null:
        for surface in node.get_surface_override_material_count():
            var source: Material = node.get_active_material(surface)
            var replacement := _jitter_material(source, target, cache_material)
            if replacement != source:
                surfaces[surface] = node.get_surface_override_material(surface)
                node.set_surface_override_material(surface, replacement)
    elif node is MultiMeshInstance3D and node.multimesh != null:
        _apply_single_surface(node, node.multimesh.mesh, target, cache_material)
    if node.material_override != override or not surfaces.is_empty():
        _originals[id] = {"override": override, "surfaces": surfaces}


func _apply_single_surface(node: GeometryInstance3D, mesh: Mesh, target: StringName, cache_material: bool) -> void:
    if mesh != null and mesh.get_surface_count() == 1:
        node.material_override = _jitter_material(mesh.surface_get_material(0), target, cache_material)


func _jitter_material(source: Material, target: StringName, cache_material: bool) -> Material:
    if source is BaseMaterial3D and (source.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED \
            or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or (source.no_depth_test and target != &"viewmodel")):
        return source
    var materials: Dictionary = _materials.get_or_add(target, {})
    if materials.has(source):
        return materials[source]
    var shader: Shader
    var converted := ShaderMaterial.new()
    if source is ShaderMaterial:
        shader = source.shader
        if shader == null or shader.resource_path != "res://cabin_wood.gdshader":
            return source
        var wood_code := shader.code.replace("local_normal = NORMAL;", "local_normal = NORMAL;\n" + JITTER_VERTEX)
        converted.shader = _cached_shader(wood_code.replace("shader_type spatial;", "shader_type spatial;\n" + JITTER_UNIFORMS))
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
            converted.set_shader_parameter("specular", base.metallic_specular)
            if base.emission_enabled:
                var color := base.emission * base.emission_energy_multiplier
                converted.set_shader_parameter("emission", Vector3(color.r, color.g, color.b))
    else:
        return source
    if target == &"viewmodel":
        converted.set_shader_parameter("jitter_near", Vector2(0.07, 0.23))
    elif target == &"road":
        # Keep road layers stable vertically and cap the horizontal offset below half a pixel.
        converted.set_shader_parameter("jitter_axes", Vector2(0.22, 0.0))
    if cache_material:
        materials[source] = converted
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
        .replace("JITTER_UNIFORMS", JITTER_UNIFORMS).replace("    JITTER\n", JITTER_VERTEX)
