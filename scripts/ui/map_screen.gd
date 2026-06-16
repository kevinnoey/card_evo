extends Control
## Map Screen - Network Infiltration Map (v2.0)
## Cyberpunk-style branching path map inspired by Slay the Spire
## Displays deep web topology with neon glow effects and data flow animations

# === Layout Constants ===
# Full screen
const SCREEN_WIDTH = 1920
const SCREEN_HEIGHT = 1080

# Map frame (centered rectangle where the map lives)
# Positioned to avoid overlap with action log panel (bottom-left)
const FRAME_X = 460        # Left edge of frame (right of log panel)
const FRAME_Y = 80         # Top edge of frame
const FRAME_WIDTH = 1420   # Frame width
const FRAME_HEIGHT = 920   # Frame height

# Map content (scrollable area inside frame)
const MAP_WIDTH = FRAME_WIDTH
const MAP_HEIGHT = 1800    # Scrollable content height (taller than frame)

# Nodes (larger icons)
const NODE_SIZE = 72
const NODE_SIZE_BOSS = 100

# Map area for node positioning (inside frame, with padding)
const MAP_PADDING = 40
const MAP_AREA_LEFT = FRAME_X + MAP_PADDING
const MAP_AREA_RIGHT = FRAME_X + FRAME_WIDTH - MAP_PADDING
const MAP_AREA_WIDTH = MAP_AREA_RIGHT - MAP_AREA_LEFT

# Layer spacing
const LAYER_SPACING = 105
const TOP_MARGIN = 100     # Space at top of scrollable content (clears header)
const BOTTOM_MARGIN = 100  # Space at bottom of scrollable content (clears footer)

# Node type display with cyberpunk theme
const NODE_ICONS = {
	"battle": "⚔️",
	"elite": "⚡",
	"event": "❓",
	"rest": "🏕️",
	"shop": "🛒",
	"boss": "💀"
}
const NODE_NAMES = {
	"battle": "数据节点",
	"elite": "防火墙",
	"event": "未知信号",
	"rest": "安全屋",
	"shop": "黑市",
	"boss": "核心系统"
}
# Cyberpunk color scheme for node types
const NODE_COLORS = {
	"battle": Color("#FF3B3B"),    # Red
	"elite": Color("#FF8C00"),     # Orange
	"event": Color("#B03BFF"),     # Purple
	"rest": Color("#3B8CFF"),      # Blue
	"shop": Color("#FFD700"),      # Gold
	"boss": Color("#FF1A1A")       # Bright Red
}

# Shop items
const SHOP_ITEMS = [
	{"id": "evo_module", "name": "进化模块", "price": 60, "desc": "选择一张卡牌\n+8 EP 注入进度", "icon": "🧬"},
	{"id": "nano_repair", "name": "纳米修复", "price": 40, "desc": "恢复 20 HP", "icon": "❤️"},
	{"id": "random_card", "name": "随机卡牌", "price": 50, "desc": "获得一张随机\nLv.1 卡牌", "icon": "🃏"},
	{"id": "remove_card", "name": "移除卡牌", "price": 70, "desc": "永久移除\n一张卡牌", "icon": "🗑️"},
	{"id": "energy_drink", "name": "能量饮料", "price": 30, "desc": "下场战斗\n+2 EP/回合", "icon": "⚡"},
	{"id": "reserve_boost", "name": "储备增压", "price": 45, "desc": "EP 储备池\n+8 进度", "icon": "🔋"},
]

# Member variables
var _scroll_container: ScrollContainer
var _map_container: Control
var _map_content: Control  # Content inside scroll container (full height)
var _line_layer: Control
var _node_layer: Control
var _bg_decorations: Control  # Background grid and effects
var _hp_label: Label
var _fragment_label: Label
var _chapter_label: Label
var _deck_label: Label
var _deck_viewer_btn: Button
var _music_btn: Button
var _volume_slider: HSlider
var _deck_overlay: Control
var _deck_grid: Control
var _deck_card_count_label: Label
var _node_buttons: Array = []  # 2D array of buttons [layer][index]
var _current_overlay: Control = null
var _returning_to_map: bool = false
var _pulse_tweens: Array = []
var _data_flow_tweens: Array = []  # Data flow animations on lines

# Drag-to-scroll variables
var _is_dragging: bool = false
var _is_pressing: bool = false  # Left mouse is pressed, but not yet dragging
var _drag_start_y: float = 0.0
var _press_start_y: float = 0.0  # Where mouse was pressed
var _scroll_start_y: float = 0.0
const DRAG_THRESHOLD = 8  # Minimum pixels to move before starting drag

# Action log panel (bottom-left, same style as battle HUD)
var _log_container: VBoxContainer
var _log_scroll: ScrollContainer
const MAX_LOG_ENTRIES = 50

const CardUIScene = preload("res://scenes/card_ui.tscn")

func _ready():
	# Check if we're returning from a battle
	if RunRewardState.last_battle_won or RunRewardState.pending_battle.has("enemy_key"):
		_returning_to_map = true

	_build_ui()

	# 监听全局日志信号，实时显示新条目
	ActionLog.entry_added.connect(_on_action_log_added)

	if _returning_to_map:
		_handle_return_from_battle()
		_returning_to_map = false
	else:
		_render_map()


func _input(event: InputEvent):
	"""Handle global input for drag-to-scroll on the map."""
	if not _scroll_container or not is_instance_valid(_scroll_container):
		return

	# Check if mouse is within the map frame area
	var mouse_pos = get_global_mouse_position()
	var in_frame = Rect2(FRAME_X, FRAME_Y, FRAME_WIDTH, FRAME_HEIGHT).has_point(mouse_pos)

	if not in_frame:
		# If mouse leaves frame, cancel drag/press
		_is_dragging = false
		_is_pressing = false
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start pressing (not dragging yet)
				_is_pressing = true
				_is_dragging = false
				_press_start_y = mouse_pos.y
				_drag_start_y = mouse_pos.y
				var scrollbar = _scroll_container.get_v_scroll_bar()
				_scroll_start_y = scrollbar.value if scrollbar else 0
			else:
				# 【优化】如果当前是在拖拽状态下松开鼠标，吞掉这个点击事件，防止误触地图上的节点
				if _is_dragging:
					get_viewport().set_input_as_handled()
				# Release - stop pressing/dragging
				_is_pressing = false
				_is_dragging = false

	elif event is InputEventMouseMotion:
		if _is_pressing and not _is_dragging:
			# Check if we've moved enough to start dragging
			var move_distance = abs(mouse_pos.y - _press_start_y)
			if move_distance > DRAG_THRESHOLD:
				_is_dragging = true
				_is_pressing = false
				# Update start values for smooth drag continuation
				_drag_start_y = _press_start_y
				var scrollbar = _scroll_container.get_v_scroll_bar()
				_scroll_start_y = scrollbar.value if scrollbar else 0

		if _is_dragging:
			# Scroll based on drag delta
			var current_y = mouse_pos.y
			var delta_y = _drag_start_y - current_y  # Invert for natural drag direction
			var scrollbar = _scroll_container.get_v_scroll_bar()
			if scrollbar:
				var new_value = _scroll_start_y + delta_y
				new_value = clamp(new_value, 0, scrollbar.max_value)
				scrollbar.value = new_value


# === UI BUILDING ===

func _build_ui():
	# === Background layer (fixed, full screen) ===
	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://card/背景.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg_tex.z_index = -10
	add_child(bg_tex)

	# Dark overlay
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.02, 0.02, 0.08, 0.75)
	bg_overlay.size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	bg_overlay.z_index = -9
	add_child(bg_overlay)

	# === Scroll container for the map (inside frame area) ===
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "MapScroll"
	_scroll_container.position = Vector2(FRAME_X, FRAME_Y)
	_scroll_container.size = Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Allow scroll wheel
	add_child(_scroll_container)

	# === Map content (scrollable, inside scroll container) ===
	_map_content = Control.new()
	_map_content.name = "MapContent"
	_map_content.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	# 【新增这行】这行代码是激活 ScrollContainer 滚轮和滚动条的灵魂！
	_map_content.custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_scroll_container.add_child(_map_content)

	# === Background decorations (grid, scan lines) ===
	_bg_decorations = Control.new()
	_bg_decorations.name = "BgDecorations"
	_bg_decorations.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_bg_decorations.z_index = -5
	_bg_decorations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(_bg_decorations)
	_build_cyberpunk_background()

	# === Map container for lines and nodes ===
	_map_container = Control.new()
	_map_container.name = "MapContainer"
	_map_container.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_map_content.add_child(_map_container)

	# Line layer (behind nodes)
	_line_layer = Control.new()
	_line_layer.name = "LineLayer"
	_line_layer.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_line_layer.z_index = -2
	_line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.add_child(_line_layer)

	# Node layer (on top of lines)
	_node_layer = Control.new()
	_node_layer.name = "NodeLayer"
	_node_layer.size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	_node_layer.z_index = 0
	_node_layer.mouse_filter = Control.MOUSE_FILTER_PASS  # 传递事件给子节点和父节点（滚轮/拖拽 + 点击）
	_map_container.add_child(_node_layer)

	# Top bar (fixed, full screen)
	_build_top_bar()

	# Action log panel (fixed, bottom-left)
	_build_log_panel()

	# Map title label at top of scroll content
	_build_map_title()

	# === Map frame (fixed overlay on top of scroll area) ===
	_build_map_frame()


func _build_cyberpunk_background():
	"""Build the cyberpunk grid and scan line effects."""
	# Grid lines
	var grid_color = Color("#2A2A5A", 0.15)
	var grid_spacing = 80

	for x in range(0, MAP_WIDTH, grid_spacing):
		var vline = ColorRect.new()
		vline.position = Vector2(x, 0)
		vline.size = Vector2(1, MAP_HEIGHT)
		vline.color = grid_color
		vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_decorations.add_child(vline)

	for y in range(0, MAP_HEIGHT, grid_spacing):
		var hline = ColorRect.new()
		hline.position = Vector2(0, y)
		hline.size = Vector2(MAP_WIDTH, 1)
		hline.color = grid_color
		hline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_decorations.add_child(hline)

	# Scan line effect
	var scan_line = ColorRect.new()
	scan_line.name = "ScanLine"
	scan_line.position = Vector2(0, 0)
	scan_line.size = Vector2(MAP_WIDTH, 3)
	scan_line.color = Color("#00F0FF", 0.08)
	scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_decorations.add_child(scan_line)

	var scan_tween = create_tween().set_loops()
	scan_tween.tween_property(scan_line, "position:y", MAP_HEIGHT, 8.0)
	scan_tween.tween_property(scan_line, "position:y", 0, 0)

	# Data particles
	for i in range(20):
		var particle = ColorRect.new()
		particle.position = Vector2(randf_range(20, MAP_WIDTH - 20), randf_range(0, MAP_HEIGHT))
		particle.size = Vector2(3, 3)
		particle.color = Color("#00F0FF", 0.3)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bg_decorations.add_child(particle)

		var particle_tween = create_tween().set_loops()
		particle_tween.tween_property(particle, "modulate:a", 0.1, randf_range(1.0, 3.0))
		particle_tween.tween_property(particle, "modulate:a", 0.8, randf_range(0.5, 1.5))


