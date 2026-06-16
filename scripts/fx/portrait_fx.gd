class_name PortraitFX
extends RefCounted
## Dynamic visual effects for character portraits — breathing glow, particles, scan line, idle animation

var _hud: Control
var _idle_container: Control
var _border: Panel
var _border_style: StyleBoxFlat
var _corner_rects: Array[ColorRect] = []
var _portrait: TextureRect
var _portrait_pos: Vector2
var _portrait_size: Vector2
var _glow_color: Color
var _active: bool = false
var _idle_tweens: Array[Tween] = []

var _breath_tween: Tween
var _scan_tween: Tween
var _scan_clip: Panel
var _scan_line: ColorRect


func setup(hud: Control, container: Control, border: Panel, border_style: StyleBoxFlat,
		corner_rects: Array[ColorRect], portrait: TextureRect,
		pos: Vector2, size: Vector2, glow_color: Color, tween_x: Tween, tween_y: Tween, tween_scale: Tween) -> void:
	_hud = hud
	_idle_container = container
	_border = border
	_border_style = border_style
	_corner_rects = corner_rects
	_portrait = portrait
	_portrait_pos = pos
	_portrait_size = size
	_glow_color = glow_color
	_idle_tweens = [tween_x, tween_y, tween_scale]


func start() -> void:
	_active = true
	_start_idle_cycle()
	_start_breathing_glow()
	_start_energy_particles()
	_start_scan_line()


func stop() -> void:
	_active = false
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	if _scan_tween and _scan_tween.is_valid():
		_scan_tween.kill()
	if _scan_clip and is_instance_valid(_scan_clip):
		_scan_clip.queue_free()
	for tw in _idle_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_idle_tweens.clear()


func _start_idle_cycle() -> void:
	_schedule_idle_pause()


func _schedule_idle_pause() -> void:
	if not _active:
		return
	# Play for 6–10 s, then take a short pause
	var play_duration = randf_range(6.0, 10.0)
	_hud.get_tree().create_timer(play_duration).timeout.connect(_do_idle_pause)


func _do_idle_pause() -> void:
	if not _active:
		return
	for tw in _idle_tweens:
		if tw and tw.is_valid():
			tw.set_speed_scale(0.0)
	var pause_duration = randf_range(0.8, 1.8)
	_hud.get_tree().create_timer(pause_duration).timeout.connect(_do_idle_resume)


func _do_idle_resume() -> void:
	if not _active:
		return
	for tw in _idle_tweens:
		if tw and tw.is_valid():
			tw.set_speed_scale(1.0)
	_schedule_idle_pause()


func _start_breathing_glow() -> void:
	_breath_tween = _hud.create_tween().set_loops()
	_breath_tween.tween_method(_apply_breath, 0.0, 1.0, 1.5).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_method(_apply_breath, 1.0, 0.0, 1.5).set_ease(Tween.EASE_IN_OUT)


func _apply_breath(value: float) -> void:
	var sz = lerpf(6.0, 18.0, value)
	var alpha = lerpf(0.3, 0.7, value)
	_border_style.shadow_size = int(sz)
	_border_style.shadow_color = Color(_glow_color, alpha)
	var corner_a = lerpf(0.35, 1.0, value)
	for cr in _corner_rects:
		if is_instance_valid(cr):
			cr.modulate.a = corner_a


func _start_energy_particles() -> void:
	_spawn_particle_burst()


func _spawn_particle_burst() -> void:
	if not _active:
		return
	var count = randi_range(3, 5)
	for i in range(count):
		_emit_particle(i * 0.12)
	var delay = randf_range(1.5, 2.8)
	_hud.get_tree().create_timer(delay).timeout.connect(_spawn_particle_burst)


func _emit_particle(delay: float) -> void:
	var edge = randi() % 3
	var start_pos: Vector2
	match edge:
		0: start_pos = Vector2(randf_range(0, _portrait_size.x), randf_range(-4, 4))
		1: start_pos = Vector2(randf_range(-4, 4), randf_range(0, _portrait_size.y))
		2: start_pos = Vector2(_portrait_size.x + randf_range(-4, 4), randf_range(0, _portrait_size.y))

	var particle = ColorRect.new()
	var psize = randf_range(3.0, 6.0)
	particle.size = Vector2(psize, psize)
	particle.color = Color(_glow_color, randf_range(0.5, 0.9))
	particle.position = _portrait_pos + start_pos
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(particle)

	var tween = _hud.create_tween().set_parallel(true)
	var dur = randf_range(1.2, 1.8)
	tween.tween_property(particle, "position:y", particle.position.y - randf_range(40, 80), dur)
	tween.tween_property(particle, "position:x", particle.position.x + randf_range(-15, 15), dur)
	tween.tween_property(particle, "modulate:a", 0.0, dur * 0.7).set_delay(dur * 0.3)
	tween.tween_callback(particle.queue_free).set_delay(dur)


