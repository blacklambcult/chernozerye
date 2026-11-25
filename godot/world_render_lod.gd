extends RefCounted

const BUILDING_BIAS := 0.75
const TREE_BIAS := 0.8
const GROUND_DETAIL_DISTANCE := 54.0
const UNDERSTORY_DISTANCE := 88.0
const DETAIL_MARGIN := 8.0


static func enabled() -> bool:
    if "--disable-world-lod" in OS.get_cmdline_user_args():
        return false
    if OS.has_feature("web"):
        var mode: Variant = JavaScriptBridge.eval(
            "new URLSearchParams(window.location.search).get('world_lod')", true
        )
        if mode == "off":
            return false
    return true


static func detail_distance(asset_id: String) -> float:
    if asset_id.begins_with("ground_"):
        return GROUND_DETAIL_DISTANCE
    if asset_id.begins_with("understory_"):
        return UNDERSTORY_DISTANCE
    return 0.0


static func set_detail_range(batch: MultiMeshInstance3D, bounds: AABB, distance: float) -> void:
    # Godot measures from the batch center. Account for the farthest corner
    # so a nearby detail at the edge of a large chunk cannot disappear early.
    batch.multimesh.custom_aabb = bounds
    batch.visibility_range_end = distance + bounds.size.length() * 0.5 + DETAIL_MARGIN
    batch.visibility_range_end_margin = DETAIL_MARGIN
