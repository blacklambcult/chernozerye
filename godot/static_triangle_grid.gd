extends RefCounted

# Keep whole triangles at cell boundaries so render batching preserves the
# authored coordinates and winding. The mesh AABB covers any overhang.
static func cell_for_triangle(a: Vector3, b: Vector3, c: Vector3, cell_size: float) -> Vector2i:
    var center := (a + b + c) / (3.0 * cell_size)
    return Vector2i(floori(center.x), floori(center.z))