func _build_map_title():
	"""Build the map title at the top of the scroll content."""
	var title_container = Control.new()
	title_container.position = Vector2(0, 15)
	title_container.size = Vector2(MAP_WIDTH, 45)
	_map_content.add_child(title_container)

	var title = Label.new()
	title.text = "// 深网拓扑图 //"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 0)
	title.size = Vector2(MAP_WIDTH, 28)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#00F0FF", 0.8))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.add_child(title)

	#var subtitle = Label.new()
	#var chapter_name = "第一章: 外围防线" if RunRewardState.current_chapter == 1 else "第二章: 深层网络"
	#subtitle.text = chapter_name
	#subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#subtitle.position = Vector2(0, 28)
	#subtitle.size = Vector2(MAP_WIDTH, 20)
	#subtitle.add_theme_font_size_override("font_size", 14)
	#subtitle.add_theme_color_override("font_color", Color("#B03BFF", 0.6))
	#subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#title_container.add_child(subtitle)


func _build_map_frame():
	"""Build a cyberpunk-style frame around the scrollable map area."""
	# Frame container (positioned at FRAME_X, FRAME_Y)
	var frame = Control.new()
	frame.name = "MapFrame"
	frame.position = Vector2(FRAME_X, FRAME_Y)
	frame.size = Vector2(FRAME_WIDTH, FRAME_HEIGHT)
	frame.z_index = 50
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# Local coordinates for frame elements
	var fw = FRAME_WIDTH
	var fh = FRAME_HEIGHT

	# === Outer border (4 edges) ===
	var border_color = Color("#00F0FF", 0.7)
	var border_thick = 3

	# Top border
	var top_border = ColorRect.new()
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(fw, border_thick)
	top_border.color = border_color
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top_border)

	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.position = Vector2(0, fh - border_thick)
	bottom_border.size = Vector2(fw, border_thick)
	bottom_border.color = border_color
	bottom_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bottom_border)

	# Left border
	var left_border = ColorRect.new()
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_thick, fh)
	left_border.color = border_color
	left_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(left_border)

	# Right border
	var right_border = ColorRect.new()
	right_border.position = Vector2(fw - border_thick, 0)
	right_border.size = Vector2(border_thick, fh)
	right_border.color = border_color
	right_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(right_border)

	# === Outer glow ===
	var glow_color = Color("#00F0FF", 0.15)
	var glow_size = 10

	var top_glow = ColorRect.new()
	top_glow.position = Vector2(0, -glow_size)
	top_glow.size = Vector2(fw, glow_size)
	top_glow.color = glow_color
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(top_glow)

	var bottom_glow = ColorRect.new()
	bottom_glow.position = Vector2(0, fh)
	bottom_glow.size = Vector2(fw, glow_size)
	bottom_glow.color = glow_color
	bottom_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bottom_glow)

	var left_glow = ColorRect.new()
	left_glow.position = Vector2(-glow_size, 0)
	left_glow.size = Vector2(glow_size, fh)
	left_glow.color = glow_color
	left_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(left_glow)

	var right_glow = ColorRect.new()
	right_glow.position = Vector2(fw, 0)
	right_glow.size = Vector2(glow_size, fh)
	right_glow.color = glow_color
	right_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(right_glow)

	# === Inner border (thinner, purple) ===
	var inner_color = Color("#B03BFF", 0.4)
	var inner_thick = 1
	var inner_margin = 12

	var inner_top = ColorRect.new()
	inner_top.position = Vector2(inner_margin, inner_margin)
	inner_top.size = Vector2(fw - inner_margin * 2, inner_thick)
	inner_top.color = inner_color
	inner_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner_top)

	var inner_bottom = ColorRect.new()
	inner_bottom.position = Vector2(inner_margin, fh - inner_margin - inner_thick)
	inner_bottom.size = Vector2(fw - inner_margin * 2, inner_thick)
	inner_bottom.color = inner_color
	inner_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner_bottom)

	var inner_left = ColorRect.new()
	inner_left.position = Vector2(inner_margin, inner_margin)
	inner_left.size = Vector2(inner_thick, fh - inner_margin * 2)
	inner_left.color = inner_color
	inner_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner_left)

	var inner_right = ColorRect.new()
	inner_right.position = Vector2(fw - inner_margin - inner_thick, inner_margin)
	inner_right.size = Vector2(inner_thick, fh - inner_margin * 2)
	inner_right.color = inner_color
	inner_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner_right)

	# === L-shaped corner decorations (golden) ===
	var corner_color = Color("#FFD700", 0.85)
	var corner_len = 35
	var corner_thick = 4
	var c_margin = 6

	# Top-left
	var tl_h = ColorRect.new(); tl_h.position = Vector2(c_margin, c_margin); tl_h.size = Vector2(corner_len, corner_thick); tl_h.color = corner_color; tl_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(tl_h)
	var tl_v = ColorRect.new(); tl_v.position = Vector2(c_margin, c_margin); tl_v.size = Vector2(corner_thick, corner_len); tl_v.color = corner_color; tl_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(tl_v)

	# Top-right
	var tr_h = ColorRect.new(); tr_h.position = Vector2(fw - c_margin - corner_len, c_margin); tr_h.size = Vector2(corner_len, corner_thick); tr_h.color = corner_color; tr_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(tr_h)
	var tr_v = ColorRect.new(); tr_v.position = Vector2(fw - c_margin - corner_thick, c_margin); tr_v.size = Vector2(corner_thick, corner_len); tr_v.color = corner_color; tr_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(tr_v)

	# Bottom-left
	var bl_h = ColorRect.new(); bl_h.position = Vector2(c_margin, fh - c_margin - corner_thick); bl_h.size = Vector2(corner_len, corner_thick); bl_h.color = corner_color; bl_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(bl_h)
	var bl_v = ColorRect.new(); bl_v.position = Vector2(c_margin, fh - c_margin - corner_len); bl_v.size = Vector2(corner_thick, corner_len); bl_v.color = corner_color; bl_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(bl_v)

	# Bottom-right
	var br_h = ColorRect.new(); br_h.position = Vector2(fw - c_margin - corner_len, fh - c_margin - corner_thick); br_h.size = Vector2(corner_len, corner_thick); br_h.color = corner_color; br_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(br_h)
	var br_v = ColorRect.new(); br_v.position = Vector2(fw - c_margin - corner_thick, fh - c_margin - corner_len); br_v.size = Vector2(corner_thick, corner_len); br_v.color = corner_color; br_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_child(br_v)

	# === Top header bar ===
	var header_bg = ColorRect.new()
	header_bg.position = Vector2(0, 0)
	header_bg.size = Vector2(fw, 40)
	header_bg.color = Color("#060610", 0.9)
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(header_bg)

	var header_line = ColorRect.new()
	header_line.position = Vector2(0, 40)
	header_line.size = Vector2(fw, 2)
	header_line.color = Color("#B03BFF", 0.8)
	header_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(header_line)

	var header_title = Label.new()
	header_title.text = "◈ NETWORK INFILTRATION MAP ◈"
	header_title.position = Vector2(0, 8)
	header_title.size = Vector2(fw, 24)
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title.add_theme_font_size_override("font_size", 18)
	header_title.add_theme_color_override("font_color", Color("#00F0FF"))
	header_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(header_title)

	# === Bottom status bar ===
	var footer_bg = ColorRect.new()
	footer_bg.position = Vector2(0, fh - 32)
	footer_bg.size = Vector2(fw, 32)
	footer_bg.color = Color("#060610", 0.9)
	footer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(footer_bg)

	var footer_line = ColorRect.new()
	footer_line.position = Vector2(0, fh - 32)
	footer_line.size = Vector2(fw, 2)
	footer_line.color = Color("#B03BFF", 0.8)
	footer_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(footer_line)

	var footer_hint = Label.new()
	footer_hint.text = "◇ SCROLL TO NAVIGATE ◇"
	footer_hint.position = Vector2(0, fh - 26)
	footer_hint.size = Vector2(fw, 20)
	footer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_hint.add_theme_font_size_override("font_size", 12)
	footer_hint.add_theme_color_override("font_color", Color("#B03BFF", 0.7))
	footer_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(footer_hint)

	# === Side tick marks ===
	var tick_color = Color("#00F0FF", 0.3)
	for y_pos in range(60, fh - 40, 80):
		var tick_l = ColorRect.new()
		tick_l.position = Vector2(0, y_pos)
		tick_l.size = Vector2(5, 1)
		tick_l.color = tick_color
		tick_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tick_l)

		var tick_r = ColorRect.new()
		tick_r.position = Vector2(fw - 5, y_pos)
		tick_r.size = Vector2(5, 1)
		tick_r.color = tick_color
		tick_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tick_r)

	# === Breathing animation on outer border ===
	var breathe = create_tween().set_loops()
	breathe.tween_property(top_border, "modulate:a", 0.5, 2.0)
	breathe.tween_property(top_border, "modulate:a", 1.0, 2.0)
	var breathe_b = create_tween().set_loops()
	breathe_b.tween_property(bottom_border, "modulate:a", 0.5, 2.0)
	breathe_b.tween_property(bottom_border, "modulate:a", 1.0, 2.0)
	var breathe_l = create_tween().set_loops()
	breathe_l.tween_property(left_border, "modulate:a", 0.5, 2.0)
	breathe_l.tween_property(left_border, "modulate:a", 1.0, 2.0)
	var breathe_r = create_tween().set_loops()
	breathe_r.tween_property(right_border, "modulate:a", 0.5, 2.0)
	breathe_r.tween_property(right_border, "modulate:a", 1.0, 2.0)


