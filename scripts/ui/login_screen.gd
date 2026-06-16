class_name LoginScreen
## 登陆/标题画面脚本
## 包含两个阶段：标题画面 → 角色选择画面（分辨率 1920x1080）
extends Control

# ========== 预加载场景 ==========
const CardUIScene = preload("res://scenes/card_ui.tscn")

# ========== 阶段追踪 ==========
var phase: String = "title"  # 当前阶段："title"（标题）或 "select"（角色选择）
var selected_character_id: String = ""  # 玩家选中的角色 ID

# ========== 标题阶段节点 ==========
var title_container: Control    # 标题画面的容器节点
var title_start_btn: Button     # "开始游戏"按钮

# ========== 选择阶段节点 ==========
var select_container: Control           # 角色选择画面的容器节点
var char_card_infiltrator: Panel        # "渗透者"角色卡片面板
var char_card_crasher: Panel            # "代码崩溃者"角色卡片面板
var char_card_infiltrator_border: StyleBoxFlat  # 渗透者卡片的边框样式
var char_card_crasher_border: StyleBoxFlat      # 崩溃者卡片的边框样式
var confirm_btn: Button                 # "确认选择"按钮


func _ready():
	"""
	节点就绪时的入口函数。
	调用 _build_ui() 构建完整的 UI 界面。
	"""
	_build_ui()


func _build_ui():
	"""
	构建完整的 UI 界面。
	按以下顺序组装：
	1. 背景图片
	2. 背景网格叠加层
	3. 水平扫描线叠加层
	4. 标题阶段容器（含按钮）
	5. 角色选择阶段容器（初始隐藏）
	"""
	# ---- 背景图片（两个阶段共享） ----
	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://card/登陆界面.png")  # 加载背景图片
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # 忽略原始尺寸，完全按设定大小拉伸
	bg_tex.size = Vector2(1920, 1080)  # 填满全屏
	bg_tex.z_index = -10  # 置于最底层
	add_child(bg_tex)

	# === 背景网格叠加层（微妙的赛博朋克风格网格） ===
	var grid_overlay = Control.new()
	grid_overlay.z_index = -9
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 忽略鼠标事件，穿透点击
	add_child(grid_overlay)

	# 画竖线
	var grid_color = Color("#4A3F8A", 0.06)  # 半透明紫色，非常淡
	var grid_spacing = 80  # 网格间距 80 像素
	for x in range(0, 1920, grid_spacing):
		var vline = ColorRect.new()
		vline.position = Vector2(x, 0)
		vline.size = Vector2(1, 1080)  # 1 像素宽的竖线
		vline.color = grid_color
		grid_overlay.add_child(vline)

	# 画横线
	for y in range(0, 1080, grid_spacing):
		var hline = ColorRect.new()
		hline.position = Vector2(0, y)
		hline.size = Vector2(1920, 1)  # 1 像素高的横线
		hline.color = grid_color
		grid_overlay.add_child(hline)

	# === 水平扫描线叠加层（模拟老式 CRT 显示器效果） ===
	var scan_overlay = Control.new()
	scan_overlay.z_index = -8
	scan_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan_overlay)
	for y in range(0, 1080, 4):
		var scan = ColorRect.new()
		scan.position = Vector2(0, y)
		scan.size = Vector2(1920, 1)
		scan.color = Color(0, 0, 0, 0.04)  # 极淡的黑色扫描线
		scan_overlay.add_child(scan)

	# === 阶段1：标题画面 ===
	title_container = Control.new()
	title_container.name = "TitleContainer"
	add_child(title_container)
	_build_title_phase()  # 构建标题画面的具体内容

	# === 阶段2：角色选择画面（初始隐藏） ===
	select_container = Control.new()
	select_container.name = "SelectContainer"
	select_container.visible = false  # 一开始不可见
	add_child(select_container)
	_build_select_phase()  # 构建选择画面的具体内容


func _build_title_phase():
	"""
	构建标题阶段的 UI。
	主要包含一个居中的赛博朋克风格的"开始游戏"按钮，
	带有霓虹边框和发光脉冲动画。
	"""
	# ---- 中央"开始游戏"按钮：赛博朋克霓虹风格 ----
	var start_btn = Button.new()
	start_btn.text = "开 始 游 戏"
	start_btn.position = Vector2(785, 520)  # 居中位置（1920x1080 分辨率下）
	start_btn.size = Vector2(350, 100)      # 按钮尺寸
	start_btn.add_theme_font_size_override("font_size", 40)  # 字体大小 40
	start_btn.add_theme_color_override("font_color", Color.WHITE)           # 默认文字颜色：白色
	start_btn.add_theme_color_override("font_hover_color", Color("#FFE080"))  # 悬停文字颜色：金色

	# -- 按钮普通状态样式（深紫色背景 + 紫色边框 + 霓虹发光） --
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#1A1050")            # 深紫色背景
	btn_normal.border_color = Color("#6B3BFF")        # 紫色边框
	btn_normal.border_width_left = 3; btn_normal.border_width_right = 3
	btn_normal.border_width_top = 3; btn_normal.border_width_bottom = 3
	btn_normal.corner_radius_top_left = 18; btn_normal.corner_radius_top_right = 18
	btn_normal.corner_radius_bottom_left = 18; btn_normal.corner_radius_bottom_right = 18  # 圆角 18px
	btn_normal.shadow_size = 14           # 阴影大小
	btn_normal.shadow_color = Color("#6B3BFF", 0.5)   # 半透明紫色阴影，制造发光感
	start_btn.add_theme_stylebox_override("normal", btn_normal)

	# -- 按钮悬停状态样式（更亮的背景 + 金色边框 + 强发光） --
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color("#2A1868")
	btn_hover.border_color = Color("#FFD700")         # 金色边框
	btn_hover.border_width_left = 3; btn_hover.border_width_right = 3
	btn_hover.border_width_top = 3; btn_hover.border_width_bottom = 3
	btn_hover.corner_radius_top_left = 18; btn_hover.corner_radius_top_right = 18
	btn_hover.corner_radius_bottom_left = 18; btn_hover.corner_radius_bottom_right = 18
	btn_hover.shadow_size = 22                          # 更大的阴影
	btn_hover.shadow_color = Color("#FFD700", 0.7)     # 金色发光阴影
	start_btn.add_theme_stylebox_override("hover", btn_hover)

	# -- 按钮按下状态样式（更深颜色 + 橙色边框 + 最强发光） --
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color("#3A2080")
	btn_pressed.border_color = Color("#FFA000")       # 橙色边框
	btn_pressed.border_width_left = 3; btn_pressed.border_width_right = 3
	btn_pressed.border_width_top = 3; btn_pressed.border_width_bottom = 3
	btn_pressed.corner_radius_top_left = 18; btn_pressed.corner_radius_top_right = 18
	btn_pressed.corner_radius_bottom_left = 18; btn_pressed.corner_radius_bottom_right = 18
	btn_pressed.shadow_size = 28                       # 最大阴影
	btn_pressed.shadow_color = Color("#FFD700", 0.9)
	start_btn.add_theme_stylebox_override("pressed", btn_pressed)

	# 绑定按钮点击信号
	start_btn.pressed.connect(_on_title_start_pressed)
	title_container.add_child(start_btn)
	title_start_btn = start_btn

	# ---- 发光脉冲动画（按钮透明度在 0.85 ~ 1.0 之间循环） ----
	var glow_tween = create_tween().set_loops()  # 创建循环动画
	glow_tween.tween_property(start_btn, "modulate:a", 0.85, 1.5)  # 变暗
	glow_tween.tween_property(start_btn, "modulate:a", 1.0, 1.5)   # 变亮


