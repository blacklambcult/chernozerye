extends Node3D
# Version 1.7: georeferenced, batched 3D extrusion of Overture building candidates
# in western sector A. Coordinates are EPSG:32640 metres relative to the study centre.
# Source geometry is not cadastral truth; elevations and roof shape are placeholders.

const SOURCE := "res://overture_buildings.json"
const CENTRE := Vector2(-660.0, 390.0)
const HALF := 340.0
var generated_count := 0

func _ready() -> void:
    call_deferred("_build")

func _build() -> void:
    await get_tree().process_frame
    if not FileAccess.file_exists(SOURCE):
        push_warning("Overture building dataset missing: " + SOURCE)
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not data is Dictionary:
        push_warning("Invalid Overture building dataset")
        return
    var buildings: Array = data.get("buildings", [])
    var walls := PackedVector3Array()
    var wall_normals := PackedVector3Array()
    var wall_colors := PackedColorArray()
    var roofs := PackedVector3Array()
    var roof_normals := PackedVector3Array()
    var roof_colors := PackedColorArray()

    for feature in buildings:
        if not feature is Dictionary:
            continue
        var raw_points: Array = feature.get("points", [])
        if raw_points.size() < 3 or raw_points.size() > 250:
            continue
        var footprint := PackedVector2Array()
        var middle := Vector2.ZERO
        for coords in raw_points:
            var p := Vector2(float(coords[0]), float(coords[1]))
            footprint.append(p)
            middle += p
        middle /= float(footprint.size())
        if absf(middle.x - CENTRE.x) > HALF or absf(middle.y - CENTRE.y) > HALF:
            continue
        var triangles := Geometry2D.triangulate_polygon(footprint)
        if triangles.is_empty():
            continue

        # Identical features keep identical placeholder heights and colors after refresh.
        var variant: int = absi(str(feature.get("id", "")).hash()) % 5
        var height := 3.5 + float(variant) * 0.38
        var reported = feature.get("height_m", null)
        if reported is float or reported is int:
            height = clampf(float(reported), 2.5, 12.0)
        var wall_tint := [
            Color("#988778"), Color("#a29281"), Color("#87796d"),
            Color("#b09a84"), Color("#8b8277")
        ][variant]
        var roof_tint := [
            Color("#65514e"), Color("#68636a"), Color("#845c50"),
            Color("#5d6668"), Color("#6f5c4f")
        ][variant]

        for i in range(footprint.size()):
            var a: Vector2 = footprint[i]
            var b: Vector2 = footprint[(i + 1) % footprint.size()]
            if a.distance_squared_to(b) < 0.01:
                continue
            var low_a := Vector3(a.x, 0.07, -a.y)
            var low_b := Vector3(b.x, 0.07, -b.y)
            var high_a := low_a + Vector3.UP * height
            var high_b := low_b + Vector3.UP * height
            _triangle(walls, wall_normals, wall_colors, low_a, low_b, high_b, wall_tint)
            _triangle(walls, wall_normals, wall_colors, low_a, high_b, high_a, wall_tint)

        for k in range(0, triangles.size(), 3):
            var p0: Vector2 = footprint[triangles[k]]
            var p1: Vector2 = footprint[triangles[k + 1]]
            var p2: Vector2 = footprint[triangles[k + 2]]
            _triangle(
                roofs, roof_normals, roof_colors,
                Vector3(p0.x, 0.07 + height, -p0.y),
                Vector3(p1.x, 0.07 + height, -p1.y),
                Vector3(p2.x, 0.07 + height, -p2.y),
                roof_tint
            )
        generated_count += 1

    _add_surface(walls, wall_normals, wall_colors, "OvertureWalls")
    _add_surface(roofs, roof_normals, roof_colors, "OvertureRoofs")
    print("OVERTURE_3D_A_READY: ", generated_count)

func _triangle(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
        a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
    var normal := (b - a).cross(c - a).normalized()
    vertices.append_array(PackedVector3Array([a, b, c]))
    normals.append_array(PackedVector3Array([normal, normal, normal]))
    colors.append_array(PackedColorArray([tint, tint, tint]))

func _add_surface(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, label: String) -> void:
    if vertices.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    instance.material_override = mat
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
