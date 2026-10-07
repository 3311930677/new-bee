shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_atlas : source_color, filter_nearest;
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform vec2 surface_scale = vec2(1.0);

void fragment() {
	float road = texture(TEXTURE, UV).r;
	// Larger expedition maps keep the same material pixel scale as the world maps.
	// Mirror at patch boundaries to avoid a hard texture seam.
	vec2 material_uv = vec2(1.0) - abs(fract(UV * surface_scale * 0.5) * 2.0 - vec2(1.0));
	// Separate generated terrain and road materials; the mask follows the real game route.
	vec3 terrain = texture(surface_atlas, vec2(material_uv.x * 0.5, material_uv.y)).rgb;
	vec3 track = texture(surface_atlas, vec2(0.5 + material_uv.x * 0.5, material_uv.y)).rgb;
	COLOR = vec4(mix(terrain, track, road) * surface_tint.rgb, 1.0);
}
