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
uniform float uWaveAmplitude;
uniform float uWaveFrequency;

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

    float nx = uv.x;
    float ny = uv.y;
    float phase = uTime * 6.28318;
    
    // 1. Wave offset
    float waveOffset = 0.0;
    if (uType < 2.5) { // Vertical patterns (random, topDown, bottomUp)
        waveOffset = sin(nx * uWaveFrequency * 6.28318 + phase) * (uWaveAmplitude / uSize.y);
    } else if (uType < 4.5) { // Horizontal patterns
        waveOffset = sin(ny * uWaveFrequency * 6.28318 + phase) * (uWaveAmplitude / uSize.x);
    } else { // Radial
        float angle = atan(ny - 0.5, nx - 0.5);
        waveOffset = sin(angle * uWaveFrequency + phase) * (uWaveAmplitude / length(uSize));
    }

    // 2. Pattern value
    float patternValue = 0.0;
    if (uType > 0.5 && uType < 1.5) { // topDown
        patternValue = ny + waveOffset;
    } else if (uType > 1.5 && uType < 2.5) { // bottomUp
        patternValue = (1.0 - ny) + waveOffset;
    } else if (uType > 2.5 && uType < 3.5) { // leftRight
        patternValue = nx + waveOffset;
    } else if (uType > 3.5 && uType < 4.5) { // rightLeft
        patternValue = (1.0 - nx) + waveOffset;
    } else if (uType > 4.5 && uType < 5.5) { // radial
        patternValue = distance(uv, vec2(0.5)) * 1.414 + waveOffset;
    } else { // random
        patternValue = rand(uv * 0.1) + waveOffset;
    }

    // 3. Jitter (noise)
    float jitter = (rand(uv + uTime * 0.01) - 0.5) * 2.0 * (uWaveAmplitude / length(uSize)) * uNoiseWeight;
    float threshold = patternValue + jitter;

    float alpha = smoothstep(uThreshold - 0.02, uThreshold + 0.02, threshold);
    
    // Sample texture
    vec4 texColor = texture(uTexture, uv);

    // Alpha 1.0 means ERASE
    float dummy = (uTime + uSize.x + uSize.y) * 0.0;
    fragColor = vec4(texColor.rgb, texColor.a * (1.0 - alpha) + dummy);
}
