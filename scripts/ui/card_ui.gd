class_name CardUI
extends Control
## Interactive card UI with animations - 240x330 for 1920x1080

signal card_clicked(card: CardUI)
signal inject_clicked(card: CardUI)

var card_def: Dictionary = {}
var is_bloom: bool = false
var char_theme_color: Color = Color("#00F0FF")  # 角色主题色，默认渗透者青色
var cost_override: int = -1
var injected_ep: int = 0
var original_scale: Vector2 = Vector2(1.0, 1.0)
var rest_y: float = 0.0
var hand_index: int = 0
var hovered: bool = false
var selected: bool = false
var fast_mode: bool = false  # Training mode: skip animations

const CARD_WIDTH = 240
const CARD_HEIGHT = 330

var card_bg: Panel
var card_style: StyleBoxFlat
var name_label: Label
var type_label: Label
var cost_label: Label
var desc_label: Label
var level_badge: Label
var evo_progress: ProgressBar
var evo_text_label: Label
var level_stars: HBoxContainer
var tooltip_panel: Panel

func _ready():
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	original_scale = scale
	rest_y = position.y
	# 获取当前角色主题色
	if RunRewardState.selected_character:
		var char_info = CardDatabase.get_character_info(RunRewardState.selected_character)
		char_theme_color = char_info.get("color", Color("#00F0FF"))
	_build_ui()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _build_ui():
	if card_style:
		return

	card_bg = Panel.new()
	card_bg.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_bg.position = Vector2.ZERO
	add_child(card_bg)

	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color("#0A0E27")
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color("#3B8CFF")
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_size = 6
	card_style.shadow_color = Color(0, 0, 0, 0.5)
	card_bg.add_theme_stylebox_override("panel", card_style)
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Inner panel
	var inner = Panel.new()
	inner.size = Vector2(CARD_WIDTH - 8, CARD_HEIGHT - 8)
	inner.position = Vector2(4, 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color("#0D1230")
	inner_style.corner_radius_top_left = 10
	inner_style.corner_radius_top_right = 10
	inner_style.corner_radius_bottom_left = 10
	inner_style.corner_radius_bottom_right = 10
	inner.add_theme_stylebox_override("panel", inner_style)
	card_bg.add_child(inner)

	# Cost
	cost_label = Label.new()
	cost_label.position = Vector2(12, 10)
	cost_label.size = Vector2(48, 44)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 28)
	cost_label.add_theme_color_override("font_color", Color("#FFD700"))
	card_bg.add_child(cost_label)

	var cost_bg = ColorRect.new()
	cost_bg.position = Vector2(10, 10)
	cost_bg.size = Vector2(50, 46)
	cost_bg.color = Color("#0A0E27")
	cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_bg.add_child(cost_bg)
	cost_bg.z_index = -1

	# Type label
	type_label = Label.new()
	type_label.position = Vector2(90, 14)
	type_label.size = Vector2(135, 24)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.add_theme_font_size_override("font_size", 17)
	card_bg.add_child(type_label)

	# Level badge
	level_badge = Label.new()
	level_badge.position = Vector2(12, 60)
	level_badge.size = Vector2(CARD_WIDTH - 24, 24)
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.add_theme_font_size_override("font_size", 15)
	level_badge.add_theme_color_override("font_color", Color("#888888"))
	card_bg.add_child(level_badge)

	# Level stars
	level_stars = HBoxContainer.new()
	level_stars.position = Vector2(55, 86)
	level_stars.size = Vector2(CARD_WIDTH - 110, 22)
	level_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	card_bg.add_child(level_stars)

	# Name
	name_label = Label.new()
	name_label.position = Vector2(12, 118)
	name_label.size = Vector2(CARD_WIDTH - 24, 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	card_bg.add_child(name_label)

	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(30, 156)
	sep.size = Vector2(CARD_WIDTH - 60, 2)
	sep.color = Color("#333366")
	card_bg.add_child(sep)

	# Description
	desc_label = Label.new()
	desc_label.position = Vector2(16, 166)
	desc_label.size = Vector2(CARD_WIDTH - 32, 72)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color("#BBBBBB"))
	card_bg.add_child(desc_label)

	# Evolution progress bar
	evo_progress = ProgressBar.new()
	evo_progress.position = Vector2(18, 248)
	evo_progress.size = Vector2(CARD_WIDTH - 76, 8)
	evo_progress.show_percentage = false
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color("#1A1A3A")
	progress_style.corner_radius_top_left = 3
	progress_style.corner_radius_top_right = 3
	progress_style.corner_radius_bottom_left = 3
	progress_style.corner_radius_bottom_right = 3
	evo_progress.add_theme_stylebox_override("background", progress_style)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color("#3BFF8C")
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	evo_progress.add_theme_stylebox_override("fill", fill_style)
	evo_progress.value = 0
	evo_progress.visible = false
	card_bg.add_child(evo_progress)

	# EP progress text
	evo_text_label = Label.new()
	evo_text_label.position = Vector2(CARD_WIDTH - 70, 244)
	evo_text_label.size = Vector2(56, 18)
	evo_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	evo_text_label.add_theme_font_size_override("font_size", 13)
	evo_text_label.add_theme_color_override("font_color", Color("#3BFF8C"))
	evo_text_label.visible = false
	card_bg.add_child(evo_text_label)

	# Right-click hint
	var hint = Label.new()
	hint.text = "右键=注入"
	hint.position = Vector2(14, 266)
	hint.size = Vector2(CARD_WIDTH - 28, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#555555"))
	card_bg.add_child(hint)

	# Keep progress indicator
	var keep_hint = Label.new()
	keep_hint.text = "弃牌保留进度"
	keep_hint.position = Vector2(14, 290)
	keep_hint.size = Vector2(CARD_WIDTH - 28, 20)
	keep_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep_hint.add_theme_font_size_override("font_size", 12)
	keep_hint.add_theme_color_override("font_color", Color("#444444"))
	card_bg.add_child(keep_hint)

func setup_card(def: Dictionary):
	card_def = def
	refresh_display()

func refresh_display():
	if not card_style:
		_build_ui()
	if card_def.is_empty():
		return

	var type = card_def.get("type", 0)
	var type_color = CardDatabase.TYPE_COLORS.get(type, Color.WHITE)
	var type_name = CardDatabase.TYPE_NAMES.get(type, "未知")

	# Border color: 使用角色主题色
	card_style.border_color = char_theme_color

	# Name
	name_label.text = card_def.get("name", "???")
	var cost = cost_override if cost_override >= 0 else card_def.get("cost", 0)
	if cost == 0:
		cost_label.text = "0"
		cost_label.add_theme_color_override("font_color", Color("#3BFF8C"))
		cost_label.add_theme_font_size_override("font_size", 26)
	else:
		cost_label.text = str(cost)
		cost_label.add_theme_color_override("font_color", Color("#FFD700"))
		cost_label.add_theme_font_size_override("font_size", 28)

	# Type
	type_label.text = type_name
	type_label.add_theme_color_override("font_color", type_color)

	# Level
	var level = card_def.get("level", 1)
	var level_text = "Lv." + str(level)
	if level >= 3:
		level_text += " ◆ MAX"
	level_badge.text = level_text

	# Stars
	for child in level_stars.get_children():
		child.free()
	for i in range(3):
		var star = Label.new()
		star.text = "★" if i < level else "☆"
		star.add_theme_font_size_override("font_size", 16)
		star.add_theme_color_override("font_color", type_color if i < level else Color("#444444"))
		level_stars.add_child(star)

	# Description
	desc_label.text = card_def.get("description", "")

	# Evolution progress visibility
	var evo_needed = card_def.get("ep_to_evolve", -1)
	evo_progress.visible = evo_needed > 0
	evo_text_label.visible = evo_needed > 0

	# Bloom indicator
	if is_bloom:
		name_label.add_theme_color_override("font_color", Color("#FFD700"))
		level_badge.text = "✦ 进化绽放 ✦"
		level_badge.add_theme_color_override("font_color", Color("#FFD700"))
		cost_label.text = "0"
		cost_label.add_theme_color_override("font_color", Color("#FFD700"))

func update_evolution_progress(progress: float):
	evo_progress.value = progress * 100
	if progress >= 1.0:
		evo_progress.modulate = Color.GOLD
		var tween = create_tween().set_loops()
		tween.tween_property(evo_progress, "modulate:a", 0.5, 0.3)
		tween.tween_property(evo_progress, "modulate:a", 1.0, 0.3)

func update_ep_text(text: String):
	evo_text_label.text = text

func _on_mouse_entered():
	hovered = true
	z_index = 100  # Bring to front so card is fully visible in stacked mode
	if not selected:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", original_scale * 1.12, 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position:y", rest_y - 15, 0.12).set_ease(Tween.EASE_OUT)

		card_style.shadow_size = 16
		card_style.shadow_color = Color(char_theme_color, 0.6)

	if card_def.get("type", 0) == 3 or card_def.has("evolution_family"):
		_show_tooltip()