## 将难度文本转换为星级显示
## 参数 difficulty: 难度文本（"中等"/"较高"/"极高"）
## 返回: 对应的星标字符串
func _get_star_display(difficulty: String) -> String:
	match difficulty:
		"中等":
			return "⭐⭐⭐"       # 3 星
		"较高":
			return "⭐⭐⭐⭐"     # 4 星
		"极高":
			return "⭐⭐⭐⭐⭐"   # 5 星
		_:
			return "⭐⭐⭐"       # 默认 3 星


func _build_select_phase():
	"""
	构建角色选择阶段的 UI。
	包含：外框装饰 → 标题栏 → 角色卡片（渗透者 + 代码崩溃者）→ 确认按钮 → 底部提示
	整体布局为赛博朋克风格，深色背景配金色/紫色装饰。
	"""
	# === 外框面板 ===
	var outer_frame = Panel.new()
	outer_frame.name = "OuterFrame"
	outer_frame.position = Vector2(160, 50)    # 在 1920x1080 中居中
	outer_frame.size = Vector2(1600, 950)       # 外框尺寸

	# 外框样式：半透明深蓝背景 + 紫色边框 + 圆角 + 发光阴影
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color("#080C1E", 0.92)    # 深蓝黑底色，92%不透明
	outer_style.border_color = Color("#4A3F8A")      # 紫色边框
	outer_style.border_width_left = 2
	outer_style.border_width_right = 2
	outer_style.border_width_top = 2
	outer_style.border_width_bottom = 2
	outer_style.corner_radius_top_left = 20       # 圆角 20px
	outer_style.corner_radius_top_right = 20
	outer_style.corner_radius_bottom_left = 20
	outer_style.corner_radius_bottom_right = 20
	outer_style.shadow_size = 18                   # 阴影大小
	outer_style.shadow_color = Color("#6B3BFF", 0.3)  # 紫色半透明阴影
	outer_frame.add_theme_stylebox_override("panel", outer_style)
	select_container.add_child(outer_frame)

	# === 外框四角装饰（金色 L 形角标） ===
	var corner_color = Color("#FFD700", 0.6)  # 金色，60%不透明
	var corner_len = 30    # 角标线段长度
	var corner_thick = 3   # 角标线段粗细
	# 左上角（横线 + 竖线）
	var tl_h = ColorRect.new(); tl_h.position = Vector2(16, 16); tl_h.size = Vector2(corner_len, corner_thick); tl_h.color = corner_color; outer_frame.add_child(tl_h)
	var tl_v = ColorRect.new(); tl_v.position = Vector2(16, 16); tl_v.size = Vector2(corner_thick, corner_len); tl_v.color = corner_color; outer_frame.add_child(tl_v)
	# 右上角
	var tr_h = ColorRect.new(); tr_h.position = Vector2(1600 - 16 - corner_len, 16); tr_h.size = Vector2(corner_len, corner_thick); tr_h.color = corner_color; outer_frame.add_child(tr_h)
	var tr_v = ColorRect.new(); tr_v.position = Vector2(1600 - 16 - corner_thick, 16); tr_v.size = Vector2(corner_thick, corner_len); tr_v.color = corner_color; outer_frame.add_child(tr_v)
	# 左下角
	var bl_h = ColorRect.new(); bl_h.position = Vector2(16, 950 - 16 - corner_thick); bl_h.size = Vector2(corner_len, corner_thick); bl_h.color = corner_color; outer_frame.add_child(bl_h)
	var bl_v = ColorRect.new(); bl_v.position = Vector2(16, 950 - 16 - corner_len); bl_v.size = Vector2(corner_thick, corner_len); bl_v.color = corner_color; outer_frame.add_child(bl_v)
	# 右下角
	var br_h = ColorRect.new(); br_h.position = Vector2(1600 - 16 - corner_len, 950 - 16 - corner_thick); br_h.size = Vector2(corner_len, corner_thick); br_h.color = corner_color; outer_frame.add_child(br_h)
	var br_v = ColorRect.new(); br_v.position = Vector2(1600 - 16 - corner_thick, 950 - 16 - corner_len); br_v.size = Vector2(corner_thick, corner_len); br_v.color = corner_color; outer_frame.add_child(br_v)

	# === 标题文字（带发光底层效果） ===
	# 底层发光文字（模糊效果，透明度低，制造发光感）
	var title_glow = Label.new()
	title_glow.text = "选择你的角色"
	title_glow.position = Vector2(0, 28)
	title_glow.size = Vector2(1600, 50)
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.add_theme_font_size_override("font_size", 42)
	title_glow.add_theme_color_override("font_color", Color("#FFD700", 0.25))  # 金色，25%不透明
	outer_frame.add_child(title_glow)

	# 上层主标题（实色）
	var title = Label.new()
	title.text = "选择你的角色"
	title.position = Vector2(0, 28)
	title.size = Vector2(1600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#FFD700"))  # 纯金色
	outer_frame.add_child(title)

	# 标题两侧装饰菱形图标
	var title_diamond_left = Label.new()
	title_diamond_left.text = "◇"
	title_diamond_left.position = Vector2(340, 32)
	title_diamond_left.size = Vector2(40, 40)
	title_diamond_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_diamond_left.add_theme_font_size_override("font_size", 20)
	title_diamond_left.add_theme_color_override("font_color", Color("#FFD700", 0.5))
	outer_frame.add_child(title_diamond_left)

	var title_diamond_right = Label.new()
	title_diamond_right.text = "◇"
	title_diamond_right.position = Vector2(1220, 32)
	title_diamond_right.size = Vector2(40, 40)
	title_diamond_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_diamond_right.add_theme_font_size_override("font_size", 20)
	title_diamond_right.add_theme_color_override("font_color", Color("#FFD700", 0.5))
	outer_frame.add_child(title_diamond_right)

	# 标题下方的金色装饰线
	var title_bar = ColorRect.new()
	title_bar.position = Vector2(480, 76)
	title_bar.size = Vector2(640, 2)          # 宽 640px，高 2px
	title_bar.color = Color("#FFD700", 0.4)   # 金色半透明
	outer_frame.add_child(title_bar)

	# === Evolution Core 状态显示 ===
	var evo_status = Label.new()
	evo_status.text = "[ Evolution Core 状态 ]"
	evo_status.position = Vector2(0, 84)
	evo_status.size = Vector2(1600, 28)
	evo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evo_status.add_theme_font_size_override("font_size", 20)
	evo_status.add_theme_color_override("font_color", Color("#00E5FF", 0.85))  # 青色文字
	outer_frame.add_child(evo_status)

	# === 顶部装饰分隔线（带淡入淡出效果） ===
	_add_fade_separator(outer_frame, Vector2(200, 122), 1200, Color("#4A3F8A", 0.5))

	# === 角色卡片1：渗透者 ===
	char_card_infiltrator = _create_char_card(
		"infiltrator",
		Vector2(45, 135),
		CardDatabase.get_character_info("infiltrator")  # 从数据库获取角色信息
	)
	outer_frame.add_child(char_card_infiltrator)

	# === 角色卡片2：代码崩溃者 ===
	char_card_crasher = _create_char_card(
		"crasher",
		Vector2(815, 135),
		CardDatabase.get_character_info("crasher")  # 从数据库获取角色信息
	)
	outer_frame.add_child(char_card_crasher)

	# === 底部装饰分隔线（带淡入淡出效果） ===
	_add_fade_separator(outer_frame, Vector2(200, 810), 1200, Color("#4A3F8A", 0.5))


	# === 底部操作提示文字（带图标） ===
	# === 确认选择按钮 ===
	confirm_btn = Button.new()
	confirm_btn.text = "确认选择"
	confirm_btn.position = Vector2(550, 840)
	confirm_btn.size = Vector2(500, 65)
	confirm_btn.add_theme_font_size_override("font_size", 32)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.add_theme_color_override("font_hover_color", Color("#FFE080"))
	confirm_btn.disabled = true       # 初始禁用，需先选择角色
	confirm_btn.modulate.a = 0.4      # 半透明表示不可用

	# -- 确认按钮各种状态的样式 --
	# 普通状态：深紫背景 + 紫色边框
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#120A30")
	btn_normal.border_color = Color("#6B3BFF")
	btn_normal.border_width_left = 3; btn_normal.border_width_right = 3
	btn_normal.border_width_top = 3; btn_normal.border_width_bottom = 3
	btn_normal.corner_radius_top_left = 16; btn_normal.corner_radius_top_right = 16
	btn_normal.corner_radius_bottom_left = 16; btn_normal.corner_radius_bottom_right = 16
	btn_normal.shadow_size = 12
	btn_normal.shadow_color = Color("#6B3BFF", 0.4)
	confirm_btn.add_theme_stylebox_override("normal", btn_normal)

	# 悬停状态：金色边框 + 强发光
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color("#2A1868")
	btn_hover.border_color = Color("#FFD700")
	btn_hover.border_width_left = 3; btn_hover.border_width_right = 3
	btn_hover.border_width_top = 3; btn_hover.border_width_bottom = 3
	btn_hover.corner_radius_top_left = 16; btn_hover.corner_radius_top_right = 16
	btn_hover.corner_radius_bottom_left = 16; btn_hover.corner_radius_bottom_right = 16
	btn_hover.shadow_size = 22
	btn_hover.shadow_color = Color("#FFD700", 0.7)
	confirm_btn.add_theme_stylebox_override("hover", btn_hover)

	# 按下状态：橙色边框 + 最强发光
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color("#3A2080")
	btn_pressed.border_color = Color("#FFA000")
	btn_pressed.border_width_left = 3; btn_pressed.border_width_right = 3
	btn_pressed.border_width_top = 3; btn_pressed.border_width_bottom = 3
	btn_pressed.corner_radius_top_left = 16; btn_pressed.corner_radius_top_right = 16
	btn_pressed.corner_radius_bottom_left = 16; btn_pressed.corner_radius_bottom_right = 16
	btn_pressed.shadow_size = 26
	btn_pressed.shadow_color = Color("#FFD700", 0.9)
	confirm_btn.add_theme_stylebox_override("pressed", btn_pressed)

	# 禁用状态：暗灰色无发光
	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color("#08061A")
	btn_disabled.border_color = Color("#2A2A44")
	btn_disabled.border_width_left = 2; btn_disabled.border_width_right = 2
	btn_disabled.border_width_top = 2; btn_disabled.border_width_bottom = 2
	btn_disabled.corner_radius_top_left = 16; btn_disabled.corner_radius_top_right = 16
	btn_disabled.corner_radius_bottom_left = 16; btn_disabled.corner_radius_bottom_right = 16
	confirm_btn.add_theme_stylebox_override("disabled", btn_disabled)

	confirm_btn.pressed.connect(_on_confirm_pressed)
	outer_frame.add_child(confirm_btn)

	var hint_container = Control.new()
	hint_container.position = Vector2(0, 916)
	hint_container.size = Vector2(1600, 24)
	outer_frame.add_child(hint_container)

	# 提示图标
	var hint_icon = Label.new()
	hint_icon.text = "◈ "
	hint_icon.position = Vector2(640, 0)
	hint_icon.size = Vector2(30, 24)
	hint_icon.add_theme_font_size_override("font_size", 14)
	hint_icon.add_theme_color_override("font_color", Color("#4A3F8A", 0.6))
	hint_container.add_child(hint_icon)

	# 提示文字
	#var hint = Label.new()
	#hint.text = "点击角色头像直接开始游戏"
	#hint.position = Vector2(668, 0)
	#hint.size = Vector2(300, 24)
	#hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	#hint.add_theme_font_size_override("font_size", 15)
	#hint.add_theme_color_override("font_color", Color("#5A5A7A"))
	#hint_container.add_child(hint)


## 创建角色卡片（双栏布局：左侧头像 + 右侧信息面板）
## 参数:
##   char_id: 角色唯一标识（"infiltrator" 或 "crasher"）
##   pos: 卡片在外框中的位置
##   info: 从 CardDatabase 获取的角色信息字典
## 返回: 配置好的卡片 Panel 节点
func _create_char_card(char_id: String, pos: Vector2, info: Dictionary) -> Panel:
	var card = Panel.new()
	card.position = pos
	card.size = Vector2(740, 650)  # 卡片尺寸
	card.clip_contents = true      # 裁剪超出部分，保持圆角效果

	var char_color = info.get("color", Color("#00F0FF"))  # 角色主题色
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#0A0E27", 0.94)   # 深蓝黑背景
	style.border_color = char_color            # 角色主题色边框
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_size = 20
	style.shadow_color = Color(char_color, 0.45)  # 主题色发光阴影
	card.add_theme_stylebox_override("panel", style)

	# 保存卡片边框引用，以便后续高亮选中状态
	if char_id == "infiltrator":
		char_card_infiltrator_border = style
	else:
		char_card_crasher_border = style

	# 绑定鼠标点击事件
	card.gui_input.connect(_on_char_card_input.bind(char_id, style, char_color))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # 鼠标悬停显示手型

	var content = Control.new()
	content.name = "Content"
	card.add_child(content)

	# -- 卡片顶部装饰色条（加宽 + 发光效果） --
	var top_bar = ColorRect.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(740, 4)   # 4px 高的色条
	top_bar.color = char_color
	top_bar.modulate.a = 0.85
	card.add_child(top_bar)

	# 顶部色条下方的发光晕染
	var top_glow = ColorRect.new()
	top_glow.position = Vector2(0, 4)
	top_glow.size = Vector2(740, 6)
	top_glow.color = Color(char_color, 0.12)
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_glow)

	# -- 卡片底部装饰色条 --
	var bottom_bar = ColorRect.new()
	bottom_bar.position = Vector2(0, 646)
	bottom_bar.size = Vector2(740, 4)
	bottom_bar.color = char_color
	bottom_bar.modulate.a = 0.85
	card.add_child(bottom_bar)

	# 底部色条上方的发光晕染
	var bottom_glow = ColorRect.new()
	bottom_glow.position = Vector2(0, 640)
	bottom_glow.size = Vector2(740, 6)
	bottom_glow.color = Color(char_color, 0.12)
	bottom_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bottom_glow)

	# -- 卡片炫酷边框装饰 --
	_add_card_border_fx(card, char_color, Vector2(740, 650))

	# ===== 左栏：角色头像面板 =====
	var left_panel = Panel.new()
	left_panel.name = "LeftPanel"
	left_panel.position = Vector2(12, 12)
	left_panel.size = Vector2(440, 626)
	left_panel.clip_contents = true  # 裁剪边框/扫描线溢出
	# 注意：左栏不设 clip_contents，让头像完整渲染，由卡片的 clip_contents 控制溢出
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color("#060918", 0.4)  # 降低不透明度，让头像更突出
	left_style.border_color = Color(char_color, 0.0)  # 隐藏原始面板边框（由霓虹边框替代）
	left_style.border_width_left = 0
	left_style.border_width_right = 0
	left_style.border_width_top = 0
	left_style.border_width_bottom = 0
	left_style.corner_radius_top_left = 10
	left_style.corner_radius_top_right = 10
	left_style.corner_radius_bottom_left = 10
	left_style.corner_radius_bottom_right = 10
	left_panel.add_theme_stylebox_override("panel", left_style)
	content.add_child(left_panel)

	# -- 角色头像图（加大，填满左面板） --
	var portrait = TextureRect.new()
	var portrait_path = "res://card/渗透者.png" if char_id == "infiltrator" else "res://card/代码崩溃者.png"
	portrait.texture = load(portrait_path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(428, 614)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_char_card_input(event, char_id, style, char_color)
	)
	left_panel.add_child(portrait)

	# -- 赛博朋克霓虹边框效果（叠加在头像上方） --
	_add_portrait_border(left_panel, char_color, Vector2(440, 626))

	# ===== 右栏：角色信息面板 =====
	var right_panel = Control.new()
	right_panel.name = "RightPanel"
	right_panel.position = Vector2(460, 12)
	right_panel.size = Vector2(283, 626)

	# 半透明背景，提升文字可读性
	var right_bg = ColorRect.new()
	right_bg.position = Vector2(0, 0)
	right_bg.size = Vector2(283, 626)
	right_bg.color = Color("#0A0E27", 0.6)
	right_panel.add_child(right_bg)

	content.add_child(right_panel)

	# -- 角色名称（大字体） --
	var name_lbl = Label.new()
	name_lbl.text = info.get("name", "???")
	name_lbl.position = Vector2(0, 6)
	name_lbl.size = Vector2(283, 32)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.add_theme_font_size_override("font_size", 46)
	name_lbl.add_theme_color_override("font_color", char_color)  # 使用角色主题色
	right_panel.add_child(name_lbl)

	## -- 名称下方的装饰下划线 --
	#var name_underline = ColorRect.new()
	#name_underline.position = Vector2(40, 65)
	#name_underline.size = Vector2(200, 2)
	#name_underline.color = Color(char_color, 0.6)
	#right_panel.add_child(name_underline)

	# -- 基础属性行：HP / EP / 手牌上限 --
	var hp = info.get("hp", 70)
	var ep = info.get("ep_per_turn", 3)
	var hand = info.get("hand_size", 5)
	var stats_lbl = Label.new()
	stats_lbl.text = "HP:%d  EP:%d  手牌:%d" % [hp, ep, hand]
	stats_lbl.position = Vector2(0, 70)
	stats_lbl.size = Vector2(283, 24)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_lbl.add_theme_font_size_override("font_size", 26)
	stats_lbl.add_theme_color_override("font_color", Color("#FFD700"))  # 金色数字
	right_panel.add_child(stats_lbl)

	## -- 分隔线 --
	#var sep1 = ColorRect.new()
	#sep1.position = Vector2(0, 100)
	#sep1.size = Vector2(263, 1)
	#sep1.color = Color("#3A3A5A")
	#right_panel.add_child(sep1)

	# -- 核心机制描述 --
	var mech_lbl = Label.new()
	mech_lbl.text = "核心: " + info.get("mechanic", "")
	mech_lbl.position = Vector2(0, 110)
	mech_lbl.size = Vector2(283, 56)
	mech_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mech_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mech_lbl.add_theme_font_size_override("font_size", 26)
	mech_lbl.add_theme_color_override("font_color", Color("#FF6B35"))  # 橙色强调
	right_panel.add_child(mech_lbl)

	## -- 分隔线 --
	#var sep2 = ColorRect.new()
	#sep2.position = Vector2(0, 172)
	#sep2.size = Vector2(263, 1)
	#sep2.color = Color("#3A3A5A")
	#right_panel.add_child(sep2)

	# -- 难度星级显示 --
	var diff_str = info.get("difficulty", "中等")
	var stars = _get_star_display(diff_str)
	var diff_lbl = Label.new()
	diff_lbl.text = "难度: %s (%s)" % [stars, diff_str]
	diff_lbl.position = Vector2(0, 192)
	diff_lbl.size = Vector2(283, 28)
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	diff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_lbl.add_theme_font_size_override("font_size", 26)
	diff_lbl.add_theme_color_override("font_color", Color("#BBBBCC"))
	right_panel.add_child(diff_lbl)

	## -- 分隔线 --
	#var sep3 = ColorRect.new()
	#sep3.position = Vector2(0, 216)
	#sep3.size = Vector2(263, 1)
	#sep3.color = Color("#3A3A5A")
	#right_panel.add_child(sep3)

	# -- "初始卡组"标题 --
	var deck_hdr = Label.new()
	deck_hdr.text = "初始卡组"
	deck_hdr.position = Vector2(0, 276)
	deck_hdr.size = Vector2(283, 20)
	deck_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	deck_hdr.add_theme_font_size_override("font_size", 26)
	deck_hdr.add_theme_color_override("font_color", Color("#9999BB"))
	right_panel.add_child(deck_hdr)

	# -- 迷你卡牌预览行（点击可展开查看全部） --
	var mini_cards_container = Control.new()
	mini_cards_container.name = "MiniCards"
	mini_cards_container.position = Vector2(0, 326)
	mini_cards_container.size = Vector2(283, 100)
	mini_cards_container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # 手型光标
	right_panel.add_child(mini_cards_container)

	# 绑定点击事件，展开/收起完整卡组
	mini_cards_container.gui_input.connect(_on_mini_cards_clicked.bind(mini_cards_container, char_id, char_color))

	# 从数据库获取角色的初始卡组列表
	var deck = CardDatabase.get_starting_deck_for_character(char_id)
	var display_count = min(deck.size(), 3)  # 默认只显示前 3 张
	for i in range(display_count):
		var cid = deck[i]
		var cdef = CardDatabase.get_card_def(cid)     # 获取卡牌定义
		var card_name = cdef.get("name", cid) if not cdef.is_empty() else cid
		var card_color = cdef.get("color", char_color) if not cdef.is_empty() else char_color

		# 迷你卡牌面板
		var mini_card = Panel.new()
		mini_card.position = Vector2(i * 88, 0)  # 水平排列，间距 88px
		mini_card.size = Vector2(76, 80)

		# 迷你卡牌样式
		var mini_style = StyleBoxFlat.new()
		mini_style.bg_color = Color("#0E122A")
		mini_style.border_color = Color(card_color, 0.5)  # 卡牌主题色边框
		mini_style.border_width_left = 1
		mini_style.border_width_right = 1
		mini_style.border_width_top = 1
		mini_style.border_width_bottom = 1
		mini_style.corner_radius_top_left = 5
		mini_style.corner_radius_top_right = 5
		mini_style.corner_radius_bottom_left = 5
		mini_style.corner_radius_bottom_right = 5
		mini_card.add_theme_stylebox_override("panel", mini_style)

		# 卡牌名称（超过3字时截断加省略号）
		var mini_name = Label.new()
		var short_name = card_name
		if short_name.length() > 3:
			short_name = short_name.substr(0, 3) + "…"
		mini_name.text = short_name
		mini_name.position = Vector2(2, 3)
		mini_name.size = Vector2(72, 28)
		mini_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mini_name.add_theme_font_size_override("font_size", 16)
		mini_name.add_theme_color_override("font_color", Color(card_color, 0.9))
		mini_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 智能换行
		mini_card.add_child(mini_name)

		# 卡牌装饰图标
		var mini_icon = Label.new()
		mini_icon.text = "▣"
		mini_icon.position = Vector2(0, 32)
		mini_icon.size = Vector2(76, 24)
		mini_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mini_icon.add_theme_font_size_override("font_size", 16)
		mini_icon.add_theme_color_override("font_color", Color(card_color, 0.4))
		mini_card.add_child(mini_icon)

		mini_cards_container.add_child(mini_card)

	# -- 卡牌数量提示（点击查看卡组详情弹窗） --
	var count_note = Label.new()
	count_note.text = "点击查看卡组详情 >>"
	count_note.position = Vector2(0, 82)
	count_note.size = Vector2(283, 26)
	count_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_note.add_theme_font_size_override("font_size", 26)
	count_note.add_theme_color_override("font_color", Color(char_color, 0.5))
	mini_cards_container.add_child(count_note)

	return card


