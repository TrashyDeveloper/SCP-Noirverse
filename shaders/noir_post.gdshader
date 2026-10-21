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
// A round area of the screen where colour comes back (e.g. around the
// Gamma reactor). Centre in screen UV, radius in screen heights.
uniform vec2 color_center = vec2(0.5, 0.5);
uniform float color_radius = 0.0;
uniform float color_strength : hint_range(0.0, 1.0) = 0.0;
// Reality breaking down (near the overheating Gamma reactor): torn lines,
// colour channels splitting apart, blocks of static, inverted flashes.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// Gravitational lens (the black/white hole): centre in screen UV, radius in
// screen heights, strength > 0 pulls light in, < 0 pushes it out.
uniform vec2 lens_center = vec2(0.5, 0.5);
uniform float lens_radius = 0.0;
uniform float lens_strength = 0.0;
// Inside a time-stop field: cold blue picture, frozen film grain.
uniform float stasis : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float frame = floor(TIME * 24.0);
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// Gravitational lens: bend the picture around the hole.
	if (lens_radius > 0.0 && lens_strength != 0.0) {
		vec2 dv = (uv - lens_center) * vec2(aspect, 1.0);
		float d = max(length(dv), 0.0001);
		float reach = smoothstep(lens_radius * 5.0, lens_radius * 1.1, d);
		float bend = lens_strength * lens_radius * lens_radius / max(d, lens_radius * 0.6) * reach;
		uv -= (dv / d) / vec2(aspect, 1.0) * bend * 0.35;
		// Swirl around a black hole.
		float swirl = lens_strength * reach * 0.6;
		vec2 rel = uv - lens_center;
		float c = cos(swirl), s = sin(swirl);
		uv = lens_center + vec2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
	}

	// Glitch: tear some horizontal bands sideways.
	float g = glitch;
	if (g > 0.0) {
		float band = floor(uv.y * mix(12.0, 60.0, hash(vec2(frame, 11.0))));
		float tear = step(1.0 - g * 0.45, hash(vec2(band, frame)));
		uv.x += (hash(vec2(band, frame + 3.0)) - 0.5) * 0.25 * g * tear;
		// The whole picture jumps now and then.
		uv.y += step(1.0 - g * 0.15, hash(vec2(frame, 5.0))) * (hash(vec2(frame, 6.0)) - 0.5) * 0.1 * g;
	}
	float split = g * 0.012 * (0.5 + hash(vec2(frame, 9.0)));
	vec3 color;
	color.r = texture(screen_texture, uv + vec2(split, 0.0)).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - vec2(split, split * 0.5)).b;

	// Desaturate.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float sat = saturation;
	if (color_strength > 0.0 && color_radius > 0.0) {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		float d = length((SCREEN_UV - color_center) * vec2(aspect, 1.0));
		float zone = 1.0 - smoothstep(color_radius * 0.3, color_radius, d);
		// A shimmering edge, like light bending around the reactor.
		zone *= 0.9 + 0.1 * sin(d * 60.0 - TIME * 8.0);
		sat = mix(sat, 1.15, clamp(zone * color_strength, 0.0, 1.0));
	}
	color = mix(vec3(luma), color, sat);

	// Contrast around mid-grey, then brightness.
	color = (color - 0.5) * contrast + 0.5 + brightness;
	color *= tint;

	// Film runs at ~24 frames per second; noise changes per "film frame".
	// (In a time-stop field the film stops too.)
	float seed = fract(mix(frame, 7.0, step(0.5, stasis)) * 0.6180339);
	color = mix(color, vec3(dot(color, vec3(0.299, 0.587, 0.114))) * vec3(0.72, 0.86, 1.15), stasis * 0.8);

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

	// Glitch: blocks of static and inverted flashes.
	if (g > 0.0) {
		vec2 block = floor(SCREEN_UV * vec2(24.0, 14.0));
		float noisy = step(1.0 - g * g * 0.08, hash(block + frame));
		color = mix(color, vec3(hash(FRAGCOORD.xy + frame)), noisy);
		float invert = step(1.0 - g * 0.04, hash(vec2(frame, 21.0)));
		color = mix(color, 1.0 - color, invert);
		color += (hash(vec2(SCREEN_UV.y * 400.0, frame)) - 0.5) * 0.2 * g;
	}

	// Vignette (darker corners).
	vec2 centered = SCREEN_UV - 0.5;
	float vignette = smoothstep(0.85, 0.3, length(centered * vec2(1.1, 1.0)));
	color *= mix(1.0, vignette, vignette_strength);

	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