func _build_top_bar():
	# HP display (top-left)
	_hp_label = Label.new()
	_hp_label.position = Vector2(40, 20)
	_hp_label.add_theme_font_size_override("font_size", 24)
	_hp_label.add_theme_color_override("font_color", Color("#3BFF8C"))
	add_child(_hp_label)

	# Chapter title (top-center)
	_chapter_label = Label.new()
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_label.position = Vector2(660, 15)
	_chapter_label.size = Vector2(600, 40)
	_chapter_label.add_theme_font_size_override("font_size", 28)
	_chapter_label.add_theme_color_override("font_color", Color("#00F0FF"))
	add_child(_chapter_label)

	# Fragment display (top-right)
	_fragment_label = Label.new()
	_fragment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fragment_label.position = Vector2(1520, 20)
	_fragment_label.size = Vector2(360, 40)
	_fragment_label.add_theme_font_size_override("font_size", 24)
	_fragment_label.add_theme_color_override("font_color", Color("#00BFFF"))
	add_child(_fragment_label)

	# Deck count (below HP)
	_deck_label = Label.new()
	_deck_label.position = Vector2(40, 55)
	_deck_label.add_theme_font_size_override("font_size", 26)
	_deck_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	add_child(_deck_label)

	# Deck viewer button (next to deck count)
	_deck_viewer_btn = Button.new()
	_deck_viewer_btn.text = "📋 查看"
	_deck_viewer_btn.position = Vector2(40, 100)
	_deck_viewer_btn.size = Vector2(100, 30)
	_deck_viewer_btn.add_theme_font_size_override("font_size", 26)
	_deck_viewer_btn.add_theme_color_override("font_color", Color("#00F0FF"))
	var dk_style = StyleBoxFlat.new()
	dk_style.bg_color = Color("#1A1A3A")
	dk_style.border_color = Color("#00F0FF")
	dk_style.border_width_left = 1; dk_style.border_width_right = 1
	dk_style.border_width_top = 1; dk_style.border_width_bottom = 1
	dk_style.corner_radius_top_left = 4; dk_style.corner_radius_top_right = 4
	dk_style.corner_radius_bottom_left = 4; dk_style.corner_radius_bottom_right = 4
	_deck_viewer_btn.add_theme_stylebox_override("normal", dk_style)
	var dk_hover = dk_style.duplicate()
	dk_hover.bg_color = Color("#2A2A5A")
	dk_hover.border_color = Color("#FFFFFF")
	_deck_viewer_btn.add_theme_stylebox_override("hover", dk_hover)
	_deck_viewer_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_deck_viewer_btn.pressed.connect(_on_deck_viewer_btn_pressed)
	add_child(_deck_viewer_btn)

	# Music toggle button (top-right, below fragment counter)
	_music_btn = Button.new()
	_music_btn.position = Vector2(50, 500)
	_music_btn.size = Vector2(150, 50)
	_music_btn.add_theme_font_size_override("font_size", 20)
	_music_btn.add_theme_color_override("font_color", Color("#00F0FF") if not AudioManager.is_muted() else Color("#888888"))
	var music_style = StyleBoxFlat.new()
	music_style.bg_color = Color("#1A1A3A")
	music_style.border_color = Color("#00F0FF") if not AudioManager.is_muted() else Color("#666666")
	music_style.border_width_left = 1; music_style.border_width_right = 1
	music_style.border_width_top = 1; music_style.border_width_bottom = 1
	music_style.corner_radius_top_left = 4; music_style.corner_radius_top_right = 4
	music_style.corner_radius_bottom_left = 4; music_style.corner_radius_bottom_right = 4
	_music_btn.add_theme_stylebox_override("normal", music_style)
	var music_hover = music_style.duplicate()
	music_hover.bg_color = Color("#2A2A5A")
	music_hover.border_color = Color("#FFFFFF")
	_music_btn.add_theme_stylebox_override("hover", music_hover)
	_music_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_music_btn.pressed.connect(_on_music_btn_pressed)
	add_child(_music_btn)
	_update_music_btn_text()
	AudioManager.music_toggled.connect(_on_music_toggled)

	# Volume slider (below music button)
	var vol_label = Label.new()
	vol_label.text = "音量"
	vol_label.position = Vector2(50, 558)
	vol_label.add_theme_font_size_override("font_size", 18)
	vol_label.add_theme_color_override("font_color", Color("#AAAAAA"))
	add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.position = Vector2(100, 558)
	_volume_slider.size = Vector2(120, 30)
	_volume_slider.min_value = -40.0
	_volume_slider.max_value = 0.0
	_volume_slider.step = 1.0
	_volume_slider.value = AudioManager.get_music_volume()
	_volume_slider.scrollable = false
	_volume_slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_volume_slider.value_changed.connect(_on_volume_slider_changed)
	AudioManager.volume_changed.connect(_on_volume_changed)
	add_child(_volume_slider)

	# Shield display (below deck)
	var shield_label = Label.new()
	shield_label.name = "ShieldLabel"
	shield_label.position = Vector2(140, 20)
	shield_label.add_theme_font_size_override("font_size", 16)
	shield_label.add_theme_color_override("font_color", Color("#FFD700"))
	add_child(shield_label)

	_update_top_bar()


func _update_top_bar():
	_hp_label.text = "❤️ %d/%d" % [RunRewardState.player_hp, RunRewardState.player_max_hp]
	_fragment_label.text = "💠 %d 数据碎片" % RunRewardState.data_fragments

	var chapter_name = "第一章 — 外围防线" if RunRewardState.current_chapter == 1 else "第二章 — 深层网络"
	_chapter_label.text = chapter_name

	_deck_label.text = "🃏 牌库: %d 张" % RunRewardState.player_deck.size()

	var shield_lbl = get_node_or_null("ShieldLabel")
	if shield_lbl:
		if RunRewardState.player_energy_shield > 0:
			shield_lbl.text = "🛡️ 能量护盾: %d" % RunRewardState.player_energy_shield
		else:
			shield_lbl.text = ""


# === MAP RENDERING ===

func _render_map():
	# Clear existing nodes and lines
	for child in _line_layer.get_children():
		child.queue_free()
	for child in _node_layer.get_children():
		child.queue_free()
	_node_buttons.clear()
	_kill_pulse_tweens()
	_kill_data_flow_tweens()

	var map_data = RunRewardState.current_map_data
	if not map_data.has("layers"):
		return

	var layers = map_data["layers"]

	# Draw connection lines based on node.connections
	for layer_idx in range(layers.size() - 1):
		var current_layer_nodes = layers[layer_idx]["nodes"]
		var next_layer_nodes = layers[layer_idx + 1]["nodes"]

		for node_idx in range(current_layer_nodes.size()):
			var node = current_layer_nodes[node_idx]
			var connections = node.get("connections", [])
			var from_pos = _get_node_position_from_x(node["x"], layer_idx)

			for conn_idx in connections:
				if conn_idx < next_layer_nodes.size():
					var next_node = next_layer_nodes[conn_idx]
					var to_pos = _get_node_position_from_x(next_node["x"], layer_idx + 1)

					# Determine line style based on completion status
					var line_type = "normal"
					if node.get("completed", false):
						line_type = "completed"
					elif node.get("available", false):
						line_type = "active"

					_draw_neon_connection_line(from_pos, to_pos, line_type)

	# Create node buttons
	for layer_idx in range(layers.size()):
		var layer_buttons = []
		var nodes = layers[layer_idx]["nodes"]
		for node_idx in range(nodes.size()):
			var node = nodes[node_idx]
			var pos = _get_node_position_from_x(node["x"], layer_idx)
			var btn = _create_cyber_node(node, pos)
			_node_layer.add_child(btn)
			layer_buttons.append(btn)
		_node_buttons.append(layer_buttons)

	_update_top_bar()

	# Scroll to show current available nodes
	_scroll_to_current_layer()


func _get_node_position_from_x(x_ratio: float, layer_idx: int) -> Vector2:
	"""Convert relative x position (0-1) and layer index to map content coordinates."""
	# X: map from 0-1 ratio to position within map area (local to map content)
	var local_x = MAP_PADDING + x_ratio * (MAP_WIDTH - MAP_PADDING * 2)

	# Y: layers go from bottom (layer 0) to top (highest layer)
	var local_y = MAP_HEIGHT - BOTTOM_MARGIN - (layer_idx * LAYER_SPACING)

	return Vector2(local_x, local_y)


func _scroll_to_current_layer():
	"""Scroll the map to show the current available layer."""
	if RunRewardState.current_layer < 0:
		return

	# Calculate the Y position of the current layer in map content
	var target_y = MAP_HEIGHT - BOTTOM_MARGIN - (RunRewardState.current_layer * LAYER_SPACING)

	# We want this to be roughly in the middle of the visible frame
	var scroll_target = target_y - (FRAME_HEIGHT / 2)
	scroll_target = clamp(scroll_target, 0, MAP_HEIGHT - FRAME_HEIGHT)

	# Smooth scroll to target
	await get_tree().create_timer(0.3).timeout
	if _scroll_container and is_instance_valid(_scroll_container):
		var scrollbar = _scroll_container.get_v_scroll_bar()
		if scrollbar:
			var tween = create_tween()
			tween.tween_property(scrollbar, "value", scroll_target, 0.5).set_ease(Tween.EASE_OUT)


