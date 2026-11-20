extends SceneTree
# Standalone real-world loot regression, independent of F7 Quest Lab preview.
func _fail(why: String) -> void:
    push_error("WORLD_ITEMS_REGRESSION_FAILED: " + why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "WorldItemHarness"
    get_root().add_child(root)
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.position = Vector3(130, 0.22, -82)
    root.add_child(actor)
    var cam := Camera3D.new()
    cam.name = "Camera3D"
    actor.add_child(cam)
    var archive := Node.new()
    archive.name = "NoteArchive"
    archive.set_script(load("res://note_archive.gd"))
    root.add_child(archive)
    var manager := Node3D.new()
    manager.name = "WorldDocument"
    manager.set_script(load("res://world_document.gd"))
    root.add_child(manager)
    manager.set_process(false)
    var entries: Array = manager.get("entries")
    if entries.size() != 4:
        _fail("world item library was not loaded independently: " + str(entries.size()))
        return
    if archive.call("has_document", "world-note-roadside") \
            or archive.call("has_item", "world-item-rusted-key"):
        _fail("fresh CI session already owns the sample pickups")
        return
    var record: Dictionary = entries[0]
    if str(record["id"]) != "world-note-roadside" or str(record["type"]) != "note":
        _fail("first note is missing or reordered")
        return
    actor.global_position = Vector3(133, 0.22, -85)
    if not bool(manager.call("_collect_nearest")):
        _fail("E interaction did not collect an authored world note")
        return
    if not archive.call("has_document", "world-note-roadside") or not archive.call("is_reader_open"):
        _fail("world note was not saved/opened in the full-screen reader")
        return
    var paper: Dictionary = archive.call("get_document", "world-note-roadside")
    if not str(paper.get("body", "")).contains("ноябрь 2005"):
        _fail("author's note text did not reach the game archive")
        return
    archive.call("close_reader")
    if bool(manager.call("_collect_nearest")):
        _fail("a collected note can be picked again")
        return
    actor.global_position = Vector3(138, 0.22, -88)
    if not bool(manager.call("_collect_nearest")):
        _fail("ordinary loot item cannot be collected with E")
        return
    if not archive.call("has_item", "world-item-rusted-key"):
        _fail("ordinary item was not recorded in persistent inventory")
        return
    var item: Dictionary = archive.call("get_item", "world-item-rusted-key")
    if not str(item.get("description", "")).contains("железный"):
        _fail("item description did not persist")
        return
    archive.call("open_journal")
    if str(archive.get("mode")) != "journal":
        _fail("J did not open collected-items journal")
        return
    if not archive.call("open_document", "world-note-roadside", true):
        _fail("the note cannot be reread from the journal")
        return
    archive.call("close_reader")
    if not archive.call("open_item", "world-item-rusted-key"):
        _fail("ordinary item cannot be inspected in the inventory")
        return
    archive.call("close_reader")
    archive.call("close_all")
    var save_file := "user://chernozerye_field_documents_v1.json"
    if not FileAccess.file_exists(save_file):
        _fail("world item save file not created")
        return
    var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_file))
    if not saved is Dictionary:
        _fail("save is malformed")
        return
    if not saved.get("items") is Array or (saved.get("items") as Array).size() < 1 \
            or not saved.get("documents") is Array:
        _fail("save did not include both documents and world items")
        return
    # Save roundtrip should retain the collected IDs and their original prose.
    var saved_docs: Array = saved["documents"]
    var saved_items: Array = saved["items"]
    if not saved_docs.any(func(d: Dictionary) -> bool:
            return str(d.get("id",""))=="world-note-roadside") \
            or not saved_items.any(func(d: Dictionary) -> bool:
                return str(d.get("id",""))=="world-item-rusted-key"):
        _fail("persistent ID roundtrip failed")
        return
    var original_count := entries.size()
    manager.call("_process", 0.0)
    var visual := record["node"] as Node3D
    if visual.visible:
        _fail("world paper did not disappear after collection")
        return
    print("WORLD_ITEMS_REGRESSION_OK: authored=", original_count,
        " reader=true item=true journal=true persistence=true spawned=true")
    quit(0)
