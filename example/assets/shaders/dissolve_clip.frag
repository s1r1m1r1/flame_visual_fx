#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform sampler2D uTexture;
uniform vec4 uWorldToUV[4];
uniform vec2 uSize;
uniform float uThreshold;
uniform float uType;
uniform float uNoiseWeight;
uniform float uTime;
uniform float uClipEdges;

out vec4 fragColor;

void main() {
    mat4 m = mat4(uWorldToUV[0], uWorldToUV[1], uWorldToUV[2], uWorldToUV[3]);
    vec4 localPos = m * vec4(FlutterFragCoord().xy, 0.0, 1.0);
    vec2 uv = localPos.xy;
    
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

    float alpha = shouldClip ? 1.0 : 0.0;

    // Sample the actual texture
    vec4 texColor = texture(uTexture, uv);

    // Prevent optimization
    float dummy = (uTime + uSize.x + uSize.y + uType + uNoiseWeight) * 0.0;
    fragColor = vec4(texColor.rgb, texColor.a * (1.0 - alpha) + dummy);
}
