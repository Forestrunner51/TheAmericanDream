extends CanvasLayer
## All HUD widgets are built in code so there is no fragile .tscn to break.

@export var font_size_big: int = 40
@export var font_size_banner: int = 72
@export var low_health_threshold: int = 30
@export var banner_hold_time: float = 1.2
@export var damage_flash_alpha: float = 0.45
@export var font_path: String = "res://assets/fonts/kenney_future.ttf"
@export var crosshair_texture_path: String = "res://assets/ui/crosshair.png"
@export var crosshair_size: float = 46.0
@export var panel_texture_path: String = "res://assets/ui/panel.png"
@export var panel_patch_margin: int = 6

var _health_label: Label
var _wave_label: Label
var _banner_label: Label
var _damage_rect: ColorRect
var _banner_tween: Tween
var _flash_tween: Tween
var _font: Font


func _ready() -> void:
	layer = 10
	_load_font()
	_build_damage_flash()
	_build_crosshair()
	_build_health_label()
	_build_wave_label()
	_build_banner()


# --- Public API ---------------------------------------------------------

func set_health(value: int) -> void:
	_health_label.text = "HP %d" % value
	if value < low_health_threshold:
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	else:
		_health_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))


func set_wave(index: int, total: int) -> void:
	_wave_label.text = "WAVE %d/%d" % [index, total]


func show_banner(text: String, hold: float = -1.0) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var wait := banner_hold_time if hold < 0.0 else hold
	_banner_tween = create_tween()
	_banner_tween.tween_interval(wait)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 0.6)


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_damage_rect.color = Color(0.8, 0.0, 0.0, damage_flash_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_rect, "color:a", 0.0, 0.45)


# --- Construction -------------------------------------------------------

func _build_damage_flash() -> void:
	_damage_rect = ColorRect.new()
	_damage_rect.name = "DamageFlash"
	_damage_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_damage_rect)


func _load_font() -> void:
	if ResourceLoader.exists(font_path):
		var res := load(font_path)
		if res is Font:
			_font = res as Font


func _build_crosshair() -> void:
	var root := Control.new()
	root.name = "Crosshair"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	if ResourceLoader.exists(crosshair_texture_path):
		var tex := load(crosshair_texture_path)
		if tex is Texture2D:
			var icon := TextureRect.new()
			icon.texture = tex as Texture2D
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
			icon.set_anchors_preset(Control.PRESET_CENTER)
			icon.size = Vector2(crosshair_size, crosshair_size)
			icon.position = Vector2(-crosshair_size * 0.5, -crosshair_size * 0.5)
			root.add_child(icon)
			return

	_add_crosshair_bar(root, Vector2(2.0, 12.0), Vector2(-1.0, -22.0))
	_add_crosshair_bar(root, Vector2(2.0, 12.0), Vector2(-1.0, 10.0))
	_add_crosshair_bar(root, Vector2(12.0, 2.0), Vector2(-22.0, -1.0))
	_add_crosshair_bar(root, Vector2(12.0, 2.0), Vector2(10.0, -1.0))
	_add_crosshair_bar(root, Vector2(3.0, 3.0), Vector2(-1.5, -1.5))


func _add_crosshair_bar(root: Control, size: Vector2, offset: Vector2) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.95, 0.95, 0.95, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.size = size
	bar.position = offset
	root.add_child(bar)


func _build_health_label() -> void:
	var panel := _make_panel(Vector2(252.0, 86.0))
	if panel != null:
		panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		panel.position = Vector2(24.0, -112.0)
		add_child(panel)

	_health_label = Label.new()
	_health_label.name = "HealthLabel"
	_health_label.text = "HP 100"
	_styled(_health_label, font_size_big)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_label.size = Vector2(252.0, 86.0)
	_health_label.position = Vector2(24.0, -112.0)
	add_child(_health_label)


func _build_wave_label() -> void:
	var panel_size := Vector2(320.0, 82.0)
	var panel := _make_panel(panel_size)
	if panel != null:
		panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		panel.position = Vector2(-panel_size.x * 0.5, 20.0)
		add_child(panel)

	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.text = "WAVE 1/3"
	_styled(_wave_label, font_size_big)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wave_label.size = panel_size
	_wave_label.position = Vector2(-panel_size.x * 0.5, 20.0)
	add_child(_wave_label)


## Kenney's adventure UI panel, nine-sliced. Returns null if the sprite is gone,
## so the HUD still reads fine on bare labels.
func _make_panel(panel_size: Vector2) -> NinePatchRect:
	if not ResourceLoader.exists(panel_texture_path):
		return null
	var tex := load(panel_texture_path)
	if not (tex is Texture2D):
		return null
	var panel := NinePatchRect.new()
	panel.texture = tex as Texture2D
	panel.patch_margin_left = panel_patch_margin
	panel.patch_margin_right = panel_patch_margin
	panel.patch_margin_top = panel_patch_margin
	panel.patch_margin_bottom = panel_patch_margin
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1.0, 1.0, 1.0, 0.82)
	panel.size = panel_size
	return panel


func _build_banner() -> void:
	_banner_label = Label.new()
	_banner_label.name = "Banner"
	_banner_label.text = ""
	_styled(_banner_label, font_size_banner)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.anchor_left = 0.0
	_banner_label.anchor_right = 1.0
	_banner_label.anchor_top = 0.3
	_banner_label.anchor_bottom = 0.3
	_banner_label.offset_left = 0.0
	_banner_label.offset_right = 0.0
	_banner_label.offset_top = 0.0
	_banner_label.offset_bottom = 110.0
	_banner_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_banner_label)


func _styled(label: Label, size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 10)
