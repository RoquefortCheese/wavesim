shader_type canvas_item;
uniform sampler2D screen;
const vec3[4] colors = {vec3(0), vec3(0.75), vec3(1, 0, 0), vec3(0, 0, 1)};

void fragment() {
	COLOR.rgb = colors[int(round(texture(screen, UV).x * 8.))];
}