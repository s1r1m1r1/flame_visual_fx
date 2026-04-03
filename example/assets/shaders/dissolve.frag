#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture;
uniform vec4 uWorldToUV[4];
uniform vec2 uSize;
uniform float uThreshold;
uniform float uType;
uniform float uNoiseWeight;
uniform float uTime;

out vec4 fragColor;

// High-performance 2D pseudo-random hash
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2D Noise for smoother look (bilinear interpolation of 4 random points)
float noise_2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void main() {
    mat4 m = mat4(uWorldToUV[0], uWorldToUV[1], uWorldToUV[2], uWorldToUV[3]);
    vec4 localPos = m * vec4(FlutterFragCoord().xy, 0.0, 1.0);
    vec2 uv = localPos.xy;
    
    // Bounds check to avoid wrapping or bleeding
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // 1. Calculate pattern value based on uType
    float patternValue = 0.0;
    
    // DissolveType: random(0), topDown(1), bottomUp(2), leftRight(3), rightLeft(4), radial(5)
    if (uType > 0.5 && uType < 1.5) { // topDown
        patternValue = uv.y;
    } else if (uType > 1.5 && uType < 2.5) { // bottomUp
        patternValue = 1.0 - uv.y;
    } else if (uType > 2.5 && uType < 3.5) { // leftRight
        patternValue = uv.x;
    } else if (uType > 3.5 && uType < 4.5) { // rightLeft
        patternValue = 1.0 - uv.x;
    } else if (uType > 4.5 && uType < 5.5) { // radial
        patternValue = length(uv - 0.5) * 1.414;
    } else { // random or fallback
        patternValue = 0.0;
    }
    
    // 2. Sample noise
    float noiseValue = noise_2(uv * 20.0);
    
    // 3. Combine pattern and noise following CPU logic
    float edgeWeight = 1.0 - uNoiseWeight;
    float threshold = (patternValue * edgeWeight) + (noiseValue * uNoiseWeight);
    
    // 4. Thresholding
    float alpha = smoothstep(uThreshold - 0.01, uThreshold + 0.01, threshold);

    // Sample the actual texture
    vec4 texColor = texture(uTexture, uv);

    // Prevent optimization of uSize
    float dummy = (uSize.x + uSize.y + uTime) * 0.0;
    fragColor = vec4(texColor.rgb, texColor.a * (1.0 - alpha) + dummy);
}
