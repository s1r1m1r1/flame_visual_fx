#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniforms
layout(location = 0) uniform vec2 uSize;      // (width, height)
layout(location = 1) uniform vec4 uSrcRect;   // (x, y, w, h) in atlas
layout(location = 2) uniform vec2 uAtlasSize; // (atlasW, atlasH)
layout(location = 3) uniform vec2 uOffset;    // margin/offset
layout(location = 4) uniform float uTime;     // phase for glitch sync
layout(location = 5) uniform float uThickness; // outline thickness in pixels
layout(location = 6) uniform vec4 uOutlineColor; // outline color
layout(location = 7) uniform float uUseGlitch; // 1.0 to enable glitch displacement sync
layout(location = 8) uniform sampler2D uTexture;

out vec4 fragColor;

// Noise helpers (synced with glitch.frag)
float hash(float n) { return fract(sin(n) * 43758.5453123); }
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
    vec2 localPos = FlutterFragCoord().xy - uOffset;
    vec2 spriteUv = localPos / uSrcRect.zw;
    
    // 1. Optional Glitch Displacement Sync
    float xOffset = 0.0;
    if (uUseGlitch > 0.5) {
        float timePhase = uTime * 6.28318;
        float jitter = (noise(spriteUv.y * 100.0 + timePhase * 10.0) - 0.5) * 0.02;
        float jump = (hash(floor(uTime * 20.0)) > 0.8) ? (hash(floor(spriteUv.y * 5.0 + timePhase)) - 0.5) * 0.05 : 0.0;
        xOffset = jitter + jump;
    }
    
    vec2 targetUv = spriteUv + vec2(xOffset, 0.0);
    vec4 center = sampleAtlas(targetUv);
    
    // If the center pixel is already opaque, don't draw the outline here.
    // The main sprite will be drawn on top of this outline.
    if (center.a > 0.5) {
        fragColor = vec4(0.0);
        return;
    }
    
    // 2. Check 4 Neighbors
    // We use a small texel offset based on uThickness
    vec2 texelSize = vec2(uThickness) / uSrcRect.zw;
    
    float a = 0.0;
    a = max(a, sampleAtlas(targetUv + vec2(texelSize.x, 0.0)).a);
    a = max(a, sampleAtlas(targetUv - vec2(texelSize.x, 0.0)).a);
    a = max(a, sampleAtlas(targetUv + vec2(0.0, texelSize.y)).a);
    a = max(a, sampleAtlas(targetUv - vec2(0.0, texelSize.y)).a);
    
    // If any neighbor is opaque, this is an outline pixel
    if (a > 0.1) {
        fragColor = uOutlineColor;
    } else {
        // Also check diagonals for smoother outline
        float d = 0.0;
        vec2 diag = texelSize * 0.7071;
        d = max(d, sampleAtlas(targetUv + diag).a);
        d = max(d, sampleAtlas(targetUv - diag).a);
        d = max(d, sampleAtlas(targetUv + vec2(diag.x, -diag.y)).a);
        d = max(d, sampleAtlas(targetUv + vec2(-diag.x, diag.y)).a);
        
        if (d > 0.1) {
            fragColor = uOutlineColor;
        } else {
            fragColor = vec4(0.0);
        }
    }
}