func _create_cyber_node(node: Dictionary, pos: Vector2) -> Button:
	"""Create a cyberpunk-styled node button."""
	var is_boss = node.get("type", "") == "boss"
	var btn_size = NODE_SIZE_BOSS if is_boss else NODE_SIZE
	var btn = Button.new()
	btn.position = pos - Vector2(btn_size / 2, btn_size / 2)
	btn.size = Vector2(btn_size, btn_size)
	btn.flat = true

	var is_completed = node.get("completed", false)
	var is_available = node.get("available", false)
	var node_type = node.get("type", "battle")
	var type_color = NODE_COLORS.get(node_type, Color("#00F0FF"))

	# Style based on state
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = btn_size / 2
	style.corner_radius_top_right = btn_size / 2
	style.corner_radius_bottom_left = btn_size / 2
	style.corner_radius_bottom_right = btn_size / 2

	var icon_color: Color
	var border_color: Color
	var border_width: float
	var bg_color: Color

	if is_completed:
		bg_color = Color("#0A2A0A", 0.9)
		border_color = Color("#3BFF8C", 1.0)
		border_width = 3.0
		btn.disabled = true
		icon_color = Color("#3BFF8C", 0.8)
	elif is_available:
		bg_color = Color("#0A0A2A", 0.95)
		border_color = type_color
		border_width = 3.0
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon_color = type_color
		# Pulse animation for available nodes
		var tween = create_tween().set_loops()
		tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.8)
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.8)
		_pulse_tweens.append(tween)
	else:
		bg_color = Color("#1A1A1A", 0.6)
		border_color = Color("#3A3A5A", 0.5)
		border_width = 2.0
		btn.disabled = true
		icon_color = Color("#555555", 0.6)

	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	# Glow effect
	if is_available or is_completed:
		style.shadow_size = 12
		style.shadow_color = Color(border_color, 0.5)

	btn.add_theme_stylebox_override("normal", style)

	# Hover style
	var hover_style = style.duplicate()
	hover_style.border_color = Color("#FFD700", 1.0)
	hover_style.border_width_left = 4
	hover_style.border_width_right = 4
	hover_style.border_width_top = 4
	hover_style.border_width_bottom = 4
	hover_style.shadow_size = 18
	hover_style.shadow_color = Color("#FFD700", 0.6)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Outer glow ring
	var ring = Line2D.new()
	ring.width = 2.0 if is_available else 1.5
	ring.default_color = Color(border_color, 0.6 if is_available else 0.3)
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	var center = Vector2(btn_size / 2, btn_size / 2)
	var ring_radius = btn_size / 2 + 4
	for i in range(25):
		var angle = (i / 24.0) * TAU
		ring.add_point(center + Vector2(cos(angle) * ring_radius, sin(angle) * ring_radius))
	ring.add_point(center + Vector2(ring_radius, 0))
	btn.add_child(ring)

	# Icon label
	var icon_text = NODE_ICONS.get(node_type, "?")
	var icon = Label.new()
	icon.text = icon_text
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.size = Vector2(btn_size, btn_size)
	icon.add_theme_font_size_override("font_size", 40 if is_boss else 32)
	icon.add_theme_color_override("font_color", icon_color)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# Tooltip
	var tooltip = NODE_NAMES.get(node_type, node_type)
	if node.has("enemy_key") and node["enemy_key"] != "" and (is_available or is_completed):
		tooltip += "\n" + _get_enemy_display_name(node["enemy_key"])
	btn.tooltip_text = tooltip

	# Connect click signal
	if is_available and not is_completed:
		var layer = node.get("layer", 0)
		var index = node.get("index", 0)
		btn.pressed.connect(_on_node_clicked.bind(layer, index))

	return btn


func _draw_neon_connection_line(from: Vector2, to: Vector2, line_type: String = "normal"):
	"""Draw a neon-glowing connection line between two points."""
	var line_color: Color
	var glow_color: Color
	var line_width: float
	var glow_width: float

	match line_type:
		"completed":
			line_color = Color("#3BFF8C", 0.9)
			glow_color = Color("#3BFF8C", 0.3)
			line_width = 2.5
			glow_width = 8.0
		"active":
			line_color = Color("#00F0FF", 0.8)
			glow_color = Color("#00F0FF", 0.25)
			line_width = 2.0
			glow_width = 6.0
		_:
			line_color = Color("#4A4AFF", 0.4)
			glow_color = Color("#4A4AFF", 0.1)
			line_width = 1.5
			glow_width = 4.0

	# Outer glow line
	var glow_line = Line2D.new()
	glow_line.width = glow_width
	glow_line.default_color = glow_color
	glow_line.add_point(from)
	glow_line.add_point(to)
	_line_layer.add_child(glow_line)

	# Main line
	var line = Line2D.new()
	line.width = line_width
	line.default_color = line_color
	line.add_point(from)
	line.add_point(to)
	_line_layer.add_child(line)

	# Data flow animation for active lines
	if line_type == "active":
		_add_data_flow_animation(from, to, line_color)


func _add_data_flow_animation(from: Vector2, to: Vector2, color: Color):
	"""Add a data flow animation (moving dot) along a connection line."""
	var dot = ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.color = color
	dot.position = from
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_layer.add_child(dot)

	# Animate dot from start to end
	var tween = create_tween().set_loops()
	tween.tween_property(dot, "position", to, 1.5)
	tween.tween_property(dot, "position", from, 0)
	_data_flow_tweens.append(tween)


func _kill_data_flow_tweens():
	"""Kill all data flow animation tweens."""
	for tween in _data_flow_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_data_flow_tweens.clear()


func _get_enemy_display_name(enemy_key: String) -> String:
	# Map enemy keys to display names
	var names = {
		"enemy_a": "防火墙哨兵",
		"enemy_b": "脉冲中继器",
		"enemy_c": "数据腐化体",
		"enemy_d": "加密守护者",
		"enemy_e": "虚空信标",
		"enemy_f": "湮灭协议·原型",
		"enemy_g": "内存吞噬者",
		"enemy_h": "矩阵哨卫",
		"enemy_i": "主控中枢·格式化巨兽",
		"enemy_b_ch2": "脉冲中继器·改",
		"enemy_c_ch2": "数据腐化体·改",
		"enemy_d_ch2": "加密守护者·改",
	}
	return names.get(enemy_key, enemy_key)


# === NODE CLICK HANDLING ===

func _on_node_clicked(layer: int, index: int):
	var map_data = RunRewardState.current_map_data
	if not map_data.has("layers") or layer >= map_data["layers"].size():
		return

	var node = map_data["layers"][layer]["nodes"][index]
	var node_type = node.get("type", "")

	match node_type:
		"battle", "elite", "boss":
			_enter_battle(node)
		"event":
			_show_event_overlay(node)
		"shop":
			_show_shop_overlay(node)
		"rest":
			_show_rest_overlay(node)


func _enter_battle(node: Dictionary):
	"""Set up battle config and transition to battle scene."""
	var enemy_key = node.get("enemy_key", "")
	var enemy_name = _get_enemy_display_name(enemy_key)
	var node_type = node.get("type", "battle")
	var prefix = "⚡ 精英战斗" if node_type == "elite" else ("👹 Boss 战" if node_type == "boss" else "⚔️ 进入战斗")
	ActionLog.add_log("%s：[color=#FF6B35]%s[/color]" % [prefix, enemy_name], Color("#FF6B35"))

	# Store pending battle info in RunRewardState
	RunRewardState.pending_battle = {
		"enemy_key": node.get("enemy_key", ""),
		"node_type": node.get("type", "battle"),
		"node_layer": node.get("layer", 0),
		"node_index": node.get("index", 0),
		"is_elite": node.get("type", "") == "elite"
	}
	RunRewardState.last_battle_won = false
	RunRewardState.fragments_earned = 0

	# Transition to battle scene
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


# === RETURN FROM BATTLE ===

func _handle_return_from_battle():
	"""Called when returning from battle scene. Process results and re-render map."""
	var pending = RunRewardState.pending_battle
	if pending.is_empty():
		_render_map()
		return

	var layer = pending.get("node_layer", 0)
	var index = pending.get("node_index", 0)

	if RunRewardState.last_battle_won:
		ActionLog.add_log("═══ 返回地图 ═══", Color("#888888"))

		# Mark node as completed
		RunRewardState.complete_node(layer, index)

		# Check if boss was defeated
		if RunRewardState.is_boss_node(layer, index):
			_handle_boss_defeated()
			return
	else:
		# Player lost - game over
		_show_game_over()
		return

	# Clear pending battle
	RunRewardState.pending_battle = {}
	RunRewardState.last_battle_won = false

	_render_map()


func _handle_boss_defeated():
	"""Handle boss node completion - chapter transition or game victory."""
	if RunRewardState.current_chapter == 1:
		# Chapter 1 boss defeated - show core breakthrough
		_show_core_breakthrough()
	else:
		# Chapter 2 boss defeated - game victory!
		_show_victory_screen()


# === EVENT OVERLAY ===

func _show_event_overlay(node: Dictionary):
	"""Show event panel with story text and choices."""
	var event_key = node.get("event_key", "")
	var event_data = EventDatabase.get_event(event_key)
	if event_data.is_empty():
		# Fallback: just complete the node
		RunRewardState.complete_node(node["layer"], node["index"])
		_render_map()
		return

	ActionLog.add_log("📡 发现未知事件：[color=#00FFFF]%s[/color]" % event_data.get("title", "事件"), Color("#00FFFF"))

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	# Main panel
	var panel = _create_centered_panel(900, 500, Color("#0A0E27"), Color("#B03BFF"))
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = event_data.get("title", "事件")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 30)
	title.size = Vector2(800, 40)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Story text
	var story = RichTextLabel.new()
	story.text = event_data.get("story", "")
	story.bbcode_enabled = true
	story.position = Vector2(50, 90)
	story.size = Vector2(800, 120)
	story.add_theme_font_size_override("normal_font_size", 18)
	story.add_theme_color_override("default_color", Color("#CCCCCC"))
	panel.add_child(story)

	# Choice buttons
	var choices = event_data.get("choices", [])
	var y_offset = 230
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.get("text", "")
		btn.position = Vector2(80, y_offset)
		btn.size = Vector2(740, 55)
		btn.add_theme_font_size_override("font_size", 18)

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#1A1A3A", 0.9)
		btn_style.border_color = Color("#B03BFF")
		btn_style.border_width_left = 1
		btn_style.border_width_right = 1
		btn_style.border_width_top = 1
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 8
		btn_style.corner_radius_top_right = 8
		btn_style.corner_radius_bottom_left = 8
		btn_style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = btn_style.duplicate()
		hover_style.border_color = Color("#FFD700")
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_color_override("font_color", Color("#EEEEFF"))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		btn.pressed.connect(_on_event_choice_selected.bind(node, choice, overlay))
		panel.add_child(btn)
		y_offset += 70


func _on_event_choice_selected(node: Dictionary, choice: Dictionary, overlay: Control):
	"""Execute the chosen event effect."""
	var effect = choice.get("effect", "")
	var result_text = choice.get("result_text", "效果已生效。")

	ActionLog.add_log("▶ 选择：%s" % choice.get("text", ""), Color("#FFFFFF"))

	# Execute effect
	var needs_card_selector = _execute_event_effect(effect, choice)

	if needs_card_selector:
		# Some effects need a card selector (copy_card, remove_card)
		# Keep the overlay but show result + card selector
		_show_event_result_with_card_selector(node, choice, overlay, result_text, effect)
	else:
		# Show result text, then close
		_show_event_result_and_close(node, overlay, result_text)


