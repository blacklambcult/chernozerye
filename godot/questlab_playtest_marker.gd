extends Node3D
# Temporary Quest Lab playtest prop. Does not change the real village geometry.
# Shows a stylized interactive marker or a collectable note at the quest target.
var item_type := "interact"
var caption := ""
var linked_object := false
var object_category := ""
var elapsed := 0.0
var visual: Node3D

func configure(step: Dictionary) -> void:
    item_type = str(step.get("type", "interact"))
    caption = str(step.get("title", "Задача"))
    linked_object = str(step.get("target_source", "")) == "geo_lab_id" and not str(step.get("object_id", "")).is_empty()
    object_category = str(step.get("object_type", ""))

func _ready() -> void:
    name = "QuestLabPlaytestMarker"
    visual = Node3D.new()
    visual.name = "PreviewOnlyVisual"
    visual.position.y = 0.12 if linked_object else 1.55
    add_child(visual)
    if item_type == "reach":
        _make_reach_ring()
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#e7c59d") if item_type == "collect" else Color("#77ccb5")
    material.emission_enabled = true
    material.emission = material.albedo_color
    material.emission_energy_multiplier = 0.4
    material.roughness = 0.88
    var body := MeshInstance3D.new()
    body.name = "QuestNote" if item_type == "collect" else "QuestSignal"
    if linked_object:
        # A small ground target at a real Geo Lab building, not a fake house.
        # The actual building geometry is already rendered by ManualGeo.
        var ring := CylinderMesh.new()
        ring.height = 0.04
        ring.top_radius = 0.38
        ring.bottom_radius = 0.38
        ring.radial_segments = 10
        body.mesh = ring
    elif item_type == "collect":
        var note := BoxMesh.new()
        note.size = Vector3(0.35, 0.24, 0.035)
        body.mesh = note
    else:
        var jewel := SphereMesh.new()
        jewel.radius = 0.19
        jewel.height = 0.38
        jewel.radial_segments = 8
        jewel.rings = 4
        body.mesh = jewel
    body.material_override = material
    visual.add_child(body)
    var label := Label3D.new()
    label.name = "QuestHint"
    label.text = "E · ПОДОБРАТЬ" if item_type == "collect" else "E · ОСМОТРЕТЬ"
    if linked_object:
        label.text = "GEO LAB / " + object_category.to_upper() + " / E"
    label.position = Vector3(0, 1.65 if linked_object else 0.48, 0)
    label.font_size = 28
    label.pixel_size = 0.003
    label.modulate = Color("#e9d7bb")
    label.outline_modulate = Color("#172120")
    label.outline_size = 5
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    visual.add_child(label)

func _process(delta: float) -> void:
    elapsed += delta
    if visual != null:
        if item_type == "reach":
            visual.scale = Vector3.ONE * (1.0 + 0.06 * sin(elapsed * 2.8))
        elif linked_object:
            visual.position.y = 0.12 + sin(elapsed * 1.8) * 0.025
        else:
            visual.position.y = 1.55 + sin(elapsed * 1.8) * 0.12
            visual.rotation.y += delta * 0.45

func _make_reach_ring() -> void:
    visual.position.y = 0.18
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("#6ef5cf")
    material.emission_enabled = true
    material.emission = material.albedo_color
    material.emission_energy_multiplier = 1.5
    var ring := TorusMesh.new()
    ring.outer_radius = 2.0
    ring.inner_radius = 1.65
    ring.rings = 32
    ring.ring_segments = 8
    var mesh := MeshInstance3D.new()
    mesh.name = "ReachGroundRing"
    mesh.mesh = ring
    mesh.material_override = material
    visual.add_child(mesh)

    var beacon := MeshInstance3D.new()
    beacon.name = "ReachBeacon"
    var shaft := CylinderMesh.new()
    shaft.top_radius = 0.05
    shaft.bottom_radius = 0.12
    shaft.height = 2.8
    beacon.mesh = shaft
    beacon.position.y = 1.4
    beacon.material_override = material
    visual.add_child(beacon)
    var label := Label3D.new()
    label.text = "ЦЕЛЬ"
    label.position.y = 3.0
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.pixel_size = 0.012
    label.modulate = material.albedo_color
    visual.add_child(label)
