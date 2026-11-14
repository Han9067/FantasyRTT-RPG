shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float edge = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			edge = max(edge, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
		}
	}
	// Only transparent pixels outside the current frame's silhouette turn white.
	COLOR = original.a > 0.01 ? original : vec4(1.0, 1.0, 1.0, step(0.01, edge));
}
