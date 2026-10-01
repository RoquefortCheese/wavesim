shader_type canvas_item;
uniform sampler2D state : filter_nearest, repeat_disable, hint_default_black;
uniform vec3 wavecolor;
uniform vec3 magnicolor;
uniform vec3 stonecolor;
uniform bool magnitude;

void fragment() {
	vec3 self = texture(state, UV).xyz;
	switch (int(self.z + 0.5)) {
		case 0:
		case 2:
		case 3:
			float waveval = clamp(self.x, -2.0, 2.0) / 2.0;
			float brightness = magnitude ? abs(waveval) : ((waveval + 1.0) / 2.0);
			COLOR.rgb = (magnitude ? magnicolor : wavecolor) * brightness;
			break;
		case 1:
			COLOR.rgb = stonecolor;
			break;
	}
}
