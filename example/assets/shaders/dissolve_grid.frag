#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec4 uWorldToUV[4];
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
    mat4 m = mat4(uWorldToUV[0], uWorldToUV[1], uWorldToUV[2], uWorldToUV[3]);
    vec4 localPos = m * vec4(FlutterFragCoord().xy, 0.0, 1.0);
    vec2 uv = localPos.xy;
    
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
        // For random, we use the noise only, or a random base per cell
        patternValue = rand(gridUV + 0.123); 
    }

    // 3. Sample grid noise
    float noiseValue = rand(gridUV);
    
    // 4. Combine
    float edgeWeight = 1.0 - uNoiseWeight;
    float threshold = (patternValue * edgeWeight) + (noiseValue * uNoiseWeight);

    // Alpha 1.0 means we ERASE the destination (dstOut)
    float alpha = smoothstep(uThreshold - 0.02, uThreshold + 0.02, threshold);

    // Prevent optimization of uTime and uSize if they are not used in some paths
    float dummy = (uTime + uSize.x + uSize.y) * 0.0;
    fragColor = vec4(0.0, 0.0, 0.0, (1.0 - alpha) + dummy);
}
