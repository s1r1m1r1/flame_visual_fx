#version 460 core
#include <flutter/runtime_effect.glsl>

layout(location = 0) uniform vec2 uSize;      // Context size (width, height)
layout(location = 1) uniform float uProgress; // Dissolve progress (0.0 to 1.0)
layout(location = 2) uniform float uType;     // 0:Random, 1:Top-down, 2:Bottom-up, 3:Left-right, 4:Right-left, 5:Radial
layout(location = 3) uniform float uNoiseWeight; // 0.0 (Geometric only) to 1.0 (Hash only)
layout(location = 4) uniform float uPixelSize;  // Quantization scale (e.g. 1.0 or 2.0)
layout(location = 5) uniform vec4 uEdgeColor;   // (Unused in pixel version, but kept for uniform compatibility)
layout(location = 6) uniform float uEdgeDepth;  // (Unused in pixel version, but kept for uniform compatibility)
layout(location = 7) uniform sampler2D uTexture;
layout(location = 8) uniform vec4 uSrcRect;   // Rect of sprite in atlas [x, y, w, h]
layout(location = 9) uniform vec2 uAtlasSize; // [atlasW, atlasH]

out vec4 fragColor;

// --- UTILS ---
// High-frequency pseudo-random hash for per-pixel disintegration
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    return fract(p.x * p.y * 43758.5453123);
}

void main() {
    // 1. Coordinate Quantization (Essential for Pixel Art consistency)
    vec2 pixelPos = floor(FlutterFragCoord().xy / uPixelSize) * uPixelSize;
    // Normalized local UV relative to the sprite bounds (0.0 to 1.0)
    vec2 uv = pixelPos / uSize;
    
    // Safety check for bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    // 2. Color Sampling from Atlas
    vec2 atlasUV = (uSrcRect.xy + (uv * uSrcRect.zw)) / uAtlasSize;
    vec4 sprite = texture(uTexture, atlasUV);
    
    // Alpha transparency discard
    if (sprite.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }
    
    // 3. Pixel-by-Pixel Crumbling Calculation
    float h = hash(pixelPos); // Discrete per-pixel random value
    
    // Geometric gradients for directional disintegration
    float geometry = 0.0;
    if (uType < 0.5) geometry = 0.0;                      // Pure Random (if NoiseWeight is 1.0)
    else if (uType < 1.5) geometry = uv.y;               // Top-down crumble
    else if (uType < 2.5) geometry = 1.0 - uv.y;         // Bottom-up crumble
    else if (uType < 3.5) geometry = uv.x;               // Left-right crumble
    else if (uType < 4.5) geometry = 1.0 - uv.x;         // Right-left crumble
    else geometry = distance(uv, vec2(0.5)) * 1.414;     // Radial crumble
    
    // Combine geometry (long-range) with hash (high-frequency)
    // For stone crumbling, we typically want a high NoiseWeight (0.7-1.0)
    float threshold = mix(geometry, h, uNoiseWeight);
    
    // 4. Binary Discard (No soft "burning paper" edge)
    if (threshold < uProgress) {
        fragColor = vec4(0.0);
    } else {
        fragColor = sprite;
    }
}