func _execute_event_effect(effect: String, choice: Dictionary) -> bool:
	"""Execute an event effect. Returns true if a card selector is needed."""
	match effect:
		"random_ep_inject":
			var amount = choice.get("amount", 8)
			var fam = _inject_ep_to_random_family(amount)
			if fam != "":
				ActionLog.add_log("💉 随机注入 [color=#FFD700]%d EP[/color] 到 [color=#00F0FF]%s[/color] 族" % [amount, fam], Color("#FFD700"))
			else:
				ActionLog.add_log("💉 储备池 [color=#FFD700]+%d[/color]（所有卡族已满级）" % amount, Color("#FFD700"))

		"add_fragments":
			var amount = choice.get("amount", 20)
			RunRewardState.add_fragments(amount)
			ActionLog.add_log("💎 获得 [color=#00BFFF]%d[/color] 数据碎片" % amount, Color("#00BFFF"))

		"buy_ep_per_turn":
			var cost = choice.get("cost", 25)
			if RunRewardState.spend_fragments(cost):
				RunRewardState.permanent_ep_bonus += 1
				ActionLog.add_log("🛒 购买协议：永久 [color=#FFD700]+1 EP[/color] (-%d 碎片)" % cost, Color("#FF8C00"))
			else:
				return false  # Not enough fragments

		"buy_heal":
			var cost = choice.get("cost", 15)
			var amount = choice.get("amount", 20)
			if RunRewardState.spend_fragments(cost):
				RunRewardState.heal_player(amount)
				ActionLog.add_log("🛒 购买治疗：[color=#3BFF8C]+%d HP[/color] (-%d 碎片)" % [amount, cost], Color("#3BFF8C"))

		"report_merchant":
			var amount = choice.get("amount", 10)
			RunRewardState.add_fragments(amount)
			RunRewardState.next_battle_enemy_bonus_strength += 2
			ActionLog.add_log("🔍 举报商人 — 获得 [color=#00BFFF]%d[/color] 碎片（下场敌人强化）" % amount, Color("#FF6B35"))

		"copy_card":
			return true  # Needs card selector

		"smash_device":
			var hp_cost = choice.get("hp_cost", 5)
			var amount = choice.get("amount", 15)
			RunRewardState.damage_player(hp_cost)
			RunRewardState.add_fragments(amount)
			ActionLog.add_log("💥 摧毁设备 — [color=#FF3B3B]-%d HP[/color]，[color=#00BFFF]+%d[/color] 碎片" % [hp_cost, amount], Color("#FF6B35"))

		"resist_storm":
			var hp_cost = choice.get("hp_cost", 10)
			var reserve = choice.get("reserve_amount", 5)
			RunRewardState.damage_player(hp_cost)
			RunRewardState.reserve_pool = mini(RunRewardState.reserve_pool + reserve, 15)
			ActionLog.add_log("⚡ 抵抗风暴 — [color=#FF3B3B]-%d HP[/color]，储备池 [color=#FFD700]+%d[/color]" % [hp_cost, reserve], Color("#FF6B35"))

		"lower_shield":
			var hp_cost = choice.get("hp_cost", 8)
			var amount = choice.get("amount", 30)
			RunRewardState.damage_player(hp_cost)
			RunRewardState.add_fragments(amount)
			ActionLog.add_log("🛡️ 降低护盾 — [color=#FF3B3B]-%d HP[/color]，[color=#00BFFF]+%d[/color] 碎片" % [hp_cost, amount], Color("#FF6B35"))

		"remove_card":
			return true  # Needs card selector

		"upgrade_card":
			var amount = choice.get("amount", 8)
			var fam = _inject_ep_to_random_family(amount)
			if fam != "":
				ActionLog.add_log("⬆️ 升级卡牌：[color=#FFD700]+%d EP[/color] 到 [color=#00F0FF]%s[/color] 族" % [amount, fam], Color("#FFD700"))
			else:
				ActionLog.add_log("⬆️ 储备池 [color=#FFD700]+%d[/color]（所有卡族已满级）" % amount, Color("#FFD700"))

		"temp_ep_bonus":
			var amount = choice.get("amount", 3)
			RunRewardState.next_battle_temp_bonus.ep_per_turn_add += amount
			ActionLog.add_log("⚡ 临时 EP 加成：下场战斗 [color=#FFD700]+%d EP/回合[/color]" % amount, Color("#FFD700"))

		"add_shield":
			var amount = choice.get("amount", 1)
			RunRewardState.player_energy_shield += amount
			ActionLog.add_log("🛡️ 获得 [color=#00FFFF]%d[/color] 层能量护盾" % amount, Color("#00FFFF"))

		"sacrifice_hp_ep":
			var hp_cost = choice.get("hp_cost", 10)
			var amount = choice.get("amount", 12)
			RunRewardState.damage_player(hp_cost)
			var fam = _inject_ep_to_random_family(amount)
			if fam != "":
				ActionLog.add_log("💀 献祭 [color=#FF3B3B]%d HP[/color] → [color=#FFD700]+%d EP[/color] 到 [color=#00F0FF]%s[/color]" % [hp_cost, amount, fam], Color("#FF3B35"))
			else:
				ActionLog.add_log("💀 献祭 [color=#FF3B3B]%d HP[/color] → 储备池 [color=#FFD700]+%d[/color]" % [hp_cost, amount], Color("#FF3B35"))

		"sacrifice_hp_ep_per_turn":
			var hp_cost = choice.get("hp_cost", 20)
			RunRewardState.damage_player(hp_cost)
			RunRewardState.permanent_ep_bonus += 1
			ActionLog.add_log("💀 献祭 [color=#FF3B3B]%d HP[/color] → 永久 [color=#FFD700]+1 EP/回合[/color]" % hp_cost, Color("#FF3B35"))

		"leave":
			ActionLog.add_log("🚪 选择离开", Color("#888888"))

	return false


func _inject_ep_to_random_family(amount: int) -> String:
	"""Inject EP into a random card family that isn't max level. Returns the target family name."""
	var families = _get_families_in_deck()
	# Filter to families not at max level
	var eligible = []
	for fam in families:
		if RunRewardState.family_max_level.get(fam, 1) < 3:
			eligible.append(fam)

	if eligible.is_empty():
		# All maxed - add to reserve instead
		RunRewardState.reserve_pool = mini(RunRewardState.reserve_pool + amount, 15)
		return ""

	var target = eligible[randi() % eligible.size()]
	if not RunRewardState.card_ep_by_family.has(target):
		RunRewardState.card_ep_by_family[target] = 0
	RunRewardState.card_ep_by_family[target] += amount

	# Check for evolution
	_check_evolution_threshold(target)
	return target


func _check_evolution_threshold(family: String):
	"""Check if a family should evolve based on accumulated EP."""
	var ep = RunRewardState.card_ep_by_family.get(family, 0)
	var current_level = RunRewardState.family_max_level.get(family, 1)

	if current_level == 1 and ep >= 8:
		RunRewardState.family_max_level[family] = 2
	elif current_level == 2 and ep >= 20:
		RunRewardState.family_max_level[family] = 3


func _get_families_in_deck() -> Array:
	"""Get unique evolution families from the player's deck."""
	var families = []
	for card_id in RunRewardState.player_deck:
		var family = RunRewardState._get_family_for_card(card_id)
		if not families.has(family):
			families.append(family)
	return families


func _show_event_result_and_close(node: Dictionary, overlay: Control, result_text: String):
	"""Show result text briefly, then close overlay and complete node."""
	# Clear overlay content and show result
	for child in overlay.get_children():
		child.queue_free()

	var result_panel = _create_centered_panel(700, 250, Color("#0A0E27"), Color("#3BFF8C"))
	overlay.add_child(result_panel)

	var result_label = RichTextLabel.new()
	result_label.text = result_text
	result_label.bbcode_enabled = true
	result_label.position = Vector2(40, 40)
	result_label.size = Vector2(620, 100)
	result_label.add_theme_font_size_override("normal_font_size", 20)
	result_label.add_theme_color_override("default_color", Color("#EEEEFF"))
	result_panel.add_child(result_label)

	var close_btn = Button.new()
	close_btn.text = "继续"
	close_btn.position = Vector2(250, 170)
	close_btn.size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#1A3A1A")
	btn_style.border_color = Color("#3BFF8C")
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.add_theme_color_override("font_color", Color("#3BFF8C"))
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(func():
		_complete_node_and_rerender(node)
	)
	result_panel.add_child(close_btn)


func _show_event_result_with_card_selector(node: Dictionary, choice: Dictionary, overlay: Control, result_text: String, effect: String):
	"""Show card selector for copy/remove effects."""
	# Clear overlay
	for child in overlay.get_children():
		child.queue_free()

	var panel = _create_centered_panel(1200, 700, Color("#0A0E27"), Color("#00F0FF"))
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "选择一张卡牌" if effect == "copy_card" else "选择要移除的卡牌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1100, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Build card grid
	_build_card_selector_in_panel(panel, effect == "copy_card", node)


func _complete_node_and_rerender(node: Dictionary):
	"""Complete a non-battle node and re-render the map."""
	RunRewardState.complete_node(node["layer"], node["index"])
	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null
	_render_map()


# === SHOP OVERLAY ===

func _show_shop_overlay(node: Dictionary):
	"""Show shop panel with purchasable items."""
	ActionLog.add_log("🛒 进入商店 — 数据碎片：[color=#00BFFF]%d[/color]" % RunRewardState.data_fragments, Color("#FFD700"))

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(1100, 650, Color("#0A0E27"), Color("#FFD700"))
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "🛒 数据商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1000, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	# Fragment display
	var frag_label = Label.new()
	frag_label.name = "ShopFragLabel"
	frag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frag_label.position = Vector2(700, 20)
	frag_label.size = Vector2(350, 40)
	frag_label.add_theme_font_size_override("font_size", 22)
	frag_label.add_theme_color_override("font_color", Color("#00BFFF"))
	frag_label.text = "💠 %d 碎片" % RunRewardState.data_fragments
	panel.add_child(frag_label)

	# Items grid (2 rows × 3 columns)
	var col = 0
	var row = 0
	for item in SHOP_ITEMS:
		var x = 50 + col * 340
		var y = 80 + row * 250
		_create_shop_item(panel, item, x, y, node)
		col += 1
		if col >= 3:
			col = 0
			row += 1

	# Leave button
	var leave_btn = Button.new()
	leave_btn.text = "离开商店"
	leave_btn.position = Vector2(400, 580)
	leave_btn.size = Vector2(300, 50)
	leave_btn.add_theme_font_size_override("font_size", 22)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#1A1A3A")
	btn_style.border_color = Color("#FFD700")
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	leave_btn.add_theme_stylebox_override("normal", btn_style)
	leave_btn.add_theme_color_override("font_color", Color("#FFD700"))
	leave_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	leave_btn.pressed.connect(func(): _complete_node_and_rerender(node))
	panel.add_child(leave_btn)