## 处理迷你卡牌区域的点击事件，打开卡组详情弹窗
func _on_mini_cards_clicked(event: InputEvent, _container: Control, char_id: String, char_color: Color):
	"""
	参数:
	  event: 输入事件
	  container: 迷你卡牌的容器节点（未使用，保留兼容信号签名）
	  char_id: 角色 ID
	  char_color: 角色主题色
	"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_deck_detail_overlay(char_id, char_color)


## 辅助函数：向容器中添加一张迷你卡牌
## 参数:
##   container: 目标容器
##   card_id: 卡牌 ID
##   char_color: 角色主题色（备用颜色）
##   x, y: 迷你卡牌位置
##   w, h: 迷你卡牌尺寸
func _add_mini_card_to_container(container: Control, card_id: String, char_color: Color, x: float, y: float, w: float, h: float):
	var cdef = CardDatabase.get_card_def(card_id)  # 获取卡牌定义
	var card_name = cdef.get("name", card_id) if not cdef.is_empty() else card_id
	var card_color = cdef.get("color", char_color) if not cdef.is_empty() else char_color

	# 创建迷你卡牌面板
	var mini_card = Panel.new()
	mini_card.position = Vector2(x, y)
	mini_card.size = Vector2(w, h)

	# 迷你卡牌样式
	var mini_style = StyleBoxFlat.new()
	mini_style.bg_color = Color("#0E122A")           # 深色背景
	mini_style.border_color = Color(card_color, 0.5)  # 半透明主题色边框
	mini_style.border_width_left = 1
	mini_style.border_width_right = 1
	mini_style.border_width_top = 1
	mini_style.border_width_bottom = 1
	mini_style.corner_radius_top_left = 4
	mini_style.corner_radius_top_right = 4
	mini_style.corner_radius_bottom_left = 4
	mini_style.corner_radius_bottom_right = 4
	mini_card.add_theme_stylebox_override("panel", mini_style)

	# 卡牌名称（超过3字时截断加省略号）
	var mini_name = Label.new()
	var short_name = card_name
	if short_name.length() > 3:
		short_name = short_name.substr(0, 3) + "…"
	mini_name.text = short_name
	mini_name.position = Vector2(2, 2)
	mini_name.size = Vector2(w - 4, 24)
	mini_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mini_name.add_theme_font_size_override("font_size", 9)
	mini_name.add_theme_color_override("font_color", Color(card_color, 0.9))
	mini_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mini_card.add_child(mini_name)

	# 卡牌装饰图标
	var mini_icon = Label.new()
	mini_icon.text = "▣"
	mini_icon.position = Vector2(0, 26)
	mini_icon.size = Vector2(w, 20)
	mini_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mini_icon.add_theme_font_size_override("font_size", 14)
	mini_icon.add_theme_color_override("font_color", Color(card_color, 0.4))
	mini_card.add_child(mini_icon)

	container.add_child(mini_card)


# ===== 阶段切换（标题 → 角色选择） =====

func _on_title_start_pressed():
	"""
	"开始游戏"按钮点击处理函数。
	执行淡出标题画面 → 淡入角色选择画面的过渡动画。
	"""
	phase = "select"  # 切换到选择阶段
	var tween = create_tween()
	tween.tween_property(title_container, "modulate:a", 0.0, 0.3)  # 标题画面淡出（0.3秒）
	tween.tween_callback(func():
		title_container.visible = false          # 隐藏标题
		select_container.visible = true          # 显示选择画面
		select_container.modulate.a = 0.0        # 初始透明度为0
	)
	tween.tween_property(select_container, "modulate:a", 1.0, 0.3)  # 选择画面淡入（0.3秒）


# ===== 角色选择逻辑 =====

func _on_char_card_input(event: InputEvent, char_id: String, style: StyleBoxFlat, char_color: Color):
	"""
	角色卡片的鼠标输入事件处理函数。
	处理点击选择逻辑：
	1. 重置两张卡片的边框为未选中状态
	2. 将被点击的卡片边框加粗高亮
	3. 启用确认按钮，显示选中的角色名
	"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# ---- 步骤1：重置两张卡片的边框到默认状态 ----
		if char_card_infiltrator_border:
			char_card_infiltrator_border.border_width_left = 3
			char_card_infiltrator_border.border_width_right = 3
			char_card_infiltrator_border.border_width_top = 3
			char_card_infiltrator_border.border_width_bottom = 3
			char_card_infiltrator_border.shadow_size = 20
			char_card_infiltrator_border.shadow_color = Color(
				CardDatabase.get_character_info("infiltrator").get("color", Color.WHITE), 0.45)
		if char_card_crasher_border:
			char_card_crasher_border.border_width_left = 3
			char_card_crasher_border.border_width_right = 3
			char_card_crasher_border.border_width_top = 3
			char_card_crasher_border.border_width_bottom = 3
			char_card_crasher_border.shadow_size = 20
			char_card_crasher_border.shadow_color = Color(
				CardDatabase.get_character_info("crasher").get("color", Color.WHITE), 0.45)

		# ---- 步骤2：高亮被选中的卡片（加粗边框 + 超强发光） ----
		selected_character_id = char_id
		style.border_width_left = 5
		style.border_width_right = 5
		style.border_width_top = 5
		style.border_width_bottom = 5
		style.shadow_size = 36
		style.shadow_color = Color(char_color, 0.85)  # 超强发光效果

		# 选中卡片脉冲动画（循环3次）
		var select_pulse = create_tween().set_loops(3)
		select_pulse.tween_property(style, "shadow_size", 28, 0.3)
		select_pulse.tween_property(style, "shadow_size", 40, 0.3)

		# ---- 步骤3：启用确认按钮，显示选中角色名 ----
		confirm_btn.disabled = false        # 启用按钮
		confirm_btn.modulate.a = 1.0        # 恢复完全不透明
		confirm_btn.text = "确认选择 — " + CardDatabase.get_character_info(char_id).get("name", "")
		
		# 确认按钮的发光脉冲动画（循环2次）
		var glow_tween = create_tween().set_loops(2)
		glow_tween.tween_property(confirm_btn, "modulate:a", 0.7, 0.25)
		glow_tween.tween_property(confirm_btn, "modulate:a", 1.0, 0.25)


