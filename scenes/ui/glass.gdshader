shader_type canvas_item;
// Матовое стекло: размытая картинка под панелью, осветлённая полупрозрачной заливкой.
// Форму (скруглённые углы) задаёт стиль панели — шейдер берёт только её прозрачность.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// Сила размытия (уровень мип-карты экрана).
uniform float blur : hint_range(0.0, 6.0) = 4.2;
// Цвет и плотность «молочной» заливки поверх размытого фона.
uniform vec4 tint : source_color = vec4(0.97, 0.98, 1.0, 0.3);
// Лёгкий блик сверху панели, как на стекле.
uniform float sheen : hint_range(0.0, 0.3) = 0.06;

void fragment() {
	// Несколько выборок вокруг точки — размытие мягче, без «ступенек» мип-карты.
	vec2 px = SCREEN_PIXEL_SIZE * 10.0;
	vec3 bg = textureLod(screen_tex, SCREEN_UV, blur).rgb * 0.4;
	bg += textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), blur).rgb * 0.15;
	bg += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), blur).rgb * 0.15;
	bg += textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), blur).rgb * 0.15;
	bg += textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), blur).rgb * 0.15;
	// Над тёмным (ночь) стекло само светлеет, иначе тёмный текст на нём не читается.
	float lum = dot(bg, vec3(0.299, 0.587, 0.114));
	float density = mix(tint.a + 0.42, tint.a, smoothstep(0.12, 0.55, lum));
	vec3 color = mix(bg, tint.rgb, density);
	color += sheen * (1.0 - UV.y);
	COLOR = vec4(color, COLOR.a);
}
