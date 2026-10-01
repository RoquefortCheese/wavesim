shader_type canvas_item;
uniform vec3 samplecol;

void fragment() {
	vec2 disp = abs(UV * 2. - vec2(1));
	COLOR.rgb = max(disp.x, disp.y) > 0.875 ? vec3(1) : samplecol;
}