func _confirm_and_start(char_id: String):
	"""Directly confirm character selection and start the game."""
	RunRewardState.selected_character = char_id
	RunRewardState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map_screen.tscn")

func _on_confirm_pressed():
	"""
	"确认选择"按钮点击处理函数。
	将选中的角色 ID 存入 RunRewardState，启动新游戏并跳转到地图场景。
	"""
	if selected_character_id == "":
		return
	_confirm_and_start(selected_character_id)


## 添加一条两端带淡入淡出效果的水平分隔线
## 参数:
##   parent: 父容器
##   pos: 分隔线的起始位置
##   total_width: 分隔线总宽度
##   color: 分隔线颜色（含透明度）
func _add_fade_separator(parent: Control, pos: Vector2, total_width: float, color: Color):
	var fade_len = 80           # 两端渐变区域的长度
	var solid_width = total_width - fade_len * 2  # 中间实色部分的宽度

	# ---- 左侧渐变段（从透明渐变到指定颜色） ----
	var segments = 8  # 渐变分段数
	for i in range(segments):
		var alpha = float(i + 1) / float(segments) * color.a  # 透明度递增
		var seg = ColorRect.new()
		seg.position = Vector2(pos.x + i * (fade_len / float(segments)), pos.y)
		seg.size = Vector2(fade_len / float(segments), 1)
		seg.color = Color(color.r, color.g, color.b, alpha)
		parent.add_child(seg)

	# ---- 中间实色段（完全不渐变） ----
	if solid_width > 0:
		var mid = ColorRect.new()
		mid.position = Vector2(pos.x + fade_len, pos.y)
		mid.size = Vector2(solid_width, 1)
		mid.color = color
		parent.add_child(mid)

	# ---- 右侧渐变段（从指定颜色渐变到透明） ----
	for i in range(segments):
		var alpha = float(segments - i) / float(segments) * color.a  # 透明度递减
		var seg = ColorRect.new()
		seg.position = Vector2(pos.x + fade_len + solid_width + i * (fade_len / float(segments)), pos.y)
		seg.size = Vector2(fade_len / float(segments), 1)
		seg.color = Color(color.r, color.g, color.b, alpha)
		parent.add_child(seg)


