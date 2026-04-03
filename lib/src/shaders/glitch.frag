#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniforms
layout(location = 0) uniform vec2 uSize;      // (width, height)
layout(location = 1) uniform vec4 uSrcRect;   // (x, y, w, h) in atlas
layout(location = 2) uniform vec2 uAtlasSize; // (atlasW, atlasH)
layout(location = 3) uniform vec2 uOffset;    // margin/offset in temporary canvas
layout(location = 4) uniform float uTime;     // normalized time (0 to 1)
layout(location = 5) uniform sampler2D uTexture;

out vec4 fragColor;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float noise(float p) {
    float fl = floor(p);
    float fc = fract(p);
    return mix(hash(fl), hash(fl + 1.0), fc);
}

vec4 sampleAtlas(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4(0.0);
    }
    vec2 sampledUv = clamp(uv, vec2(0.001), vec2(0.999));
    vec2 atlasCoord = uSrcRect.xy + (sampledUv * uSrcRect.zw);
    vec2 globalUv = atlasCoord / uAtlasSize;
    return texture(uTexture, globalUv);
}

void main() {
    // 1. Calculate local UV relative to the sprite bounds
    vec2 localPos = FlutterFragCoord().xy - uOffset;
    vec2 spriteUv = localPos / uSrcRect.zw;

    // 2. Add Glitch Distortion (perfect loop via uTime)
    // 6.28318 is 2 * PI
    float timePhase = uTime * 6.28318;
    
    // Horizontal scanline jitter
    float jitter = (noise(spriteUv.y * 100.0 + timePhase * 10.0) - 0.5) * 0.02;
    
    // Large banded noise
    float jump = (hash(floor(uTime * 20.0)) > 0.8) ? (hash(floor(spriteUv.y * 5.0 + timePhase)) - 0.5) * 0.05 : 0.0;
    
    float xOffset = jitter + jump;
    
    // 3. RGB Split
    float rgbSplit = 0.01 + sin(timePhase) * 0.005;
    
    vec2 uvR = spriteUv + vec2(xOffset + rgbSplit, 0.0);
    vec2 uvG = spriteUv + vec2(xOffset, 0.0);
    vec2 uvB = spriteUv + vec2(xOffset - rgbSplit, 0.0);

    vec4 colR = sampleAtlas(uvR);
    vec4 colG = sampleAtlas(uvG);
    vec4 colB = sampleAtlas(uvB);

    // Combine channels
    // We use Green's alpha as the base visibility
    float finalAlpha = colG.a;
    vec3 finalRGB = vec3(colR.r, colG.g, colB.b);

    // Simple bounds check for the entire frag
    if (spriteUv.x < -0.1 || spriteUv.x > 1.1 || spriteUv.y < 0.0 || spriteUv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    fragColor = vec4(finalRGB * finalAlpha, finalAlpha);
}
