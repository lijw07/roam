uniform vec4 vfx_player_view_sphere = vec4(0.0);

bool vfx_covers_player(vec3 view_position) {
	float radius = vfx_player_view_sphere.w;
	if (radius <= 0.0) {
		return false;
	}
	vec3 center = vfx_player_view_sphere.xyz;
	vec3 sight = normalize(view_position);
	float along = dot(center, sight);
	return length(view_position) < along && distance(center, sight * along) < radius;
}
