#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniforms
layout(location = 0) uniform vec2 uSize;      // (width, height) - NOT USED directly yet
layout(location = 1) uniform vec4 uSrcRect;   // (x, y, w, h) in atlas
layout(location = 2) uniform vec2 uAtlasSize; // (atlasW, atlasH)
layout(location = 3) uniform vec2 uOffset;    // margin/offset in temporary canvas
layout(location = 4) uniform float uTime;     // time for animation
layout(location = 5) uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    // 1. Calculate local UV relative to the sprite bounds
    vec2 localPos = FlutterFragCoord().xy - uOffset;
    vec2 spriteUv = localPos / uSrcRect.zw;

    // Bounds check to avoid drawing outside the sprite (important for atlas baking)
    if (spriteUv.x < 0.0 || spriteUv.x > 1.0 || spriteUv.y < 0.0 || spriteUv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // 2. Map local UV back to global atlas coordinates
    // Clamp slightly to avoid sampling neighbor pixels due to precision
    vec2 sampledUv = clamp(spriteUv, vec2(0.001), vec2(0.999));
    vec2 atlasCoord = uSrcRect.xy + (sampledUv * uSrcRect.zw);
    vec2 globalUv = atlasCoord / uAtlasSize;

    // 3. Sample original color
    vec4 color = texture(uTexture, globalUv);

    if (color.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    // 4. Transform to Hologram Aethestic (Cyan/Blue)
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Cyan base
    vec3 hologramColor = vec3(0.0, 0.8, 1.0);
    
    // Add some scanlines (animated via uTime)
    // 6.28318 is 2 * PI, so uTime from 0 to 1 creates a perfect loop
    float scanline = sin(localPos.y * 1.5 + uTime * 6.28318) * 0.1 + 0.9;
    
    // Mix original details with hologram color
    vec3 finalRGB = mix(hologramColor, vec3(1.0), gray * 0.5) * scanline;
    
    // Semi-transparent alpha (standard ghostly look)
    float finalAlpha = color.a * 0.7;

    fragColor = vec4(finalRGB * finalAlpha, finalAlpha);
}