func _start_scan_line() -> void:
	_scan_clip = Panel.new()
	_scan_clip.position = _portrait_pos
	_scan_clip.size = _portrait_size
	_scan_clip.clip_contents = true
	_scan_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan_clip.z_index = 10
	var clip_style = StyleBoxFlat.new()
	clip_style.bg_color = Color(0, 0, 0, 0)
	_scan_clip.add_theme_stylebox_override("panel", clip_style)
	_hud.add_child(_scan_clip)

	var diag = sqrt(_portrait_size.x * _portrait_size.x + _portrait_size.y * _portrait_size.y)
	var line_width = 18.0
	_scan_line = ColorRect.new()
	_scan_line.size = Vector2(diag * 1.3, line_width)
	_scan_line.color = Color(_glow_color, 0.10)
	_scan_line.pivot_offset = Vector2(diag * 1.3 / 2.0, line_width / 2.0)
	_scan_line.rotation = atan2(_portrait_size.y, _portrait_size.x)
	_scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scan_clip.add_child(_scan_line)

	_run_scan_pass()


func _run_scan_pass() -> void:
	if not _active:
		return
	_scan_line.position = Vector2(-60, -_scan_line.size.y - 20)

	_scan_tween = _hud.create_tween()
	_scan_tween.tween_property(_scan_line, "position:y", _portrait_size.y + 20, 2.5).set_ease(Tween.EASE_IN_OUT)
	_scan_tween.tween_interval(6.0)
	_scan_tween.tween_callback(_run_scan_pass)


# === Hit Reaction Effects ===

func play_hit_shake(intensity: float = 1.0) -> void:
	# Pause idle tweens during shake
	for tw in _idle_tweens:
		if tw and tw.is_valid():
			tw.set_speed_scale(0.0)

	var shake_tween = _hud.create_tween()
	var offset_x = 4.0 * intensity
	for i in range(6):
		var dx = randf_range(-offset_x, offset_x)
		shake_tween.tween_property(_idle_container, "position:x", _portrait_pos.x + dx, 0.03)
	shake_tween.tween_property(_idle_container, "position:x", _portrait_pos.x, 0.04)

	# Resume idle after shake
	shake_tween.tween_callback(func():
		for tw in _idle_tweens:
			if tw and tw.is_valid():
				tw.set_speed_scale(1.0)
	)


func play_hit_flash(color: Color, duration: float = 0.15) -> void:
	if not is_instance_valid(_portrait):
		return
	var flash_tween = _hud.create_tween()
	flash_tween.tween_property(_portrait, "modulate", color, duration * 0.3)
	flash_tween.tween_property(_portrait, "modulate", Color.WHITE, duration * 0.7)


func play_hit_particles(color: Color, count: int = 8) -> void:
	var center = _portrait_pos + _portrait_size / 2.0
	for i in range(count):
		var particle = ColorRect.new()
		var psize = randf_range(4.0, 8.0)
		particle.size = Vector2(psize, psize)
		particle.color = color
		particle.position = center + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(particle)

		var angle = randf_range(0, TAU)
		var dist = randf_range(30, 60)
		var tween = _hud.create_tween().set_parallel(true)
		tween.tween_property(particle, "position", particle.position + Vector2(cos(angle) * dist, sin(angle) * dist), 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.4)
		tween.tween_callback(particle.queue_free).set_delay(0.45)


func play_attack_lunge(target_x: float) -> void:
	# Pause idle during lunge
	for tw in _idle_tweens:
		if tw and tw.is_valid():
			tw.set_speed_scale(0.0)

	var lunge_dist = 20.0 if target_x < _portrait_pos.x else -20.0
	var lunge_tween = _hud.create_tween()
	lunge_tween.tween_property(_idle_container, "position:x", _portrait_pos.x + lunge_dist, 0.12).set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(_idle_container, "position:x", _portrait_pos.x, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Resume idle after lunge
	lunge_tween.tween_callback(func():
		for tw in _idle_tweens:
			if tw and tw.is_valid():
				tw.set_speed_scale(1.0)
	)
