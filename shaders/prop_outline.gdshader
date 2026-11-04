shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
stencil_mode read, compare_not_equal, 1;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width = 0.0;
uniform vec3 radial_center = vec3(0.0);
uniform float depth_pull = 0.5;

vec3 outward(vec3 vertex, vec3 normal) {
	vec3 away = vertex - radial_center;
	return length(away) > 0.0001 ? normalize(away) : normal;
}

void vertex() {
	VERTEX += outward(VERTEX, NORMAL) * outline_width;
	vec3 camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	VERTEX += normalize(camera - VERTEX) * depth_pull;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
