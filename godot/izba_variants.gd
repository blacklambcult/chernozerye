extends RefCounted
# CHERNOZERYE 3.3 / modular village house recipe
# Four independently selected sets of five visual parts; the hand-drawn footprints never change.
# Recipe is stable for each surveyed location, not for iteration order.

const VARIANTS := 5

static func _mix(value: int) -> int:
    var x := value & 0x7fffffff
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff
    return (x ^ (x >> 16)) & 0x7fffffff

static func recipe(points: PackedVector2Array) -> Dictionary:
    var center := Vector2.ZERO
    var min_x := INF
    var max_x := -INF
    var min_y := INF
    var max_y := -INF
    for p in points:
        center += p
        min_x = minf(min_x, p.x)
        max_x = maxf(max_x, p.x)
        min_y = minf(min_y, p.y)
        max_y = maxf(max_y, p.y)
    if points.is_empty():
        return {"floor_count": 1, "body": 0, "roof": 0, "window": 0, "entrance": 0}
    center /= float(points.size())
    var key := (int(roundf(center.x * 10.0)) * 73856093) ^ (int(roundf(center.y * 10.0)) * 19349663)
    var floors := 1
    # A small minority of larger footprints become two-storey countryside houses.
    if minf(max_x - min_x, max_y - min_y) >= 6.5 and _mix(key + 4451) % 8 == 0:
        floors = 2
    return {
        "floor_count": floors,
        # More log cabins than in v3.2 (only 3 of 35 were timber relief).
        # Still 5 independent body designs; distributions are deliberately weighted.
        "body": [1, 1, 1, 1, 0, 0, 2, 3, 4, 4][_mix(key + 1009) % 10],
        "roof": _mix(key + 2017) % VARIANTS,
        "window": _mix(key + 3019) % VARIANTS,
        "entrance": _mix(key + 4013) % VARIANTS
    }
