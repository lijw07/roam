extends Control

## Small vector input symbols, kept crisp at any HUD scale.
var key := ""
var mouse_button := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := ThemeDB.fallback_font
	custom_minimum_size = Vector2(24.0 if mouse_button else maxf(24.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0), 24.0)

func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.11, 0.12, 0.88)
	box.border_color = Color(0.66, 0.69, 0.72, 0.65)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7 if mouse_button else 3)
	var rect := Rect2(Vector2(3, 0), Vector2(18, 24)) if mouse_button else Rect2(Vector2.ZERO, size)
	draw_style_box(box, rect)
	if mouse_button:
		var side := Rect2(5 if mouse_button == MOUSE_BUTTON_LEFT else 13, 3, 6, 7)
		draw_rect(side, Color(0.9, 0.91, 0.92))
		draw_line(Vector2(12, 2), Vector2(12, 11), box.border_color, 1)
		draw_line(Vector2(4, 12), Vector2(20, 12), box.border_color, 1)
	else:
		var font := ThemeDB.fallback_font
		var text_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - text_width) / 2, 16), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.91, 0.92))
