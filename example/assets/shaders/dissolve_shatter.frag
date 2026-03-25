#version 460 core
#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 uSize;
uniform float uThreshold;
uniform float uType;
uniform float uNoiseWeight;
uniform float uTime;
uniform float uGridSize;
uniform float uSmoothness;

out vec4 fragColor;

vec2 hash22(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// Simple Voronoi for shattering
vec3 voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);

    vec2 mg, mr;
    float md = 8.0;
    for(int j=-1; j<=1; j++)
    for(int i=-1; i<=1; i++) {
        vec2 g = vec2(float(i), float(j));
        vec2 o = hash22(n + g);
        vec2 r = g + o - f;
        float d = dot(r, r);

        if(d < md) {
            md = d;
            mr = r;
            mg = g;
        }
    }

    return vec3(md, mr);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Voronoi coords
    vec2 p = uv * uGridSize;
    vec3 v = voronoi(p);
    
    vec2 n = floor(p);
    vec2 centerPos = n + v.yz + fract(p); 
    vec2 centerUV = centerPos / uGridSize;

    float noise = hash22(centerUV * 1337.0).x;
    
    // Pattern logic
    float patternValue = 0.0;
    if (uType > 0.5 && uType < 1.5) patternValue = centerUV.y;           // TopDown
    else if (uType > 1.5 && uType < 2.5) patternValue = 1.0 - centerUV.y; // BottomUp
    else if (uType > 2.5 && uType < 3.5) patternValue = centerUV.x;      // LeftRight
    else if (uType > 3.5 && uType < 4.5) patternValue = 1.0 - centerUV.x; // RightLeft
    else if (uType > 4.5 && uType < 5.5) patternValue = distance(centerUV, vec2(0.5)) * 1.414; // Radial
    else patternValue = hash22(centerUV + 0.5).x; // random

    float thresholdValue = (patternValue * (1.0 - uNoiseWeight)) + (noise * uNoiseWeight);
    
    float alpha = smoothstep(uThreshold - 0.02, uThreshold + 0.02, thresholdValue);
    
    // Alpha 1.0 means ERASE in dstOut mode
    float dummy = (uTime + uSize.x + uSize.y + uSmoothness) * 0.0;
    fragColor = vec4(0.0, 0.0, 0.0, alpha + dummy);
}
