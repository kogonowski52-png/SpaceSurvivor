shader_type canvas_item;
render_mode unshaded;

uniform vec4 accent : source_color = vec4(0.36, 0.88, 0.9, 1.0);
uniform float sweep = 1.4;
varying vec4 livery;

void vertex() {
	livery = COLOR;
}

void fragment() {
	vec4 hull = texture(TEXTURE, UV);
	float luminance = dot(hull.rgb, vec3(0.2126, 0.7152, 0.0722));
	float metal = smoothstep(0.11, 0.69, luminance);
	float overhead = 1.04 + 0.12 * (1.0 - UV.y);
	float reflection = 1.0 - smoothstep(0.025, 0.19, abs(UV.y + UV.x * 0.20 - sweep));
	vec3 lit = hull.rgb * livery.rgb * overhead;
	lit += mix(vec3(0.70, 0.89, 1.0), accent.rgb, 0.34) * (reflection * metal * 0.20 + metal * 0.04);
	COLOR = vec4(lit, hull.a * livery.a);
}
