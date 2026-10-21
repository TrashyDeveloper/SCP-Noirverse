// Facility walls, floors and ceilings: dark metal panels with seams.
// Uses world coordinates, so boxes of any size get evenly sized panels
// and neighbouring boxes line up.
//   Vertical faces (walls): vertical panel seams, darker kick-plate band at
//   the bottom and a horizontal trim line.
//   Horizontal faces (floor/ceiling): square tile grid.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.17, 0.17, 0.18);
uniform vec3 seam_color : source_color = vec3(0.03, 0.03, 0.035);
uniform vec3 trim_color : source_color = vec3(0.32, 0.32, 0.33);
uniform float panel_width = 1.5;
uniform float seam_width = 0.022;
uniform float kick_height = 0.32;
uniform float trim_height = 2.35;
uniform float tile_size = 1.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.15;
uniform float roughness_min : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_max : hint_range(0.0, 1.0) = 0.85;
// Grime / wear (any noise texture).
uniform sampler2D grime : hint_default_white, repeat_enable;
uniform float grime_scale = 0.35;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.22;

varying vec3 world_pos;
varying vec3 world_normal;

// 1 on a seam line, 0 elsewhere (soft edge).
float line(float coord, float spacing, float width) {
	float d = abs(coord - round(coord / spacing) * spacing);
	return 1.0 - smoothstep(width * 0.5, width, d);
}

// A thin bright edge just next to a seam (fake bevel).
float bevel(float coord, float spacing, float width) {
	float d = abs(coord - round(coord / spacing) * spacing);
	return smoothstep(width, width * 1.5, d) * (1.0 - smoothstep(width * 1.5, width * 3.0, d));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = base_color;
	float seam = 0.0;
	float edge = 0.0;
	vec2 grime_uv;
	if (abs(world_normal.y) > 0.5) {
		// Floor or ceiling tiles.
		seam = max(line(world_pos.x, tile_size, seam_width), line(world_pos.z, tile_size, seam_width));
		edge = max(bevel(world_pos.x, tile_size, seam_width), bevel(world_pos.z, tile_size, seam_width));
		grime_uv = world_pos.xz;
	} else {
		// Walls: measure along the wall's length.
		float along = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
		float y = world_pos.y;
		seam = line(along, panel_width, seam_width);
		edge = bevel(along, panel_width, seam_width);
		// Darker kick plate at the bottom, with its own seam.
		if (y < kick_height) {
			col *= 0.6;
		}
		seam = max(seam, 1.0 - smoothstep(seam_width * 0.5, seam_width, abs(y - kick_height)));
		// Horizontal trim strip.
		float trim = 1.0 - smoothstep(0.03, 0.04, abs(y - trim_height));
		col = mix(col, trim_color, trim);
		grime_uv = vec2(along, y);
	}
	float g = texture(grime, grime_uv * grime_scale).r;
	col *= mix(1.0, g * 1.4, grime_strength);
	col += edge * 0.04;
	col = mix(col, seam_color, seam);
	ALBEDO = col;
	METALLIC = metallic_amount * (1.0 - seam);
	ROUGHNESS = mix(roughness_min, roughness_max, g);
}
