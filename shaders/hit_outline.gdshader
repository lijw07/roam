shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

instance uniform vec4 outline_color : source_color = vec4(1.0);
instance uniform float outline_width = 0.0;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
