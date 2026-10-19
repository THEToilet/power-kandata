shader_type canvas_item;
// 画面全体を PICO-8 の16色に寄せる。半透明やグラデーションの中間色は 4x4 のディザで表す
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float spread = 0.0;   // 0 = ディザなし（色をくっきり）
uniform float pixel = 3.0;    // ドット1粒の大きさ。画面を格子ごとに1色にそろえる

const vec3 PAL[16] = vec3[16](
	vec3(0.0000, 0.0000, 0.0000),
	vec3(0.1137, 0.1686, 0.3255),
	vec3(0.4941, 0.1451, 0.3255),
	vec3(0.0000, 0.5294, 0.3176),
	vec3(0.6706, 0.3216, 0.2118),
	vec3(0.3725, 0.3412, 0.3098),
	vec3(0.7608, 0.7647, 0.7804),
	vec3(1.0000, 0.9451, 0.9098),
	vec3(1.0000, 0.0000, 0.3020),
	vec3(1.0000, 0.6392, 0.0000),
	vec3(1.0000, 0.9255, 0.1529),
	vec3(0.0000, 0.8941, 0.2118),
	vec3(0.1608, 0.6784, 1.0000),
	vec3(0.5137, 0.4627, 0.6118),
	vec3(1.0000, 0.4667, 0.6588),
	vec3(1.0000, 0.8000, 0.6667)
);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0 - 0.46875;
}

void fragment() {
	vec2 cell = (floor(FRAGCOORD.xy / pixel) * pixel + pixel * 0.5) * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, cell).rgb;
	c += bayer4(floor(FRAGCOORD.xy / pixel)) * spread;
	float best = 1e9;
	vec3 bc = PAL[0];
	for (int i = 0; i < 16; i++) {
		vec3 d = c - PAL[i];
		float rm = (c.r + PAL[i].r) * 0.5;
		float dist = (2.0 + rm) * d.r * d.r + 4.0 * d.g * d.g + (3.0 - rm) * d.b * d.b;
		if (dist < best) {
			best = dist;
			bc = PAL[i];
		}
	}
	COLOR = vec4(bc, 1.0);
}
