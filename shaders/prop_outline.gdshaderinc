uniform vec4 outline_color : source_color = vec4(1.0);
uniform float outline_width = 0.0;
uniform vec3 radial_center = vec3(0.0);

vec3 outlined_vertex(vec3 vertex, vec3 normal) {
	vec3 away = vertex - radial_center;
	vec3 outward = length(away) > 0.0001 ? normalize(away) : normal;
	return vertex + outward * outline_width;
}
