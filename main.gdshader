shader_type canvas_item;
uniform sampler2D screen;
const float c2 = 1.;
const float vm = 0.1;
const int sampr = 0;
const float speed = 1.5;

float storetoval(float stored) {
	//return tan((0.5 - stored) * PI);
	return stored * 4. - 2.;
}

float valtostore(float val) {
	//return 0.5 - atan(val) / PI;
	return (val + 2.) / 4.;
}

void fragment() {
	vec3 self = texture(screen, UV).xyz;
	float pos;
	float vel;
	switch (int(self.z * 8.)) {
		case 0:  // standard
			pos = storetoval(self.x);
			vel = storetoval(self.y);
			for (int axis = 0; axis < 2; axis++) {
				float sum = 0.;
				for (int delta = -sampr; delta <= sampr; delta++) {
					vec2 disp = vec2(0);
					disp[axis] = 1.;
					float left = storetoval(texture(screen, UV + (disp * float(delta - 1)) * SCREEN_PIXEL_SIZE).x);
					float middle = storetoval(texture(screen, UV + (disp * float(delta)) * SCREEN_PIXEL_SIZE).x);
					float right = storetoval(texture(screen, UV + (disp * float(delta + 1)) * SCREEN_PIXEL_SIZE).x);
					float ld = middle - left;
					float rd = right - middle;
					float slopeslope = rd - ld;
					sum += slopeslope;
				}
				vel += sum / float(sampr * 2 + 1) * c2;
			}
			pos += vel * vm;
			break;
		case 1:  // stone
			pos = 0.;
			vel = 0.;
			break;
		case 2:  // oscillator
			float factor = PI * speed;
			float osctime = TIME * factor;
			pos = sin(osctime);
			vel = cos(osctime) * factor;
			break;
	}
	COLOR.x = valtostore(pos);
	COLOR.y = valtostore(vel);
	COLOR.z = self.z;
}
