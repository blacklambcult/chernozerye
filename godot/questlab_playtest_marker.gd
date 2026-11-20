extends Node3D
# Temporary Quest Lab playtest prop. Does not change the real village geometry.
# Shows a stylized interactive marker or a collectable note at the quest target.
var item_type := "interact"
var caption := ""
var elapsed := 0.0
var visual: Node3D

func configure(step: Dictionary) -> void:
    item_type = str(step.get("type", "interact"))
    caption = str(step.get("title", "Задача"))

func _ready() -> void:
    name = "QuestLabPlaytestMarker"
    visual = Node3D.new()
    visual.name = "PreviewOnlyVisual"
    visual.position.y = 1.55
    add_child(visual)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#e7c59d") if item_type == "collect" else Color("#77ccb5")
    material.emission_enabled = true
    material.emission = material.albedo_color
    material.emission_energy_multiplier = 0.4
    material.roughness = 0.88
    var body := MeshInstance3D.new()
    body.name = "QuestNote" if item_type == "collect" else "QuestSignal"
    if item_type == "collect":
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
    label.position = Vector3(0, 0.48, 0)
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
        visual.position.y = 1.55 + sin(elapsed * 1.8) * 0.12
        visual.rotation.y += delta * 0.45
