shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

#include "res://shaders/prop_outline.gdshaderinc"

uniform float depth_pull = 0.5;

void vertex() {
	VERTEX = outlined_vertex(VERTEX, NORMAL);
	vec3 camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	VERTEX += normalize(camera - VERTEX) * depth_pull;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
