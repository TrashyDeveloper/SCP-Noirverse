class_name TrainingDummy
extends StaticBody3D
## A target for testing weapons. Flashes when hit, falls over when its
## health runs out, then stands back up after a few seconds.

@export var respawn_time := 4.0

var _flash := 0.0
var _material: StandardMaterial3D

@onready var health: Health = $Health
@onready var label: Label3D = $Label
@onready var body_mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Each dummy gets its own copy of the material so they flash separately.
	_material = body_mesh.get_active_material(0).duplicate()
	body_mesh.material_override = _material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_update_label()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		_material.emission_energy_multiplier = _flash * 2.0


func _on_damaged(_amount: float, _source: Node) -> void:
	_flash = 1.0
	_update_label()


func _on_died(_source: Node) -> void:
	collision.set_deferred("disabled", true)
	var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:x", -PI / 2, 0.7)
	tween.tween_interval(respawn_time)
	tween.tween_property(self, "rotation:x", 0.0, 0.8).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_stand_up)


func _stand_up() -> void:
	collision.disabled = false
	health.reset()
	_update_label()


func _update_label() -> void:
	label.text = "%d HP" % ceili(health.current)
