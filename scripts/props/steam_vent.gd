class_name SteamVent
extends HazardZone
## A floor vent that bursts out scalding steam every few seconds.

@export var period := 7.0
@export var burst_time := 2.2
## Offset into the cycle so vents don't all fire together.
@export var phase := 0.0

var active := false
var _time := 0.0
var _steam: CPUParticles3D


func _ready() -> void:
	damage_per_second = 30.0
	cause_of_death = "Scalded by a steam vent"
	collision_layer = 0
	collision_mask = 2
	PropBuilder.add_shape(self, Vector3(0, 1.2, 0), Vector3(1.3, 2.4, 1.3))
	_steam = CPUParticles3D.new()
	_steam.amount = 40
	_steam.lifetime = 1.0
	_steam.emitting = false
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.initial_velocity_min = 3.0
	_steam.initial_velocity_max = 5.0
	_steam.gravity = Vector3(0, 0.5, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.25
	puff.height = 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.9, 0.9, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = m
	_steam.mesh = puff
	add_child(_steam)
	_time = phase


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta, period)
	var now := _time < burst_time
	if now != active:
		active = now
		_steam.emitting = active
	if active:
		super(delta)
