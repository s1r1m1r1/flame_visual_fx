#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uThreshold;
uniform float uType;
uniform float uNoiseWeight;
uniform float uTime;
uniform float uGridSize;

out vec4 fragColor;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    // FragCoord is local in saveLayer context
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // 1. Quantize UV for grid effect
    vec2 gridUV = floor(uv * uGridSize) / uGridSize;
    float nx = gridUV.x;
    float ny = gridUV.y;

    // 2. Pattern selection
    float patternValue = 0.0;
    if (uType > 0.5 && uType < 1.5) { // topDown
        patternValue = ny;
    } else if (uType > 1.5 && uType < 2.5) { // bottomUp
        patternValue = 1.0 - ny;
    } else if (uType > 2.5 && uType < 3.5) { // leftRight
        patternValue = nx;
    } else if (uType > 3.5 && uType < 4.5) { // rightLeft
        patternValue = 1.0 - nx;
    } else if (uType > 4.5 && uType < 5.5) { // radial
        patternValue = distance(gridUV, vec2(0.5)) * 1.414;
    } else { // random (index 0) or fallback
        patternValue = rand(gridUV + 0.123); 
    }

    // 3. Sample grid noise
    float noiseValue = rand(gridUV);
    
    // 4. Combine
    float edgeWeight = 1.0 - uNoiseWeight;
    float threshold = (patternValue * edgeWeight) + (noiseValue * uNoiseWeight);

    float alpha = smoothstep(uThreshold - 0.02, uThreshold + 0.02, threshold);

    // For dstOut blending: Alpha 1.0 means ERASE, 0.0 means keep.
    // Prevent optimization of uTime
    float dummy = uTime * 0.0;
    fragColor = vec4(0.0, 0.0, 0.0, alpha + dummy);
}
