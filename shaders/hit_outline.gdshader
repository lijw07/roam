shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width = 0.0;
uniform bool radial = false;

vec3 outward(vec3 vertex, vec3 normal) {
	return radial && length(vertex) > 0.0001 ? normalize(vertex) : normal;
}

void vertex() {
	VERTEX += outward(VERTEX, NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
