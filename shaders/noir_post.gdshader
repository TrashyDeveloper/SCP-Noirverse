// Full-screen "film noir" filter: black & white, strong contrast,
// film grain, vignette, a slight frame flicker and the odd film scratch.
// It is drawn on top of everything by scenes/effects/noir_overlay.tscn.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 0 = pure black & white, 1 = original colours.
uniform float saturation : hint_range(0.0, 1.0) = 0.06;
uniform float contrast : hint_range(0.5, 2.5) = 1.35;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
// Slight warm paper tint, like old film stock.
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
uniform float grain_amount : hint_range(0.0, 0.5) = 0.09;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.65;
uniform float flicker_amount : hint_range(0.0, 0.3) = 0.04;
uniform float scratch_amount : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;

	// Desaturate.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);

	// Contrast around mid-grey, then brightness.
	color = (color - 0.5) * contrast + 0.5 + brightness;
	color *= tint;

	// Film runs at ~24 frames per second; noise changes per "film frame".
	float frame = floor(TIME * 24.0);
	float seed = fract(frame * 0.6180339);

	// Grain.
	float grain = hash(FRAGCOORD.xy + seed * 1000.0) - 0.5;
	color += grain * grain_amount;

	// Occasional thin vertical scratch.
	float scratch_x = hash(vec2(frame, 7.0));
	float scratch_on = step(1.0 - scratch_amount * 0.25, hash(vec2(frame, 3.0)));
	float scratch = (1.0 - smoothstep(0.0, 0.0015, abs(SCREEN_UV.x - scratch_x))) * scratch_on;
	color += scratch * 0.25;

	// Whole-frame flicker.
	color *= 1.0 - flicker_amount * hash(vec2(frame, 1.0));

	// Vignette (darker corners).
	vec2 centered = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.85, 0.3, length(centered * vec2(1.1, 1.0)));
	color *= mix(1.0, vignette, vignette_strength);

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
