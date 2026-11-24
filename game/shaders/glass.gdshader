shader_type canvas_item;
// Frosted glass: blurs what is behind, tints it, rounds the corners
// and adds a thin light rim along the top edge.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(0.035, 0.133, 0.145, 0.72);
uniform vec2 rect_size = vec2(358.0, 64.0);
uniform float radius = 32.0;
uniform float blur = 9.0;
uniform float rim = 0.18;

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	float d = rounded_box(px - rect_size * 0.5, rect_size * 0.5, radius);
	float inside = clamp(0.5 - d, 0.0, 1.0);
	vec2 step_px = SCREEN_PIXEL_SIZE * blur * 0.5;
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float w = exp(-float(x * x + y * y) / 6.0);
			acc += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * step_px).rgb * w;
			wsum += w;
		}
	}
	vec3 col = mix(acc / wsum, tint.rgb, tint.a);
	float edge = 1.0 - smoothstep(0.0, 1.6, abs(d + 0.8));
	float top = 1.0 - smoothstep(0.0, min(rect_size.y * 0.6, 40.0), px.y);
	col += vec3(rim) * edge * (0.25 + 0.75 * top);
	COLOR = vec4(col, inside);
}
