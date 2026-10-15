shader_type canvas_item;
render_mode unshaded;
// 手绘地面的水面闪光：TEXTURE 是水面遮罩（白=水）。
// 只画稀疏的短横高光（1 格高、3 格长，网格对齐），各自随机明灭，不覆盖已画好的浪花。
uniform vec4 glint_color : source_color = vec4(0.88, 0.97, 0.94, 0.8);
uniform vec2 extent = vec2(960.0, 1248.0);
uniform float cell = 2.0;
uniform float density = 0.05;   // 存在高光的短横比例
uniform float lit = 0.3;        // 每条短横在一个周期内亮起的时间比例
uniform float speed = 0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (texture(TEXTURE, UV).r < 0.5) { discard; }
	vec2 px = floor(UV * extent / cell);
	vec2 dash = vec2(floor(px.x / 3.0), px.y);
	if (hash(dash) < 1.0 - density) { discard; }
	if (fract(TIME * speed + hash(dash + 17.0)) > lit) { discard; }
	COLOR = glint_color;
}
