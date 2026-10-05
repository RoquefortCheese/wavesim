shader_type canvas_item;
uniform highp sampler2D screen: hint_screen_texture;
uniform sampler2D pxtype;
uniform vec3 wavecolor;
uniform vec3 magnicolor;
uniform vec3 stonecolor;
uniform bool magnitude;

float storetoval(float stored) {
	//return tan((0.5 - stored) * PI);
	return stored * 4. - 2.;
}

void fragment() {
	vec3 self = texture(screen, UV).xyz;
	switch (int(round(texture(pxtype, UV).r * 8.))) {
		case 0:
		case 2:
		case 3:
			float waveval = clamp(storetoval(self.x), -2., 2.) / 2.;
			float brightness = magnitude ? abs(waveval) : ((waveval + 1.) / 2.);
			COLOR.rgb = (magnitude ? magnicolor : wavecolor) * brightness;
			break;
		case 1:
			COLOR.rgb = stonecolor;
			break;
	}
}