func _create_shop_item(parent: Control, item: Dictionary, x: float, y: float, node: Dictionary):
	var item_panel = Panel.new()
	item_panel.position = Vector2(x, y)
	item_panel.size = Vector2(310, 220)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#12122A", 0.9)
	style.border_color = Color("#3A3A5A")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	item_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(item_panel)

	# Icon
	var icon = Label.new()
	icon.text = item.get("icon", "?")
	icon.position = Vector2(130, 10)
	icon.size = Vector2(50, 50)
	icon.add_theme_font_size_override("font_size", 36)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_panel.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.text = item.get("name", "")
	name_label.position = Vector2(10, 60)
	name_label.size = Vector2(290, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color("#FFD700"))
	item_panel.add_child(name_label)

	# Description
	var desc = Label.new()
	desc.text = item.get("desc", "")
	desc.position = Vector2(10, 95)
	desc.size = Vector2(290, 60)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color("#CCCCCC"))
	item_panel.add_child(desc)

	# Price
	var price_label = Label.new()
	price_label.text = "💠 %d" % item.get("price", 0)
	price_label.position = Vector2(10, 155)
	price_label.size = Vector2(290, 25)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 18)
	price_label.add_theme_color_override("font_color", Color("#00BFFF"))
	item_panel.add_child(price_label)

	# Buy button
	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.position = Vector2(80, 180)
	buy_btn.size = Vector2(150, 35)
	buy_btn.add_theme_font_size_override("font_size", 16)
	var can_afford = RunRewardState.data_fragments >= item.get("price", 0)

	var buy_style = StyleBoxFlat.new()
	buy_style.bg_color = Color("#1A3A1A", 0.9) if can_afford else Color("#2A1A1A", 0.5)
	buy_style.border_color = Color("#3BFF8C") if can_afford else Color("#555555")
	buy_style.border_width_left = 1
	buy_style.border_width_right = 1
	buy_style.border_width_top = 1
	buy_style.border_width_bottom = 1
	buy_style.corner_radius_top_left = 6
	buy_style.corner_radius_top_right = 6
	buy_style.corner_radius_bottom_left = 6
	buy_style.corner_radius_bottom_right = 6
	buy_btn.add_theme_stylebox_override("normal", buy_style)
	buy_btn.add_theme_color_override("font_color", Color("#3BFF8C") if can_afford else Color("#555555"))
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW
	buy_btn.disabled = not can_afford

	if can_afford:
		buy_btn.pressed.connect(_on_shop_item_bought.bind(item, node, parent))
	item_panel.add_child(buy_btn)


func _on_shop_item_bought(item: Dictionary, node: Dictionary, shop_panel: Control):
	"""Handle purchasing a shop item."""
	var price = item.get("price", 0)
	if not RunRewardState.spend_fragments(price):
		return

	var item_name = item.get("name", "")
	var item_id = item.get("id", "")
	ActionLog.add_log("🛒 购买 [color=#FFD700]%s[/color] (-%d 碎片)" % [item_name, price], Color("#FF8C00"))

	match item_id:
		"evo_module":
			# Show card selector for EP injection
			_close_shop_and_show_card_selector_for_ep(node)
			return
		"nano_repair":
			RunRewardState.heal_player(20)
			ActionLog.add_log("  → [color=#3BFF8C]恢复 20 HP[/color] (当前 %d/%d)" % [RunRewardState.player_hp, RunRewardState.player_max_hp], Color("#3BFF8C"))
		"random_card":
			_give_random_card()
		"remove_card":
			_close_shop_and_show_card_selector_for_removal(node)
			return
		"energy_drink":
			RunRewardState.next_battle_temp_bonus.ep_per_turn_add += 2
			ActionLog.add_log("  → 下场战斗 [color=#FFD700]+2 EP/回合[/color]", Color("#FFD700"))
		"reserve_boost":
			RunRewardState.reserve_pool = mini(RunRewardState.reserve_pool + 8, 15)
			ActionLog.add_log("  → 储备池 [color=#FFD700]+8[/color] (当前 %d/15)" % RunRewardState.reserve_pool, Color("#FFD700"))

	# Update shop display
	_update_top_bar()
	# Refresh shop (re-render to update button states)
	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null
	_show_shop_overlay(node)


func _give_random_card():
	"""Give the player a random Lv.1 card."""
	# Get all base card IDs from CardDatabase
	var all_cards = _get_all_base_card_ids()
	if all_cards.is_empty():
		return
	var random_card = all_cards[randi() % all_cards.size()]
	RunRewardState.add_card_to_deck(random_card)
	ActionLog.add_log("🃏 获得随机卡牌：[color=#00F0FF]%s[/color]" % random_card, Color("#00F0FF"))


func _get_all_base_card_ids() -> Array:
	"""Get all base (Lv.1) card IDs from CardDatabase."""
	# Hardcoded list of all 20 base card IDs
	return [
		"c01_basic_probe", "c02_basic_probe_b", "c03_basic_probe_c",
		"c04_basic_firewall", "c05_basic_firewall_b", "c06_basic_firewall_c",
		"c07_data_overload", "c08_light_scan",
		"c09_deep_infiltrate", "c10_shield_reconstruct",
		"c11_heavy_strike", "c12_quick_scan", "c13_ep_amplify",
		"c14_overload_pulse", "c15_fortify", "c16_system_draw",
		"c17_quick_inject", "c18_mirror_shield",
		"c19_core_overclock", "c20_barrier_matrix"
	]


func _close_shop_and_show_card_selector_for_ep(node: Dictionary):
	"""Close shop and show card selector for evolution module purchase."""
	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(1200, 700, Color("#0A0E27"), Color("#FFD700"))
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "选择一张卡牌注入 +8 EP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1100, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	_build_card_selector_in_panel(panel, false, node, true)  # inject_mode = true


func _close_shop_and_show_card_selector_for_removal(node: Dictionary):
	"""Close shop and show card selector for card removal."""
	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(1200, 700, Color("#0A0E27"), Color("#FF3B3B"))
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "选择要移除的卡牌"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1100, 40)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("#FF3B3B"))
	panel.add_child(title)

	_build_card_selector_in_panel(panel, false, node, false, true)  # remove_mode = true


# === REST OVERLAY ===

func _show_rest_overlay(node: Dictionary):
	"""Show rest point with two options: heal or inject EP."""
	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(800, 400, Color("#0A0E27"), Color("#3B8CFF"))
	overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "🏕️ 休息点"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 30)
	title.size = Vector2(700, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#3B8CFF"))
	panel.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = "你发现了一个安全的节点，可以稍作休整。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(50, 85)
	desc.size = Vector2(700, 30)
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color("#CCCCCC"))
	panel.add_child(desc)

	# Option 1: Heal 15 HP
	var heal_btn = _create_rest_option_button(
		"恢复 15 HP", "❤️ 当前: %d/%d" % [RunRewardState.player_hp, RunRewardState.player_max_hp],
		Vector2(100, 150), Color("#3BFF8C")
	)
	heal_btn.pressed.connect(func():
		RunRewardState.heal_player(15)
		ActionLog.add_log("🏕️ 休息：[color=#3BFF8C]恢复 15 HP[/color] (当前 %d/%d)" % [RunRewardState.player_hp, RunRewardState.player_max_hp], Color("#3BFF8C"))
		_complete_node_and_rerender(node)
	)
	panel.add_child(heal_btn)

	# Option 2: Inject 4 EP to random card
	var inject_btn = _create_rest_option_button(
		"随机卡牌 +4 EP", "🧬 注入进化进度",
		Vector2(100, 260), Color("#FFD700")
	)
	inject_btn.pressed.connect(func():
		var fam = _inject_ep_to_random_family(4)
		if fam != "":
			ActionLog.add_log("🏕️ 休息：[color=#FFD700]+4 EP[/color] 到 [color=#00F0FF]%s[/color] 族" % fam, Color("#FFD700"))
		else:
			ActionLog.add_log("🏕️ 休息：储备池 [color=#FFD700]+4[/color]（所有卡族已满级）", Color("#FFD700"))
		_complete_node_and_rerender(node)
	)
	panel.add_child(inject_btn)


