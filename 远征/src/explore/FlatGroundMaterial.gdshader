shader_type canvas_item;
render_mode unshaded;

uniform sampler2D surface_atlas : source_color, filter_linear;
uniform vec4 surface_tint : source_color = vec4(1.0);
uniform vec2 surface_scale = vec2(1.0);
uniform vec2 map_dimensions = vec2(960.0, 1248.0);
uniform int biome_type = 0; // 0:forest, 1:snow, 2:desert, 3:cavern, 4:abyss, 5:tide
uniform bool original_art = true;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float road = texture(TEXTURE, UV).r;
	vec2 px = original_art ? UV * map_dimensions : floor(UV * map_dimensions);

	// 1. High-Density 16-Bit Tile Frequency (96px tile domain instead of 1000px stretch)
	// This eliminates the crude "一深一浅" oversized blurry patch problem!
	vec2 micro_offset = vec2(
		sin(px.y * 0.08 + px.x * 0.05) * 3.0,
		cos(px.x * 0.07 - px.y * 0.06) * 3.0
	);
	vec2 tile_coord = px + micro_offset;
	vec2 tile_uv = fract(tile_coord / 96.0);
	vec2 macro_uv = fract((px + vec2(sin(px.y * 0.02) * 12.0, cos(px.x * 0.02) * 12.0)) / 288.0);

	// Sample atlas at native game resolution with dual-octave variation
	vec3 atlas_terrain = texture(surface_atlas, vec2(tile_uv.x * 0.48 + 0.01, tile_uv.y)).rgb;
	vec3 atlas_track = texture(surface_atlas, vec2(0.51 + tile_uv.x * 0.48, tile_uv.y)).rgb;
	vec3 macro_terrain = texture(surface_atlas, vec2(macro_uv.x * 0.48 + 0.01, macro_uv.y)).rgb;
	vec3 macro_track = texture(surface_atlas, vec2(0.51 + macro_uv.x * 0.48, macro_uv.y)).rgb;

	vec3 terrain = mix(atlas_terrain, macro_terrain, 0.35);
	vec3 track = mix(atlas_track, macro_track, 0.30);
	if (original_art) {
		COLOR = vec4(mix(atlas_terrain, atlas_track, smoothstep(0.38, 0.62, road)) * surface_tint.rgb, 1.0);
	} else {

	// 2. Multi-tier Handcrafted Pixel Details by Biome
	vec2 cell_16 = floor(px / 16.0);
	float h_cell = hash21(cell_16);
	vec2 cell_8 = floor(px / 8.0);
	float h_8 = hash21(cell_8);
	float h_px = hash21(px);

	if (biome_type == 0) {
		// --- Biome 0: Forest & Mountain Slope (秋林与荒坡) ---
		// Autumn leaf litter: 2x2 gold and crimson leaves scattered on wild turf
		if (road < 0.35 && h_8 > 0.82) {
			vec2 in_cell = mod(px, 8.0);
			if (in_cell.x < 2.0 && in_cell.y < 2.0) {
				vec3 leaf_col = (h_8 > 0.91) ? vec3(0.72, 0.32, 0.15) : vec3(0.81, 0.64, 0.20);
				terrain = mix(terrain, leaf_col, 0.85);
			}
		}
		// Wagon wheel ruts on road: subtle darker packed depressions
		float rut_dist = min(abs(mod(px.x, 36.0) - 10.0), abs(mod(px.x, 36.0) - 26.0));
		if (road > 0.60 && rut_dist < 3.0) {
			track *= 0.88;
		}
	} else if (biome_type == 1) {
		// --- Biome 1: Snow & Frost Post (霜关与坚冰) ---
		// Crystalline ice sparkles on snow
		if (road < 0.40 && h_px > 0.975) {
			terrain = vec3(0.96, 0.98, 1.0);
		}
		// Trodden blue-gray slush on road center
		if (road > 0.55 && h_8 > 0.65) {
			track = mix(track, vec3(0.48, 0.58, 0.68), 0.22);
		}
	} else if (biome_type == 2) {
		// --- Biome 2: Salt Road & Red Sand (盐道与赤砂) ---
		// Polygonal salt crust crystals
		if (road < 0.45 && h_cell > 0.76) {
			vec2 in_cell = mod(px, 16.0);
			if (in_cell.x > 3.0 && in_cell.x < 13.0 && in_cell.y > 3.0 && in_cell.y < 13.0) {
				terrain = mix(terrain, vec3(0.91, 0.95, 0.97), 0.45);
			}
		}
		// Wind-blown sand ripples
		float sand_wave = sin(px.y * 0.45 + px.x * 0.15);
		terrain += vec3(sand_wave * 0.025);
	} else if (biome_type == 3) {
		// --- Biome 3: Cavern & Deep Mines (溶洞与矿脉) ---
		// Chiseled slate seams
		vec2 stone_grid = mod(px, 24.0);
		if (road < 0.45 && (stone_grid.x < 1.0 || stone_grid.y < 1.0)) {
			terrain *= 0.72;
		}
		// Pyrite / mineral gold flecks
		if (h_px > 0.985) {
			terrain = mix(terrain, vec3(0.85, 0.72, 0.25), 0.80);
		}
		// Wooden rail sleeper ties embedded on road track every 32px
		float tie_y = mod(px.y, 32.0);
		if (road > 0.55 && tie_y < 4.0) {
			track = mix(track, vec3(0.28, 0.22, 0.16), 0.70);
		}
	} else if (biome_type == 4) {
		// --- Biome 4: Abyss Ring & Stele Core (渊口与碑心) ---
		// Basalt hexagonal flags with glowing void amethyst fissures
		float fissure = sin(px.x * 0.18 + sin(px.y * 0.15) * 2.0) * cos(px.y * 0.18);
		if (road < 0.45 && abs(fissure) < 0.08) {
			terrain = mix(terrain, vec3(0.65, 0.28, 0.88), 0.75);
		}
		// Inlaid ancient gold leylines on ceremonial path
		if (road > 0.60 && abs(mod(px.x, 48.0) - 24.0) < 2.0) {
			track = mix(track, vec3(0.85, 0.68, 0.28), 0.65);
		}
	} else if (biome_type == 5) {
		// --- Biome 5: Tideflat & Shenyuan Port (潮痕与海港) ---
		// Maritime dark wet silt ripples
		float tide_ripple = sin(px.y * 0.35 + px.x * 0.20);
		terrain += vec3(tide_ripple * 0.035, tide_ripple * 0.045, tide_ripple * 0.055);
		// Wet wooden jetty planks along road
		float plank_y = mod(px.y, 24.0);
		if (road > 0.55 && plank_y < 2.0) {
			track *= 0.78;
		}
	}

	// 3. Pixel-Grid Aligned Micro-Dither & Contact Cobblestones along Road Edge
	vec2 pixel_coord = floor(px * 0.5);
	float dither = fract(sin(dot(pixel_coord, vec2(12.9898, 78.233))) * 43758.5453);
	float edge_blend = smoothstep(0.40, 0.60, road + (dither - 0.5) * 0.16);

	// Cobblestone edge nuggets (natural 3x2 stone border instead of raw linear transition)
	float is_border = smoothstep(0.32, 0.44, road) * (1.0 - smoothstep(0.56, 0.68, road));
	if (is_border > 0.4 && h_8 > 0.68) {
		vec2 in_cell = mod(px, 8.0);
		if (in_cell.x < 4.0 && in_cell.y < 3.0) {
			edge_blend = 0.85; // Embed cobblestone from track material into border
		}
	}

	// 4. Subtle contact shadow / organic soil rim where turf meets path
	float rim = smoothstep(0.32, 0.46, road) * (1.0 - smoothstep(0.52, 0.66, road));
	vec3 blended = mix(terrain, track, edge_blend);
	vec3 final_rgb = mix(blended, blended * 0.70, rim * 0.60);

	// 5. Cinematic Vignette (Subtle edge depth to focus attention on walkable world)
	vec2 vig_uv = UV * (1.0 - UV.yx);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = clamp(pow(vig, 0.15), 0.75, 1.0);
	final_rgb *= vig;

	COLOR = vec4(final_rgb * surface_tint.rgb, 1.0);
	}
}
