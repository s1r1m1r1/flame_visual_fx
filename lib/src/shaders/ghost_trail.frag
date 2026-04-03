#version 460 core
#include <flutter/runtime_effect.glsl>

// Uniforms
layout(location = 0) uniform vec2 uSize;      // (width, height)
layout(location = 1) uniform vec4 uSrcRect;   // (x, y, w, h) in atlas
layout(location = 2) uniform vec2 uAtlasSize; // (atlasW, atlasH)
layout(location = 3) uniform vec2 uOffset;    // margin/offset in temporary canvas
layout(location = 4) uniform float uTime;     // phase for jitter/flutter (0 to 1)
layout(location = 5) uniform vec2 uDirection; // normalized direction vector of trail
layout(location = 6) uniform float uStrength;  // overall length/strength of trail (0 to 0.5)
layout(location = 7) uniform vec4 uTrailColor; // rgb + tint intensity (alpha channel)
layout(location = 8) uniform sampler2D uTexture;

out vec4 fragColor;

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
    
    // Time Phase for perfect loop pulsation
    float timePhase = uTime * 6.28318;
    float jitter = sin(timePhase * 5.0) * 0.05 + 0.95; // Subtle flutter
    
    // 2. Sample multiple times in the OPPOSITE direction to create the trail
    vec4 ghostAccum = vec4(0.0);
    const int SAMPLES = 5;
    
    for (int i = 1; i <= SAMPLES; i++) {
        float f = float(i) / float(SAMPLES);
        // Back-offset along direction and strength
        vec2 uv = spriteUv - (uDirection * uStrength * f * jitter);
        
        vec4 sampled = sampleAtlas(uv);
        if (sampled.a > 0.05) {
            // Apply color tint (purple-ish by default)
            vec3 tinted = mix(sampled.rgb / sampled.a, uTrailColor.rgb, uTrailColor.a);
            float alpha = sampled.a * (1.0 - f) * 0.5; // Older ghosts are more transparent
            
            // Simple over-blend (front to back)
            ghostAccum += vec4(tinted * alpha, alpha) * (1.0 - ghostAccum.a);
        }
    }
    
    // 3. Output ONLY the ghost accumulation
    // This allows the decorator to be a pure overlay,
    // draw(canvas) will be called separately to draw the actual character.
    fragColor = ghostAccum;
}