func _create_rest_option_button(text: String, sub_text: String, pos: Vector2, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text + "\n" + sub_text
	btn.position = pos
	btn.size = Vector2(600, 80)
	btn.add_theme_font_size_override("font_size", 20)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#1A1A3A", 0.9)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.border_color = Color("#FFD700")
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 3
	hover_style.border_width_bottom = 3
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_color_override("font_color", color)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn


# === CARD SELECTOR ===

func _build_card_selector_in_panel(panel: Control, is_copy: bool, node: Dictionary, inject_mode: bool = false, remove_mode: bool = false):
	"""Build a grid of CardUI instances for card selection.
	is_copy: if true, selecting adds a copy to deck
	inject_mode: if true, selecting injects 8 EP to that family
	remove_mode: if true, selecting removes the card from deck
	"""
	var families = _get_families_in_deck()
	var cols = 5
	var card_w = 168  # 240 * 0.7
	var card_h = 231  # 330 * 0.7
	var gap_x = 18
	var gap_y = 20
	var start_x = 60
	var start_y = 80

	var count = 0
	for family in families:
		var col = count % cols
		var row = count / cols
		var x = start_x + col * (card_w + gap_x)
		var y = start_y + row * (card_h + gap_y + 30)

		# Find the base card_id for this family
		var base_card_id = _find_base_card_for_family(family)
		if base_card_id == "":
			continue

		# Get card definition (potentially evolved)
		var max_level = RunRewardState.family_max_level.get(family, 1)
		var display_card_id = base_card_id
		if max_level >= 3:
			display_card_id = base_card_id + "_l3"
		elif max_level >= 2:
			display_card_id = base_card_id + "_l2"

		var card_def = _get_card_def_safe(display_card_id)
		if card_def.is_empty():
			card_def = _get_card_def_safe(base_card_id)
		if card_def.is_empty():
			continue

		# Create CardUI
		var card_ui = CardUIScene.instantiate()
		card_ui.position = Vector2(x, y)
		card_ui.scale = Vector2(0.7, 0.7)
		panel.add_child(card_ui)
		card_ui.setup_card(card_def.duplicate())

		# Add EP progress info
		var ep = RunRewardState.card_ep_by_family.get(family, 0)
		var progress_label = Label.new()
		if max_level >= 3:
			progress_label.text = "MAX"
			progress_label.add_theme_color_override("font_color", Color("#FFD700"))
		else:
			var needed = 8 if max_level == 1 else 20
			progress_label.text = "%d/%d EP" % [ep, needed]
			progress_label.add_theme_color_override("font_color", Color("#3BFF8C"))
		progress_label.position = Vector2(x + 10, y + card_h + 2)
		progress_label.add_theme_font_size_override("font_size", 14)
		panel.add_child(progress_label)

		# Make clickable via a transparent button overlay
		var click_btn = Button.new()
		click_btn.flat = true
		click_btn.position = Vector2(x, y)
		click_btn.size = Vector2(card_w, card_h)
		click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.add_child(click_btn)

		if is_copy:
			click_btn.pressed.connect(func():
				RunRewardState.add_card_to_deck(base_card_id)
				ActionLog.add_log("📋 复制卡牌：[color=#FFD700]%s[/color]" % base_card_id, Color("#FFD700"))
				_complete_node_and_rerender(node)
			)
		elif inject_mode:
			click_btn.pressed.connect(func():
				# Inject 8 EP to the selected family
				if not RunRewardState.card_ep_by_family.has(family):
					RunRewardState.card_ep_by_family[family] = 0
				RunRewardState.card_ep_by_family[family] += 8
				_check_evolution_threshold(family)
				ActionLog.add_log("🧬 注入 [color=#FFD700]8 EP[/color] 到 [color=#00F0FF]%s[/color] 族" % family, Color("#FFD700"))
				_complete_node_and_rerender(node)
			)
		elif remove_mode:
			# Find the index of a card with this family in the deck
			click_btn.pressed.connect(func():
				var idx = _find_deck_index_for_family(family)
				if idx >= 0:
					RunRewardState.remove_card_from_deck(idx)
				ActionLog.add_log("🗑️ 移除卡牌：[color=#FF3B3B]%s[/color]" % family, Color("#FF3B3B"))
				_complete_node_and_rerender(node)
			)

		count += 1


func _find_base_card_for_family(family: String) -> String:
	"""Find a base card ID in the player's deck that belongs to the given family."""
	for card_id in RunRewardState.player_deck:
		if RunRewardState._get_family_for_card(card_id) == family:
			return card_id
	return ""


func _find_deck_index_for_family(family: String) -> int:
	"""Find the index of the first card in deck belonging to the given family."""
	for i in range(RunRewardState.player_deck.size()):
		if RunRewardState._get_family_for_card(RunRewardState.player_deck[i]) == family:
			return i
	return -1


func _get_card_def_safe(card_id: String) -> Dictionary:
	"""Safely get card definition, returning empty dict if not found."""
	return CardDatabase.get_card_def(card_id)


# === CHAPTER TRANSITION ===

func _show_core_breakthrough():
	"""Show core breakthrough protocol selection after Chapter 1 boss."""
	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(1100, 650, Color("#0A0E27"), Color("#B03BFF"))
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "⚡ 核心突破 ⚡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 20)
	title.size = Vector2(1000, 50)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#B03BFF"))
	panel.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "第一章完成 — 选择一项突破协议"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(50, 75)
	subtitle.size = Vector2(1000, 30)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("#CCCCCC"))
	panel.add_child(subtitle)

	# Protocol options
	var protocols = _get_random_protocols(3)
	for i in range(protocols.size()):
		var proto = protocols[i]
		var x = 50 + i * 350
		_create_protocol_card(panel, proto, x, 130)


func _get_random_protocols(count: int) -> Array:
	var all_protocols = [
		{"name": "超限跃迁", "desc": "手牌上限 +1（6张）\n每场战斗第1回合失去5 HP", "color": Color("#B03BFF")},
		{"name": "涌动核心", "desc": "储备池上限 → 20\n护盾节点: 5/10/15/20", "color": Color("#FFD700")},
		{"name": "基因飞升", "desc": "所有 Lv.1 卡牌\n直接升至 Lv.2", "color": Color("#00F0FF")},
		{"name": "屏障转化", "desc": "回合结束时\n50% 屏障 → 永久最大HP", "color": Color("#3B8CFF")},
		{"name": "超频过载", "desc": "永久 +1 EP/回合\n受到伤害 +1", "color": Color("#FF3B3B")},
	]
	all_protocols.shuffle()
	return all_protocols.slice(0, count)


func _create_protocol_card(parent: Control, proto: Dictionary, x: float, y: float):
	var card_panel = Panel.new()
	card_panel.position = Vector2(x, y)
	card_panel.size = Vector2(300, 380)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#12122A", 0.9)
	style.border_color = proto.get("color", Color.WHITE)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	card_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(card_panel)

	# Name
	var name_label = Label.new()
	name_label.text = proto.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(10, 30)
	name_label.size = Vector2(280, 40)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", proto.get("color", Color.WHITE))
	card_panel.add_child(name_label)

	# Description
	var desc = Label.new()
	desc.text = proto.get("desc", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(10, 90)
	desc.size = Vector2(280, 100)
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color("#CCCCCC"))
	card_panel.add_child(desc)

	# Select button
	var btn = Button.new()
	btn.text = "选择"
	btn.position = Vector2(75, 310)
	btn.size = Vector2(150, 45)
	btn.add_theme_font_size_override("font_size", 20)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#1A1A3A")
	btn_style.border_color = proto.get("color", Color.WHITE)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", proto.get("color", Color.WHITE))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_protocol_chosen.bind(proto.get("name", "")))
	card_panel.add_child(btn)


func _on_protocol_chosen(protocol_name: String):
	"""Handle protocol selection after Chapter 1 boss."""
	RunRewardState.add_protocol(protocol_name)
	ActionLog.add_log("⚡ 选择突破协议：[color=#B03BFF]%s[/color]" % protocol_name, Color("#B03BFF"))

	# Apply immediate effects
	if protocol_name == "基因飞升":
		for family in _get_families_in_deck():
			if RunRewardState.family_max_level.get(family, 1) < 2:
				RunRewardState.card_ep_by_family[family] = 8
				RunRewardState.family_max_level[family] = 2

	# Transition to Chapter 2
	RunRewardState.current_chapter = 2
	RunRewardState._generate_map()
	RunRewardState.pending_battle = {}
	RunRewardState.last_battle_won = false

	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	_render_map()


func _show_victory_screen():
	"""Show victory screen after defeating Chapter 2 boss."""
	ActionLog.add_log("🏆 [color=#FFD700]通关成功！[/color]", Color("#FFD700"))

	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(900, 500, Color("#0A0E27"), Color("#FFD700"))
	overlay.add_child(panel)

	var title = Label.new()
	title.text = "🏆 通关成功 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 40)
	title.size = Vector2(800, 60)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	panel.add_child(title)

	var char_name_v = CardDatabase.get_character_info(RunRewardState.selected_character).get("name", "渗透者")
	var stats_text = char_name_v + "成功突破了深层网络！\n\n"
	stats_text += "牌库: %d 张卡牌\n" % RunRewardState.player_deck.size()
	stats_text += "数据碎片: %d\n" % RunRewardState.data_fragments
	stats_text += "能量护盾: %d 层\n" % RunRewardState.player_energy_shield
	var evolved_count = 0
	for fam in RunRewardState.family_max_level:
		if RunRewardState.family_max_level[fam] >= 3:
			evolved_count += 1
	stats_text += "完全进化: %d 张卡牌达到 Lv.3" % evolved_count

	var stats = Label.new()
	stats.text = stats_text
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.position = Vector2(50, 130)
	stats.size = Vector2(800, 200)
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color("#CCCCCC"))
	panel.add_child(stats)

	var restart_btn = Button.new()
	restart_btn.text = "返回主菜单"
	restart_btn.position = Vector2(300, 400)
	restart_btn.size = Vector2(300, 60)
	restart_btn.add_theme_font_size_override("font_size", 24)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#1A1A3A")
	btn_style.border_color = Color("#FFD700")
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_color_override("font_color", Color("#FFD700"))
	restart_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart_btn.pressed.connect(func():
		RunRewardState.reset()
		get_tree().change_scene_to_file("res://scenes/login_screen.tscn")
	)
	panel.add_child(restart_btn)


func _show_game_over():
	"""Show game over screen when player dies."""
	var char_name_d = CardDatabase.get_character_info(RunRewardState.selected_character).get("name", "渗透者")
	ActionLog.add_log("💀 [color=#FF3B3B]" + char_name_d + "阵亡 — 游戏结束[/color]", Color("#FF3B3B"))

	if _current_overlay:
		_current_overlay.queue_free()
		_current_overlay = null

	var overlay = _create_overlay_bg()
	_current_overlay = overlay

	var panel = _create_centered_panel(800, 400, Color("#1A0A0A"), Color("#FF3B3B"))
	overlay.add_child(panel)

	var title = Label.new()
	var char_name_dt = CardDatabase.get_character_info(RunRewardState.selected_character).get("name", "渗透者")
	title.text = "💀 " + char_name_dt + "阵亡 💀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(50, 40)
	title.size = Vector2(700, 60)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#FF3B3B"))
	panel.add_child(title)

	var desc = Label.new()
	desc.text = "你的数据被永久擦除...\n但每一次失败都是新的开始。"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.position = Vector2(50, 130)
	desc.size = Vector2(700, 80)
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color("#CCCCCC"))
	panel.add_child(desc)

	var restart_btn = Button.new()
	restart_btn.text = "返回主菜单"
	restart_btn.position = Vector2(250, 300)
	restart_btn.size = Vector2(300, 60)
	restart_btn.add_theme_font_size_override("font_size", 24)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#2A1A1A")
	btn_style.border_color = Color("#FF3B3B")
	btn_style.border_width_left = 2
	btn_style.border_width_right = 2
	btn_style.border_width_top = 2
	btn_style.border_width_bottom = 2
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	restart_btn.add_theme_stylebox_override("normal", btn_style)
	restart_btn.add_theme_color_override("font_color", Color("#FF3B3B"))
	restart_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	restart_btn.pressed.connect(func():
		RunRewardState.reset()
		get_tree().change_scene_to_file("res://scenes/login_screen.tscn")
	)
	panel.add_child(restart_btn)


# === UTILITY FUNCTIONS ===

func _create_overlay_bg() -> Control:
	"""Create a full-screen semi-transparent overlay background."""
	var overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	overlay.add_child(bg)
	add_child(overlay)
	return overlay


func _create_centered_panel(w: float, h: float, bg_color: Color, border_color: Color) -> Panel:
	"""Create a centered panel with border styling."""
	var panel = Panel.new()
	panel.size = Vector2(w, h)
	panel.position = Vector2((1920 - w) / 2, (1080 - h) / 2)
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _kill_pulse_tweens():
	for tween in _pulse_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_pulse_tweens.clear()