## 为角色头像添加赛博朋克霓虹风格装饰边框
## 参数:
##   parent: 头像所在的左面板（边框元素将作为其子节点叠加）
##   char_color: 角色主题色（渗透者=青色，崩溃者=粉色）
##   panel_size: 面板尺寸（用于定位边框元素）
func _add_portrait_border(parent: Control, char_color: Color, panel_size: Vector2):
	var pw = panel_size.x  # 面板宽度
	var ph = panel_size.y  # 面板高度
	var margin = 6         # 边框距面板边缘的距离

	# ===== 主线框（4条发光边线，角色主题色） =====
	var frame_color = Color(char_color, 0.5)  # 主题色半透明
	var frame_thick = 2                        # 线宽 2px

	# 上边线
	var frame_top = ColorRect.new()
	frame_top.position = Vector2(margin, margin)
	frame_top.size = Vector2(pw - margin * 2, frame_thick)
	frame_top.color = frame_color
	frame_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame_top)

	# 下边线
	var frame_bottom = ColorRect.new()
	frame_bottom.position = Vector2(margin, ph - margin - frame_thick)
	frame_bottom.size = Vector2(pw - margin * 2, frame_thick)
	frame_bottom.color = frame_color
	frame_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame_bottom)

	# 左边线
	var frame_left = ColorRect.new()
	frame_left.position = Vector2(margin, margin)
	frame_left.size = Vector2(frame_thick, ph - margin * 2)
	frame_left.color = frame_color
	frame_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame_left)

	# 右边线
	var frame_right = ColorRect.new()
	frame_right.position = Vector2(pw - margin - frame_thick, margin)
	frame_right.size = Vector2(frame_thick, ph - margin * 2)
	frame_right.color = frame_color
	frame_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame_right)

	# ===== L 形金色角标（四角各 2 条线段） =====
	var corner_color = Color("#FFD700", 0.75)  # 金色，75%不透明
	var corner_len = 28     # 角标臂长
	var corner_thick = 3    # 角标粗细

	# -- 左上角 --
	var tl_h = ColorRect.new()
	tl_h.position = Vector2(margin, margin)
	tl_h.size = Vector2(corner_len, corner_thick)
	tl_h.color = corner_color
	tl_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tl_h)

	var tl_v = ColorRect.new()
	tl_v.position = Vector2(margin, margin)
	tl_v.size = Vector2(corner_thick, corner_len)
	tl_v.color = corner_color
	tl_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tl_v)

	# -- 右上角 --
	var tr_h = ColorRect.new()
	tr_h.position = Vector2(pw - margin - corner_len, margin)
	tr_h.size = Vector2(corner_len, corner_thick)
	tr_h.color = corner_color
	tr_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr_h)

	var tr_v = ColorRect.new()
	tr_v.position = Vector2(pw - margin - corner_thick, margin)
	tr_v.size = Vector2(corner_thick, corner_len)
	tr_v.color = corner_color
	tr_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr_v)

	# -- 左下角 --
	var bl_h = ColorRect.new()
	bl_h.position = Vector2(margin, ph - margin - corner_thick)
	bl_h.size = Vector2(corner_len, corner_thick)
	bl_h.color = corner_color
	bl_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bl_h)

	var bl_v = ColorRect.new()
	bl_v.position = Vector2(margin, ph - margin - corner_len)
	bl_v.size = Vector2(corner_thick, corner_len)
	bl_v.color = corner_color
	bl_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bl_v)

	# -- 右下角 --
	var br_h = ColorRect.new()
	br_h.position = Vector2(pw - margin - corner_len, ph - margin - corner_thick)
	br_h.size = Vector2(corner_len, corner_thick)
	br_h.color = corner_color
	br_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(br_h)

	var br_v = ColorRect.new()
	br_v.position = Vector2(pw - margin - corner_thick, ph - margin - corner_len)
	br_v.size = Vector2(corner_thick, corner_len)
	br_v.color = corner_color
	br_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(br_v)

	# ===== 顶部/底部中央菱形装饰 =====
	var diamond_color = Color(char_color, 0.65)

	# 顶部菱形
	var diamond_top = Label.new()
	diamond_top.text = "◆"
	diamond_top.position = Vector2(pw / 2.0 - 14, margin - 8)
	diamond_top.size = Vector2(28, 20)
	diamond_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diamond_top.add_theme_font_size_override("font_size", 14)
	diamond_top.add_theme_color_override("font_color", diamond_color)
	diamond_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(diamond_top)

	# 底部菱形
	var diamond_bottom = Label.new()
	diamond_bottom.text = "◆"
	diamond_bottom.position = Vector2(pw / 2.0 - 14, ph - margin - 12)
	diamond_bottom.size = Vector2(28, 20)
	diamond_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diamond_bottom.add_theme_font_size_override("font_size", 14)
	diamond_bottom.add_theme_color_override("font_color", diamond_color)
	diamond_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(diamond_bottom)

	# ===== 左侧/右侧中央小刻度装饰（科技感细节） =====
	var tick_color = Color(char_color, 0.35)
	var tick_len = 8
	var tick_thick = 1

	# 左侧中央刻度
	var tick_left = ColorRect.new()
	tick_left.position = Vector2(margin, ph / 2.0 - tick_len / 2.0)
	tick_left.size = Vector2(tick_thick, tick_len)
	tick_left.color = tick_color
	tick_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tick_left)

	# 右侧中央刻度
	var tick_right = ColorRect.new()
	tick_right.position = Vector2(pw - margin - tick_thick, ph / 2.0 - tick_len / 2.0)
	tick_right.size = Vector2(tick_thick, tick_len)
	tick_right.color = tick_color
	tick_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tick_right)

	# ===== 扫描线叠加层（CRT 显示器效果） =====
	var scan_container = Control.new()
	scan_container.name = "PortraitScanlines"
	scan_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scan_container)

	for y in range(int(margin + 4), int(ph - margin), 4):
		var scan = ColorRect.new()
		scan.position = Vector2(margin + 2, y)
		scan.size = Vector2(pw - margin * 2 - 4, 1)
		scan.color = Color(0, 0, 0, 0.06)  # 极淡黑色扫描线
		scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scan_container.add_child(scan)

	# ===== 边框呼吸脉冲动画（主线框亮度循环变化） =====
	var glow_tween = parent.create_tween().set_loops()
	glow_tween.tween_property(frame_top, "modulate:a", 0.4, 2.0)
	glow_tween.tween_property(frame_top, "modulate:a", 1.0, 2.0)
	# 同步动画其余 3 条边线
	var sync_tween_b = parent.create_tween().set_loops()
	sync_tween_b.tween_property(frame_bottom, "modulate:a", 0.4, 2.0)
	sync_tween_b.tween_property(frame_bottom, "modulate:a", 1.0, 2.0)
	var sync_tween_l = parent.create_tween().set_loops()
	sync_tween_l.tween_property(frame_left, "modulate:a", 0.4, 2.0)
	sync_tween_l.tween_property(frame_left, "modulate:a", 1.0, 2.0)
	var sync_tween_r = parent.create_tween().set_loops()
	sync_tween_r.tween_property(frame_right, "modulate:a", 0.4, 2.0)
	sync_tween_r.tween_property(frame_right, "modulate:a", 1.0, 2.0)


