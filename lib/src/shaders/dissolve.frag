#version 460 core
#include <flutter/runtime_effect.glsl>

layout(location = 0) uniform vec2 uSize;      // Context size (width, height)
layout(location = 1) uniform float uProgress; // Dissolve progress (0.0 to 1.0)
layout(location = 2) uniform float uType;     // 0:Random, 1:Top-down, 2:Bottom-up, 3:Left-right, 4:Right-left, 5:Radial
layout(location = 3) uniform float uNoiseWeight; // 0.0 (Geometric only) to 1.0 (Noise only)
layout(location = 4) uniform float uPixelSize;  // Quantization scale (e.g. 1.0 or 2.0)
layout(location = 5) uniform vec4 uEdgeColor;   // Glowing burn color
layout(location = 6) uniform float uEdgeDepth;  // Burning edge thickness (0.0 to 0.1)
layout(location = 7) uniform sampler2D uTexture;
layout(location = 8) uniform vec4 uSrcRect;   // Rect of sprite in atlas [x, y, w, h]
layout(location = 9) uniform vec2 uAtlasSize; // [atlasW, atlasH]

out vec4 fragColor;

// --- UTILS ---
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    return fract(p.x * p.y * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void main() {
    // 1. Coordinate Quantization
    vec2 pixelPos = floor(FlutterFragCoord().xy / uPixelSize) * uPixelSize;
    // Normalized local UV relative to the sprite (0.0 to 1.0)
    vec2 uv = pixelPos / uSize;
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    // 2. Color Sampling
    vec2 atlasUV = (uSrcRect.xy + (uv * uSrcRect.zw)) / uAtlasSize;
    vec4 sprite = texture(uTexture, atlasUV);
    
    if (sprite.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }
    
    // 3. Dissolve Calculation
    float n = noise(pixelPos * 0.15); // Disintegration noise
    
    float geometry = 0.0;
    if (uType < 0.5) geometry = 0.0;                      // Random
    else if (uType < 1.5) geometry = uv.y;               // Top-down
    else if (uType < 2.5) geometry = 1.0 - uv.y;         // Bottom-up
    else if (uType < 3.5) geometry = uv.x;               // Left-right
    else if (uType < 4.5) geometry = 1.0 - uv.x;         // Right-left
    else geometry = distance(uv, vec2(0.5)) * 1.414;     // Radial
    
    // Threshold combines geometric direction with high-frequency noise
    float threshold = mix(geometry, n, uNoiseWeight);
    
    // 4. Burn Logic
    if (threshold < uProgress) {
        fragColor = vec4(0.0);
    } else if (threshold < uProgress + uEdgeDepth) {
        // Glowing burn edge
        float edgePos = (threshold - uProgress) / uEdgeDepth;
        vec4 edge = uEdgeColor * sprite.a;
        // Hotter at the very edge of dissolution
        edge.rgb *= (2.5 - edgePos * 1.5);
        fragColor = edge;
    } else {
        fragColor = sprite;
    }
}