func _on_mouse_exited():
	hovered = false
	if not selected:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", original_scale, 0.12).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "position:y", rest_y, 0.12).set_ease(Tween.EASE_IN)

		card_style.shadow_size = 6
		card_style.shadow_color = Color(0, 0, 0, 0.5)

		z_index = hand_index  # Restore stacking order
	_hide_tooltip()

func set_selected(is_selected: bool, highlight_color: Color = Color.WHITE):
	selected = is_selected
	if selected:
		var effective_highlight = highlight_color if highlight_color != Color.WHITE else Color(char_theme_color, 0.9)
		z_index = 100
		card_style.shadow_size = 20
		card_style.shadow_color = effective_highlight
		var tween = create_tween().set_parallel(true)
		tween.tween_property(self, "scale", original_scale * 1.15, 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position:y", rest_y - 30, 0.1).set_ease(Tween.EASE_OUT)
	else:
		card_style.shadow_size = 6
		card_style.shadow_color = Color(0, 0, 0, 0.5)
		if hovered:
			# Restore hover visual state
			z_index = 100
			card_style.shadow_size = 16
			card_style.shadow_color = Color(char_theme_color, 0.6)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(self, "scale", original_scale * 1.12, 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(self, "position:y", rest_y - 15, 0.1).set_ease(Tween.EASE_OUT)
		else:
			z_index = hand_index
			var tween = create_tween().set_parallel(true)
			tween.tween_property(self, "scale", original_scale, 0.1).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "position:y", rest_y, 0.1).set_ease(Tween.EASE_IN)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			inject_clicked.emit(self)

func _show_tooltip():
	if tooltip_panel:
		_hide_tooltip()

	var family = card_def.get("evolution_family", "")
	if family == "":
		return

	var chain = card_def.get("evolution_chain", [])
	if chain.is_empty():
		return

	tooltip_panel = Panel.new()
	tooltip_panel.position = Vector2(position.x, position.y - 200)
	tooltip_panel.size = Vector2(340, 220)
	tooltip_panel.z_index = 100

	var tip_style = StyleBoxFlat.new()
	tip_style.bg_color = Color("#0A0E27")
	tip_style.border_color = char_theme_color
	tip_style.border_width_left = 2
	tip_style.border_width_right = 2
	tip_style.border_width_top = 2
	tip_style.border_width_bottom = 2
	tip_style.corner_radius_top_left = 8
	tip_style.corner_radius_top_right = 8
	tip_style.corner_radius_bottom_left = 8
	tip_style.corner_radius_bottom_right = 8
	tooltip_panel.add_theme_stylebox_override("panel", tip_style)

	var tip_text = ""
	for i in range(chain.size()):
		var def = CardDatabase.get_card_def(chain[i])
		if def.is_empty():
			continue
		var lv = def.get("level", i + 1)
		var lv_label = "Lv." + str(lv) + ": " + def.get("description", "")
		if i > 0:
			tip_text += "\n"
		tip_text += lv_label

	tip_text += "\n\n弃牌保留进度"

	var tip_label = Label.new()
	tip_label.text = tip_text
	tip_label.position = Vector2(10, 8)
	tip_label.size = Vector2(316, 200)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_label.add_theme_font_size_override("font_size", 15)
	tip_label.add_theme_color_override("font_color", Color("#BBBBBB"))
	tooltip_panel.add_child(tip_label)

	get_parent().add_child(tooltip_panel)

func _hide_tooltip():
	if tooltip_panel:
		tooltip_panel.queue_free()
		tooltip_panel = null

func play_evolution_animation():
	if fast_mode:
		# Skip animation in fast mode
		return

	var tween = create_tween()

	var flash = ColorRect.new()
	flash.size = size
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	add_child(flash)

	tween.tween_property(flash, "modulate:a", 0.7, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, 0.1)
	tween.tween_property(flash, "modulate:a", 0.5, 0.05)
	tween.tween_property(flash, "modulate:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

	tween.tween_property(self, "scale", original_scale * 1.3, 0.15)
	tween.tween_property(self, "scale", original_scale, 0.2)

	if is_bloom:
		var shake_tween = create_tween()
		for i in range(8):
			shake_tween.tween_property(self, "rotation", randf_range(-0.05, 0.05), 0.03)
			shake_tween.tween_property(self, "rotation", randf_range(-0.03, 0.03), 0.03)
		shake_tween.tween_property(self, "rotation", 0.0, 0.05)

	var particles = _create_evo_particles()
	add_child(particles)

func _create_evo_particles() -> Node2D:
	var container = Node2D.new()
	container.position = size / 2

	var p_color = Color("#3BFF8C")
	if is_bloom:
		p_color = Color("#FFD700")

	for i in range(16):
		var rect = ColorRect.new()
		rect.size = Vector2(5, 5)
		rect.color = p_color
		rect.position = Vector2.ZERO
		container.add_child(rect)

		var angle = randf_range(0, TAU)
		var dist = randf_range(60, 160)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(rect, "position", Vector2(cos(angle) * dist, sin(angle) * dist), 0.45)
		tween.tween_property(rect, "modulate:a", 0.0, 0.45)
		tween.tween_property(rect, "scale", Vector2(0.2, 0.2), 0.45)

	get_tree().create_timer(0.55).timeout.connect(container.queue_free)
	return container
