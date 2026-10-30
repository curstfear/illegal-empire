shader_type spatial;
// Чистые сочные цвета моделей, как в референсе (desaturate < 0 — чуть ярче оригинала).
// tint — перекраска (синий для твоих зданий): светлые части остаются светлыми, цветные берут оттенок.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Сколько цвета убрать (0 — как есть, 1 — серое) и насколько поднять к белому.
uniform float desaturate = -0.12;
uniform float lift = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_amount = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(gray), desaturate);
	c = mix(c, vec3(1.0), lift);
	// Перекраска: тёмные и цветные места окрашиваются в tint, белые стены почти не трогаем.
	vec3 tinted = mix(tint.rgb * (0.55 + 0.6 * gray), c, smoothstep(0.82, 0.97, gray));
	ALBEDO = mix(c, tinted, tint_amount);
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
}
