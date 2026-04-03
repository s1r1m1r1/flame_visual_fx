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
uniform float uSliceCount;
uniform float uDirection;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    mat4 m = mat4(uWorldToUV[0], uWorldToUV[1], uWorldToUV[2], uWorldToUV[3]);
    vec4 localPos = m * vec4(FlutterFragCoord().xy, 0.0, 1.0);
    vec2 uv = localPos.xy;
    
    // Bounds check
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    bool isHorizontal = uDirection < 0.5;
    float coord = isHorizontal ? uv.y : uv.x;
    
    // 1. Slice quantization
    float sliceIndex = floor(coord * uSliceCount) / uSliceCount;
    
    // 2. Base pattern value (0..1)
    float patternValue = 0.0;
    
    // Simplifed logic to avoid immediate disappearance
    if (uType > 0.5 && uType < 1.5) { // TopDown
        patternValue = sliceIndex;
    } else if (uType > 1.5 && uType < 2.5) { // BottomUp
        patternValue = 1.0 - sliceIndex - (1.0 / uSliceCount); 
    } else if (uType > 2.5 && uType < 3.5) { // LeftRight
        patternValue = isHorizontal ? uv.x : sliceIndex;
    } else if (uType > 3.5 && uType < 4.5) { // RightLeft
        patternValue = isHorizontal ? 1.0 - uv.x : 1.0 - sliceIndex - (1.0 / uSliceCount);
    } else if (uType > 4.5 && uType < 5.5) { // Radial
        patternValue = distance(uv, vec2(0.5)) * 1.414;
    } else { // Random
        patternValue = rand(vec2(sliceIndex, 0.456));
    }

    // Add a tiny bit of jitter within the slice if noise is on
    float jitter = rand(uv) * 0.05 * uNoiseWeight;
    float val = patternValue + jitter;

    float alpha = smoothstep(uThreshold - 0.02, uThreshold + 0.02, val);
    
    // Sample texture
    vec4 texColor = texture(uTexture, uv);

    // Alpha 1.0 means ERASE in dstOut mode (legacy), but here we multiply directly.
    float dummy = (uTime + uSize.x + uSize.y) * 0.0;
    fragColor = vec4(texColor.rgb, texColor.a * (1.0 - alpha) + dummy);
}
