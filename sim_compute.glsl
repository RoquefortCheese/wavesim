#[compute]
#version 450

// State is rgba32f: position, velocity, cell type, unused.
// Cell type: 0 standard, 1 stone, 2 oscillator, 3 inverted oscillator.
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba32f, set = 0, binding = 0) uniform restrict readonly image2D src_image;
layout(rgba32f, set = 1, binding = 0) uniform restrict writeonly image2D dst_image;

layout(push_constant, std430) uniform Params {
	float time;
	float pad0;
	float pad1;
	float pad2;
} params;

const float C2 = 1.0;
const float VM = 0.1;
const float SPEED = 1.5;
const float PI = 3.14159265358979323846;

ivec2 wrap_coord(ivec2 p, ivec2 size) {
	return (p + size) % size;
}

float sample_pos(ivec2 p, ivec2 size) {
	return imageLoad(src_image, wrap_coord(p, size)).r;
}

void main() {
	ivec2 size = imageSize(src_image);
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	vec4 self = imageLoad(src_image, uv);
	float pos = self.r;
	float vel = self.g;
	float kind = self.b;
	int cell = int(kind + 0.5);

	if (cell == 1) {
		pos = 0.0;
		vel = 0.0;
	} else if (cell == 2 || cell == 3) {
		float sgn = cell == 2 ? 1.0 : -1.0;
		float factor = PI * SPEED;
		float osctime = params.time * factor;
		pos = sgn * sin(osctime);
		vel = sgn * cos(osctime) * factor;
	} else {
		// Isotropic 9-point Laplacian. A plus-shaped second difference
		// makes short waves move faster on the diagonal, which kinks the
		// wavefront. These weights cancel that leading directional error:
		// (1/6) * | 1  4  1 |
		//         | 4 -20 4 |
		//         | 1  4  1 |
		float center = pos;
		float orth = sample_pos(uv + ivec2(1, 0), size)
			+ sample_pos(uv + ivec2(-1, 0), size)
			+ sample_pos(uv + ivec2(0, 1), size)
			+ sample_pos(uv + ivec2(0, -1), size);
		float diag = sample_pos(uv + ivec2(1, 1), size)
			+ sample_pos(uv + ivec2(-1, 1), size)
			+ sample_pos(uv + ivec2(1, -1), size)
			+ sample_pos(uv + ivec2(-1, -1), size);
		float lap = (4.0 * orth + diag - 20.0 * center) / 6.0;
		vel += lap * C2;
		pos += vel * VM;
	}

	imageStore(dst_image, uv, vec4(pos, vel, kind, 1.0));
}