## 为角色卡片添加炫酷的赛博朋克边框装饰效果
## 参数:
##   card: 卡片 Panel 节点
##   char_color: 角色主题色
##   card_size: 卡片尺寸
func _add_card_border_fx(card: Panel, char_color: Color, card_size: Vector2):
	var cw = card_size.x  # 740
	var ch = card_size.y   # 650

	# ===== 内层双线框（距外边框 5px 的细线，制造双线效果） =====
	var inner_color = Color(char_color, 0.2)
	var inner_margin = 5
	var inner_thick = 1

	# 内层上边
	var inner_top = ColorRect.new()
	inner_top.position = Vector2(inner_margin, inner_margin)
	inner_top.size = Vector2(cw - inner_margin * 2, inner_thick)
	inner_top.color = inner_color
	inner_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner_top)

	# 内层下边
	var inner_bottom = ColorRect.new()
	inner_bottom.position = Vector2(inner_margin, ch - inner_margin - inner_thick)
	inner_bottom.size = Vector2(cw - inner_margin * 2, inner_thick)
	inner_bottom.color = inner_color
	inner_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner_bottom)

	# 内层左边
	var inner_left = ColorRect.new()
	inner_left.position = Vector2(inner_margin, inner_margin)
	inner_left.size = Vector2(inner_thick, ch - inner_margin * 2)
	inner_left.color = inner_color
	inner_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner_left)

	# 内层右边
	var inner_right = ColorRect.new()
	inner_right.position = Vector2(cw - inner_margin - inner_thick, inner_margin)
	inner_right.size = Vector2(inner_thick, ch - inner_margin * 2)
	inner_right.color = inner_color
	inner_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner_right)

	# ===== 大型科技角标（双层 L 形 + 三角点缀） =====
	var corner_color_bright = Color(char_color, 0.85)
	var corner_color_dim = Color(char_color, 0.4)
	var c_arm = 40     # 角标臂长
	var c_arm2 = 22    # 内层角标臂长（较短）
	var c_thick = 3    # 外层粗线
	var c_thick2 = 2   # 内层细线

	# -- 左上角：外层 L --
	var tl1_h = ColorRect.new()
	tl1_h.position = Vector2(3, 3); tl1_h.size = Vector2(c_arm, c_thick); tl1_h.color = corner_color_bright; tl1_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tl1_h)
	var tl1_v = ColorRect.new()
	tl1_v.position = Vector2(3, 3); tl1_v.size = Vector2(c_thick, c_arm); tl1_v.color = corner_color_bright; tl1_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tl1_v)
	# 左上角：内层 L
	var tl2_h = ColorRect.new()
	tl2_h.position = Vector2(8, 8); tl2_h.size = Vector2(c_arm2, c_thick2); tl2_h.color = corner_color_dim; tl2_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tl2_h)
	var tl2_v = ColorRect.new()
	tl2_v.position = Vector2(8, 8); tl2_v.size = Vector2(c_thick2, c_arm2); tl2_v.color = corner_color_dim; tl2_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tl2_v)
	# 左上角：小三角点缀（菱形符号）
	var tl_dot = Label.new()
	tl_dot.text = "◤"; tl_dot.position = Vector2(0, -2); tl_dot.size = Vector2(18, 18); tl_dot.add_theme_font_size_override("font_size", 10); tl_dot.add_theme_color_override("font_color", corner_color_bright); tl_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tl_dot)

	# -- 右上角 --
	var tr1_h = ColorRect.new()
	tr1_h.position = Vector2(cw - 3 - c_arm, 3); tr1_h.size = Vector2(c_arm, c_thick); tr1_h.color = corner_color_bright; tr1_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tr1_h)
	var tr1_v = ColorRect.new()
	tr1_v.position = Vector2(cw - 3 - c_thick, 3); tr1_v.size = Vector2(c_thick, c_arm); tr1_v.color = corner_color_bright; tr1_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tr1_v)
	var tr2_h = ColorRect.new()
	tr2_h.position = Vector2(cw - 8 - c_arm2, 8); tr2_h.size = Vector2(c_arm2, c_thick2); tr2_h.color = corner_color_dim; tr2_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tr2_h)
	var tr2_v = ColorRect.new()
	tr2_v.position = Vector2(cw - 8 - c_thick2, 8); tr2_v.size = Vector2(c_thick2, c_arm2); tr2_v.color = corner_color_dim; tr2_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tr2_v)
	var tr_dot = Label.new()
	tr_dot.text = "◥"; tr_dot.position = Vector2(cw - 18, -2); tr_dot.size = Vector2(18, 18); tr_dot.add_theme_font_size_override("font_size", 10); tr_dot.add_theme_color_override("font_color", corner_color_bright); tr_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(tr_dot)

	# -- 左下角 --
	var bl1_h = ColorRect.new()
	bl1_h.position = Vector2(3, ch - 3 - c_thick); bl1_h.size = Vector2(c_arm, c_thick); bl1_h.color = corner_color_bright; bl1_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(bl1_h)
	var bl1_v = ColorRect.new()
	bl1_v.position = Vector2(3, ch - 3 - c_arm); bl1_v.size = Vector2(c_thick, c_arm); bl1_v.color = corner_color_bright; bl1_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(bl1_v)
	var bl2_h = ColorRect.new()
	bl2_h.position = Vector2(8, ch - 8 - c_thick2); bl2_h.size = Vector2(c_arm2, c_thick2); bl2_h.color = corner_color_dim; bl2_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(bl2_h)
	var bl2_v = ColorRect.new()
	bl2_v.position = Vector2(8, ch - 8 - c_arm2); bl2_v.size = Vector2(c_thick2, c_arm2); bl2_v.color = corner_color_dim; bl2_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(bl2_v)
	var bl_dot = Label.new()
	bl_dot.text = "◣"; bl_dot.position = Vector2(0, ch - 16); bl_dot.size = Vector2(18, 18); bl_dot.add_theme_font_size_override("font_size", 10); bl_dot.add_theme_color_override("font_color", corner_color_bright); bl_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(bl_dot)

	# -- 右下角 --
	var br1_h = ColorRect.new()
	br1_h.position = Vector2(cw - 3 - c_arm, ch - 3 - c_thick); br1_h.size = Vector2(c_arm, c_thick); br1_h.color = corner_color_bright; br1_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(br1_h)
	var br1_v = ColorRect.new()
	br1_v.position = Vector2(cw - 3 - c_thick, ch - 3 - c_arm); br1_v.size = Vector2(c_thick, c_arm); br1_v.color = corner_color_bright; br1_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(br1_v)
	var br2_h = ColorRect.new()
	br2_h.position = Vector2(cw - 8 - c_arm2, ch - 8 - c_thick2); br2_h.size = Vector2(c_arm2, c_thick2); br2_h.color = corner_color_dim; br2_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(br2_h)
	var br2_v = ColorRect.new()
	br2_v.position = Vector2(cw - 8 - c_thick2, ch - 8 - c_arm2); br2_v.size = Vector2(c_thick2, c_arm2); br2_v.color = corner_color_dim; br2_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(br2_v)
	var br_dot = Label.new()
	br_dot.text = "◢"; br_dot.position = Vector2(cw - 18, ch - 16); br_dot.size = Vector2(18, 18); br_dot.add_theme_font_size_override("font_size", 10); br_dot.add_theme_color_override("font_color", corner_color_bright); br_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(br_dot)

	# ===== 数据流点（沿边框流动的小发光点） =====
	var dot_size = 4
	var dot_color = Color(char_color, 0.9)
	var dot_count = 6  # 每条边上的点数

	# 顶部数据流点
	for i in range(dot_count):
		var dot = ColorRect.new()
		dot.position = Vector2(50 + i * 110, 1)
		dot.size = Vector2(dot_size, dot_size)
		dot.color = dot_color
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dot)
		# 流动动画：每个点依次闪烁
		var dot_tween = card.create_tween().set_loops()
		var delay = i * 0.3
		dot_tween.tween_interval(delay)
		dot_tween.tween_property(dot, "modulate:a", 0.1, 0.4)
		dot_tween.tween_property(dot, "modulate:a", 1.0, 0.4)
		dot_tween.tween_interval(0.8)

	# 底部数据流点
	for i in range(dot_count):
		var dot = ColorRect.new()
		dot.position = Vector2(50 + i * 110, ch - 5)
		dot.size = Vector2(dot_size, dot_size)
		dot.color = dot_color
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dot)
		var dot_tween = card.create_tween().set_loops()
		var delay = i * 0.3
		dot_tween.tween_interval(delay)
		dot_tween.tween_property(dot, "modulate:a", 0.1, 0.4)
		dot_tween.tween_property(dot, "modulate:a", 1.0, 0.4)
		dot_tween.tween_interval(0.8)

	# ===== 水平扫描线（从上到下循环扫过卡片） =====
	var scan_line = ColorRect.new()
	scan_line.position = Vector2(3, 10)
	scan_line.size = Vector2(cw - 6, 2)
	scan_line.color = Color(char_color, 0.25)
	scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(scan_line)

	var scan_tween = card.create_tween().set_loops()
	scan_tween.tween_property(scan_line, "position:y", ch - 12, 4.0)
	scan_tween.tween_property(scan_line, "position:y", 10, 0.0)

	# 扫描线上方的微光晕
	var scan_glow = ColorRect.new()
	scan_glow.position = Vector2(3, 6)
	scan_glow.size = Vector2(cw - 6, 8)
	scan_glow.color = Color(char_color, 0.06)
	scan_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(scan_glow)
	# 光晕跟随扫描线
	var glow_tween = card.create_tween().set_loops()
	glow_tween.tween_property(scan_glow, "position:y", ch - 16, 4.0)
	glow_tween.tween_property(scan_glow, "position:y", 6, 0.0)

	# ===== 边框侧边缺口装饰（左右两侧各 3 个科技感缺口） =====
	var notch_color = Color(char_color, 0.5)
	var notch_w = 6
	var notch_h = 2
	var notch_positions = [120, 325, 530]  # Y 位置

	for ny in notch_positions:
		# 左侧缺口
		var notch_l = ColorRect.new()
		notch_l.position = Vector2(0, ny)
		notch_l.size = Vector2(notch_w, notch_h)
		notch_l.color = notch_color
		notch_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(notch_l)
		# 左侧缺口旁的竖线
		var notch_lv = ColorRect.new()
		notch_lv.position = Vector2(notch_w, ny - 4)
		notch_lv.size = Vector2(1, 10)
		notch_lv.color = Color(char_color, 0.3)
		notch_lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(notch_lv)

		# 右侧缺口
		var notch_r = ColorRect.new()
		notch_r.position = Vector2(cw - notch_w, ny)
		notch_r.size = Vector2(notch_w, notch_h)
		notch_r.color = notch_color
		notch_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(notch_r)
		# 右侧缺口旁的竖线
		var notch_rv = ColorRect.new()
		notch_rv.position = Vector2(cw - notch_w - 1, ny - 4)
		notch_rv.size = Vector2(1, 10)
		notch_rv.color = Color(char_color, 0.3)
		notch_rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(notch_rv)

	# ===== 顶部中央标签装饰（角色代号风格） =====
	var code_label = Label.new()
	code_label.text = "/// " + ("INF" if char_color == Color("#00F0FF") else "CSR") + " ///"
	code_label.position = Vector2(cw / 2.0 - 50, -1)
	code_label.size = Vector2(100, 16)
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.add_theme_font_size_override("font_size", 10)
	code_label.add_theme_color_override("font_color", Color(char_color, 0.6))
	code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(code_label)

	# ===== 卡片整体边框呼吸脉冲动画 =====
	var card_glow = card.create_tween().set_loops()
	card_glow.tween_property(card, "modulate:a", 0.92, 2.5)
	card_glow.tween_property(card, "modulate:a", 1.0, 2.5)