# === ACTION LOG PANEL ===

func _build_log_panel():
	"""Create the action log panel at bottom-left (same style as battle HUD)."""
	var log_panel = Panel.new()
	log_panel.position = Vector2(20, 640)
	log_panel.size = Vector2(380, 360)
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0, 0, 0, 0.7)
	log_style.border_color = Color("#00F0FF", 0.6)
	log_style.border_width_left = 2
	log_style.border_width_top = 2
	log_style.border_width_right = 2
	log_style.border_width_bottom = 2
	log_style.corner_radius_top_left = 8
	log_style.corner_radius_top_right = 8
	log_style.corner_radius_bottom_left = 8
	log_style.corner_radius_bottom_right = 8
	log_panel.add_theme_stylebox_override("panel", log_style)
	add_child(log_panel)

	var log_title = Label.new()
	log_title.text = "📋 行动日志"
	log_title.position = Vector2(10, 5)
	log_title.size = Vector2(360, 25)
	log_title.add_theme_font_size_override("font_size", 20)
	log_title.add_theme_color_override("font_color", Color("#00F0FF"))
	log_panel.add_child(log_title)

	_log_scroll = ScrollContainer.new()
	_log_scroll.position = Vector2(5, 30)
	_log_scroll.size = Vector2(370, 305)
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(_log_scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 2)
	_log_scroll.add_child(_log_container)

	# 回放历史日志
	for entry in ActionLog.get_entries():
		_add_log_entry(entry["text"], entry["color"], entry["time_str"])


func _on_action_log_added(text: String, color: Color, time_str: String):
	"""ActionLog 信号回调 — 实时显示新条目"""
	_add_log_entry(text, color, time_str)


func _add_log_entry(text: String, color: Color, time_str: String):
	"""创建 RichTextLabel 并添加到日志面板"""
	if not _log_container:
		return

	while _log_container.get_child_count() >= MAX_LOG_ENTRIES:
		var oldest = _log_container.get_child(0)
		_log_container.remove_child(oldest)
		oldest.free()

	var log_entry = RichTextLabel.new()
	log_entry.bbcode_enabled = true
	log_entry.fit_content = true
	log_entry.scroll_active = false
	log_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_entry.add_theme_font_size_override("normal_font_size", 18)
	log_entry.add_theme_color_override("default_color", color)
	log_entry.text = "[color=#666666][" + time_str + "][/color] " + text

	_log_container.add_child(log_entry)

	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom():
	if _log_scroll and is_inside_tree():
		var scrollbar = _log_scroll.get_v_scroll_bar()
		if scrollbar:
			scrollbar.value = scrollbar.max_value


# === Deck Viewer ===

func _on_deck_viewer_btn_pressed():
	"""Handle deck viewer button click."""
	_show_deck_viewer()

func _on_music_btn_pressed():
	"""Handle music toggle button click."""
	AudioManager.toggle_music()

func _on_music_toggled(_is_muted: bool):
	"""Update music button when AudioManager toggles."""
	_update_music_btn_text()

func _on_volume_slider_changed(value_db: float):
	"""Handle volume slider drag."""
	AudioManager.set_music_volume(value_db)

func _on_volume_changed(value_db: float):
	"""Update slider when AudioManager volume changes externally."""
	if _volume_slider and is_instance_valid(_volume_slider):
		_volume_slider.value = value_db

func _update_music_btn_text():
	"""Update music button text and style based on mute state."""
	if not _music_btn or not is_instance_valid(_music_btn):
		return
	var muted = AudioManager.is_muted()
	_music_btn.text = " 音乐: " + ("OFF" if muted else "ON")
	_music_btn.add_theme_color_override("font_color", Color("#888888") if muted else Color("#00F0FF"))
	var music_style = StyleBoxFlat.new()
	music_style.bg_color = Color("#1A1A3A")
	music_style.border_color = Color("#666666") if muted else Color("#00F0FF")
	music_style.border_width_left = 1; music_style.border_width_right = 1
	music_style.border_width_top = 1; music_style.border_width_bottom = 1
	music_style.corner_radius_top_left = 4; music_style.corner_radius_top_right = 4
	music_style.corner_radius_bottom_left = 4; music_style.corner_radius_bottom_right = 4
	_music_btn.add_theme_stylebox_override("normal", music_style)
	var music_hover = music_style.duplicate()
	music_hover.bg_color = Color("#2A2A5A")
	music_hover.border_color = Color("#FFFFFF")
	_music_btn.add_theme_stylebox_override("hover", music_hover)

func _show_deck_viewer():
	"""Show deck viewer popup (CardUI style, full-size cards)."""
	if _deck_overlay:
		_deck_overlay.queue_free()
		_deck_overlay = null

	_deck_overlay = Control.new()
	_deck_overlay.name = "DeckViewer"
	_deck_overlay.top_level = true
	_deck_overlay.position = Vector2.ZERO
	_deck_overlay.size = Vector2(1920, 1080)
	_deck_overlay.z_index = 100
	_deck_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_deck_overlay)

	# Dark background
	var dim = ColorRect.new()
	dim.size = Vector2(1920, 1080)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_overlay.add_child(dim)

	# Main panel
	var panel = Panel.new()
	panel.position = Vector2(200, 60)
	panel.size = Vector2(1520, 960)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color("#0A0E27")
	ps.border_color = Color("#00F0FF")
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left = 16; ps.corner_radius_top_right = 16
	ps.corner_radius_bottom_left = 16; ps.corner_radius_bottom_right = 16
	panel.add_theme_stylebox_override("panel", ps)
	_deck_overlay.add_child(panel)

	# Title
	var title = Label.new()
	title.text = "📋 当前卡组"
	title.position = Vector2(50, 15)
	title.size = Vector2(600, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#FFD700"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	# Card count
	_deck_card_count_label = Label.new()
	_deck_card_count_label.text = "共 %d 张" % RunRewardState.player_deck.size()
	_deck_card_count_label.position = Vector2(660, 18)
	_deck_card_count_label.size = Vector2(200, 35)
	_deck_card_count_label.add_theme_font_size_override("font_size", 20)
	_deck_card_count_label.add_theme_color_override("font_color", Color("#CCCCCC"))
	_deck_card_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_deck_card_count_label)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.position = Vector2(1340, 12)
	close_btn.size = Vector2(140, 40)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color("#FF6B35"))
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color("#1A1A3A")
	cs.border_color = Color("#FF6B35")
	cs.border_width_left = 1; cs.border_width_right = 1
	cs.border_width_top = 1; cs.border_width_bottom = 1
	cs.corner_radius_top_left = 8; cs.corner_radius_top_right = 8
	cs.corner_radius_bottom_left = 8; cs.corner_radius_bottom_right = 8
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_deck_viewer)
	panel.add_child(close_btn)

	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(50, 60)
	sep.size = Vector2(1420, 2)
	sep.color = Color("#00F0FF", 0.5)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sep)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 70)
	scroll.size = Vector2(1500, 880)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_deck_grid = Control.new()
	_deck_grid.custom_minimum_size = Vector2(1480, 0)
	_deck_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_deck_grid)

	_build_deck_grid_in_viewer()

	# Entrance animation
	_deck_overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_deck_overlay, "modulate:a", 1.0, 0.15)


func _build_deck_grid_in_viewer():
	"""Build the card grid — show every card in the deck with evolution progress."""
	if _deck_grid:
		for child in _deck_grid.get_children():
			child.queue_free()

	var cols = 5
	var card_w = 240
	var card_h = 330
	var gap_x = 24
	var gap_y = 40
	var start_x = 30
	var start_y = 10

	# Count duplicates per family for badge display
	var family_total = {}
	for card_id in RunRewardState.player_deck:
		var family = RunRewardState._get_family_for_card(card_id)
		family_total[family] = family_total.get(family, 0) + 1

	var count = 0
	for card_id in RunRewardState.player_deck:
		var col = count % cols
		var row = count / cols
		var x = start_x + col * (card_w + gap_x)
		var y = start_y + row * (card_h + gap_y)

		var family = RunRewardState._get_family_for_card(card_id)
		var base_card_id = card_id
		var max_level = RunRewardState.family_max_level.get(family, 1)

		var display_card_id = base_card_id
		if max_level >= 3:
			display_card_id = base_card_id + "_l3"
		elif max_level >= 2:
			display_card_id = base_card_id + "_l2"

		var card_def = CardDatabase.get_card_def(display_card_id)
		if card_def.is_empty():
			card_def = CardDatabase.get_card_def(base_card_id)
		if card_def.is_empty():
			continue

		var card_ui = CardUIScene.instantiate()
		card_ui.position = Vector2(x, y)
		card_ui.scale = Vector2(1.0, 1.0)
		_deck_grid.add_child(card_ui)
		card_ui.setup_card(card_def.duplicate())

		# Update evolution progress using CardUI's built-in display
		var ep = RunRewardState.card_ep_by_family.get(family, 0)
		if max_level >= 3:
			card_ui.evo_progress.visible = false
			card_ui.evo_text_label.visible = false
		else:
			var needed = CardDatabase.get_card_def(base_card_id).get("ep_to_evolve", 8)
			var progress = float(ep) / float(needed) if needed > 0 else 0.0
			card_ui.update_evolution_progress(clamp(progress, 0.0, 1.0))
			card_ui.update_ep_text("%d/%d EP" % [ep, needed])

		# Duplicate count badge
		var total = family_total.get(family, 1)
		if total > 1:
			var badge = Label.new()
			badge.text = "x%d" % total
			badge.position = Vector2(card_w - 56, 6)
			badge.size = Vector2(50, 24)
			badge.add_theme_font_size_override("font_size", 15)
			badge.add_theme_color_override("font_color", Color("#FFD700"))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bg = StyleBoxFlat.new()
			bg.bg_color = Color(0, 0, 0, 0.75)
			bg.corner_radius_top_left = 6
			bg.corner_radius_top_right = 6
			bg.corner_radius_bottom_left = 6
			bg.corner_radius_bottom_right = 6
			badge.add_theme_stylebox_override("normal", bg)
			card_ui.add_child(badge)

		count += 1

	var total_rows = ceili(float(count) / cols) if count > 0 else 1
	_deck_grid.custom_minimum_size = Vector2(1480, total_rows * (card_h + gap_y))


func _close_deck_viewer():
	if _deck_overlay:
		var tw = create_tween()
		tw.tween_property(_deck_overlay, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func():
			_deck_overlay.queue_free()
			_deck_overlay = null
			_deck_grid = null
		)
