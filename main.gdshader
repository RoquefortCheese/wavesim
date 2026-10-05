shader_type canvas_item;
uniform highp sampler2D screen;
uniform sampler2D pxtype;
const float c2 = 2.;
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

float pointpos(vec2 uv, vec2 sps, vec2 disp, int mag) {
	vec2 point = uv + (disp * float(mag)) * sps;
	if (min(point.x, point.y) < 0. || max(point.x, point.y) >= 1.) {
		return 0.;
	}
	return storetoval(texture(screen, point).x);
}

void fragment() {
	vec2 self = texture(screen, UV).xy;
	float pos;
	float vel;
	switch (int(round(texture(pxtype, UV).r * 8.))) {
		case 0:  // standard
			pos = storetoval(self.x);
			vel = storetoval(self.y);
			for (int axis = 0; axis < 2; axis++) {
				float sum = 0.;
				for (int delta = -sampr; delta <= sampr; delta++) {
					vec2 disp = vec2(0);
					disp[axis] = 1.;
					//float left = storetoval(texture(screen, UV + (disp * float(delta - 1)) * SCREEN_PIXEL_SIZE).x);
					//float middle = storetoval(texture(screen, UV + (disp * float(delta)) * SCREEN_PIXEL_SIZE).x);
					//float right = storetoval(texture(screen, UV + (disp * float(delta + 1)) * SCREEN_PIXEL_SIZE).x);
					float left = pointpos(UV, SCREEN_PIXEL_SIZE, disp, delta - 1);
					float middle = pointpos(UV, SCREEN_PIXEL_SIZE, disp, delta);
					float right = pointpos(UV, SCREEN_PIXEL_SIZE, disp, delta + 1);
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
		case 3:  // offset oscillator
			float factor = PI * speed;
			float osctime = TIME * factor;
			pos = -sin(osctime);
			vel = -cos(osctime) * factor;
			break;
	}
	COLOR.x = valtostore(pos);
	COLOR.y = valtostore(vel);
}
