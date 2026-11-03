shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.78, 0.16, 0.16, 1.0);
uniform vec4 empty_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 color = UV.x <= fill ? fill_color : empty_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
