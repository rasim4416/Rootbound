## Procedural presentation for Insect/Visual: idle pulse, move wobble, hit flash, death.
## Does not move the Insect root — only local Visual transform/modulate.
class_name InsectVisualAnimator
extends Node2D

const PULSE_SPEED: float = 2.4
const PULSE_SCALE_AMP: float = 0.05
const PULSE_BRIGHT_AMP: float = 0.06

const WOBBLE_SPEED: float = 7.5
const WOBBLE_POS_MOVING: float = 2.8
const WOBBLE_POS_IDLE: float = 0.7
const WOBBLE_ROT_MOVING: float = 0.09
const WOBBLE_ROT_IDLE: float = 0.025
const WOBBLE_BLEND_SPEED: float = 4.0

const HIT_FLASH_DURATION: float = 0.1
const HIT_FLASH_COLOR := Color(1.55, 1.55, 1.55, 1.0)

const DEATH_DURATION: float = 0.28

var _time: float = 0.0
var _wobble_strength: float = 0.0
var _hit_timer: float = 0.0
var _dying: bool = false
var _death_elapsed: float = 0.0
var _death_start_scale: Vector2 = Vector2.ONE
var _death_start_rotation: float = 0.0
var _death_start_modulate: Color = Color.WHITE


func _ready() -> void:
	_time = randf() * TAU
	set_process(true)


func _process(delta: float) -> void:
	if _dying:
		_process_death(delta)
		return

	_time += delta
	if _hit_timer > 0.0:
		_hit_timer = maxf(_hit_timer - delta, 0.0)

	var moving: bool = _is_path_actively_moving()
	var target_wobble: float = 1.0 if moving else 0.0
	_wobble_strength = move_toward(_wobble_strength, target_wobble, WOBBLE_BLEND_SPEED * delta)

	_apply_idle_and_wobble()


## Brief white flash on damage. Safe to call while already flashing.
func play_hit_flash() -> void:
	if _dying:
		return
	_hit_timer = HIT_FLASH_DURATION


## Shrink / spin / fade. Insect should queue_free after get_death_duration().
func play_death() -> void:
	if _dying:
		return
	_dying = true
	_death_elapsed = 0.0
	_death_start_scale = scale
	_death_start_rotation = rotation
	_death_start_modulate = modulate
	_hit_timer = 0.0


func get_death_duration() -> float:
	return DEATH_DURATION


func _apply_idle_and_wobble() -> void:
	var pulse_t: float = sin(_time * PULSE_SPEED)
	# Smooth organic pulse around 0.95..1.05
	var pulse_scale: float = 1.0 + PULSE_SCALE_AMP * sin(_time * PULSE_SPEED)
	scale = Vector2(pulse_scale, pulse_scale)

	var wobble_pos_amp: float = lerpf(WOBBLE_POS_IDLE, WOBBLE_POS_MOVING, _wobble_strength)
	var wobble_rot_amp: float = lerpf(WOBBLE_ROT_IDLE, WOBBLE_ROT_MOVING, _wobble_strength)
	# Local Y is perpendicular once Insect root faces path direction.
	var wobble_phase: float = _time * WOBBLE_SPEED
	position = Vector2(0.0, sin(wobble_phase) * wobble_pos_amp)
	rotation = sin(wobble_phase * 0.72 + 0.4) * wobble_rot_amp

	var brightness: float = 1.0 + PULSE_BRIGHT_AMP * pulse_t
	if _hit_timer > 0.0:
		var flash_t: float = clampf(_hit_timer / HIT_FLASH_DURATION, 0.0, 1.0)
		# Ease out of flash toward pulse modulate.
		modulate = HIT_FLASH_COLOR.lerp(
			Color(brightness, brightness, brightness, 1.0),
			1.0 - flash_t
		)
	else:
		modulate = Color(brightness, brightness, brightness, 1.0)

func _process_death(delta: float) -> void:
	_death_elapsed += delta
	var t: float = clampf(_death_elapsed / DEATH_DURATION, 0.0, 1.0)
	# Smoothstep ease-in for organic collapse.
	var ease_t: float = t * t * (3.0 - 2.0 * t)

	scale = _death_start_scale.lerp(Vector2(0.15, 0.15), ease_t)
	rotation = _death_start_rotation + ease_t * 0.95
	var fade: Color = _death_start_modulate
	fade.a = lerpf(_death_start_modulate.a, 0.0, ease_t)
	modulate = fade
	position = position.lerp(Vector2.ZERO, ease_t * 0.35)


func _is_path_actively_moving() -> bool:
	if GameManager != null:
		if GameManager.is_game_over():
			return false
		if GameManager.is_upgrade_paused():
			return false

	var host: Node = get_parent()
	if host == null:
		return false
	if host.get("is_alive") == false:
		return false

	var follower: Node = host.get_node_or_null("GridPathFollower")
	if follower == null:
		return false
	return bool(follower.get("is_moving"))
