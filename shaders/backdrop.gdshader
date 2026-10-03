// Фон экранов вне боя: мягкий градиент, шум «пергамента в дыму», виньетка. Статичный.
shader_type canvas_item;

uniform vec2 size = vec2(1920.0, 1080.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * size;
	vec3 col = COLOR.rgb * (0.85 + 0.3 * fbm(px * 0.003));
	col += vec3(0.05, 0.035, 0.02) * smoothstep(0.55, 0.9, fbm(px * 0.0015 + 7.0));
	col *= mix(1.15, 0.8, UV.y);
	vec2 d = UV - 0.5;
	col *= mix(0.55, 1.0, smoothstep(0.9, 0.3, length(d * vec2(1.0, 1.3))));
	COLOR = vec4(col, 1.0);
}
