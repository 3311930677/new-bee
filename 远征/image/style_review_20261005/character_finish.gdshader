shader_type canvas_item;
render_mode unshaded;

// Shared finish applies to every existing frame without changing registration.
uniform float saturation = 0.94;
uniform float contrast = 1.10;
uniform float color_steps = 24.0;
uniform float edge_strength = 0.22;
uniform vec3 warmth = vec3(1.025, 1.0, 0.975);
uniform vec2 logical_grid = vec2(0.0);
varying vec4 sprite_tint;

void vertex() {
    sprite_tint = COLOR;
}

void fragment() {
    vec2 uv = UV;
    vec2 step_uv = TEXTURE_PIXEL_SIZE;
    if (logical_grid.x > 0.0) {
        uv = (floor(UV * logical_grid) + 0.5) / logical_grid;
        step_uv = 1.0 / logical_grid;
    }
    vec4 tex = texture(TEXTURE, uv);
    float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 rgb = mix(vec3(luma), tex.rgb, saturation);
    rgb = clamp((rgb - vec3(0.5)) * contrast + vec3(0.5), vec3(0.0), vec3(1.0));
    rgb = clamp(rgb * warmth, vec3(0.0), vec3(1.0));
    rgb = floor(rgb * color_steps + vec3(0.5)) / color_steps;
    float neighbor_alpha = min(min(texture(TEXTURE, uv + vec2(step_uv.x, 0.0)).a,
        texture(TEXTURE, uv - vec2(step_uv.x, 0.0)).a),
        min(texture(TEXTURE, uv + vec2(0.0, step_uv.y)).a,
        texture(TEXTURE, uv - vec2(0.0, step_uv.y)).a));
    float edge = (1.0 - smoothstep(0.1, 0.8, neighbor_alpha)) * edge_strength;
    rgb = mix(rgb, rgb * vec3(0.57, 0.61, 0.66), edge);
    COLOR = vec4(rgb, tex.a) * sprite_tint;
}
