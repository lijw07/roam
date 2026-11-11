shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

#include "res://shaders/prop_outline.gdshaderinc"

void vertex() {
	VERTEX = outlined_vertex(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
