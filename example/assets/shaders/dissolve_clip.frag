#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uThreshold;
uniform float uType;
uniform float uNoiseWeight;
uniform float uTime;
uniform float uClipEdges;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Use float math instead of & for compatibility
    float edges = uClipEdges + 0.1;
    bool clipTop = mod(floor(edges), 2.0) == 1.0;
    bool clipBottom = mod(floor(edges / 2.0), 2.0) == 1.0;
    bool clipLeft = mod(floor(edges / 4.0), 2.0) == 1.0;
    bool clipRight = mod(floor(edges / 8.0), 2.0) == 1.0;

    float hSpeed = (clipTop && clipBottom) ? 0.5 : 1.0;
    float vSpeed = (clipLeft && clipRight) ? 0.5 : 1.0;

    float hEdge = uThreshold * hSpeed;
    float vEdge = uThreshold * vSpeed;

    bool shouldClip = false;
    if (clipTop && uv.y < hEdge) shouldClip = true;
    if (clipBottom && uv.y > (1.0 - hEdge)) shouldClip = true;
    if (clipLeft && uv.x < vEdge) shouldClip = true;
    if (clipRight && uv.x > (1.0 - vEdge)) shouldClip = true;

    if (shouldClip) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0); // Full erasure (Alpha 1.0 in masking mode)
    } else {
        fragColor = vec4(0.0); // Keep (Alpha 0.0)
    }

    // Prevent optimization
    float dummy = (uTime + uSize.x + uSize.y + uType + uNoiseWeight) * 0.0;
    fragColor.rgb += dummy;
}