# ===== 卡组详情弹窗 =====

## 显示卡组详情全屏遮罩弹窗，展示角色初始卡组所有卡牌的详细信息
func _show_deck_detail_overlay(char_id: String, char_color: Color):
	# 防止重复打开
	if has_node("DeckDetailOverlay"):
		return

	var deck = CardDatabase.get_starting_deck_for_character(char_id)
	var char_info = CardDatabase.get_character_info(char_id)
	var char_name = char_info.get("name", char_id)

	# ---- 全屏半透明遮罩背景 ----
	var overlay = ColorRect.new()
	overlay.name = "DeckDetailOverlay"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# 点击遮罩空白处关闭
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_deck_detail_overlay()
	)
	add_child(overlay)

	# ---- 居中面板容器（VBox） ----
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel_box = VBoxContainer.new()

	panel_box.add_theme_constant_override("separation", 16)
	# 限制面板最大宽度（容纳3张240px战斗卡牌 + 间距）
	panel_box.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel_box)

	# ---- 顶部标题栏（HBox：标题 + 关闭按钮） ----
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	panel_box.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "%s - 初始卡组（%d 张）" % [char_name, deck.size()]
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", char_color)
	header.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color("#CCCCCC"))
	# 按钮样式
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color("#1A1A3A")
	close_style.border_color = Color(char_color, 0.6)
	close_style.border_width_left = 1
	close_style.border_width_right = 1
	close_style.border_width_top = 1
	close_style.border_width_bottom = 1
	close_style.corner_radius_top_left = 4
	close_style.corner_radius_top_right = 4
	close_style.corner_radius_bottom_left = 4
	close_style.corner_radius_bottom_right = 4
	close_style.content_margin_left = 12
	close_style.content_margin_right = 12
	close_style.content_margin_top = 6
	close_style.content_margin_bottom = 6
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(_close_deck_detail_overlay)
	header.add_child(close_btn)

	# ---- 分隔线 ----
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(char_color, 0.4)
	panel_box.add_child(sep)

	# ---- 卡牌滚动区域 ----
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(860, 680)
	# 隐藏横向滚动条
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_box.add_child(scroll)

	# 卡牌网格容器（每行3张，使用战斗界面的CardUI原始尺寸）
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# ---- 生成每张卡牌（复用战斗界面的CardUI组件） ----
	for card_id in deck:
		var cdef = CardDatabase.get_card_def(card_id)
		if cdef.is_empty():
			continue
		var card_ui = CardUIScene.instantiate()
		card_ui.setup_card(cdef.duplicate())
		card_ui.fast_mode = true  # 跳过动画
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 禁用鼠标交互，防止悬停动画导致位移
		# 连接信号为空操作（仅查看，不交互）
		card_ui.card_clicked.connect(func(_c): pass)
		card_ui.inject_clicked.connect(func(_c): pass)
		grid.add_child(card_ui)

	# ---- 入场淡入动画 ----
	overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)


## 关闭卡组详情弹窗（带淡出动画）
func _close_deck_detail_overlay():
	if not has_node("DeckDetailOverlay"):
		return
	var overlay = get_node("DeckDetailOverlay")
	# 阻止重复关闭
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(overlay.queue_free)
