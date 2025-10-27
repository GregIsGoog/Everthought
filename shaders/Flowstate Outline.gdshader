shader_type canvas_item;

uniform float outline_size = 8.0;
uniform vec4 outline_color : source_color = vec4(0.0, 1.0, 1.0, 1.0); // cyan outline

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    if (tex_color.a < 0.1) {
        vec2 size = outline_size / TEXTURE_PIXEL_SIZE;
        float alpha = 0.0;
        for (float x = -1.0; x <= 1.0; x++) {
            for (float y = -1.0; y <= 1.0; y++) {
                vec2 offset = vec2(x, y) * size;
                alpha = max(alpha, texture(TEXTURE, UV + offset * 0.5).a);
            }
        }
        COLOR = vec4(outline_color.rgb, alpha);
    } else {
        COLOR = tex_color;
    }
}