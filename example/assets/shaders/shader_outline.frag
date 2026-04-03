#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform vec4 uColor;
uniform float uThickness;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec4 color = texture(uTexture, uv);

    // If the pixel is already opaque, keep it (so we see the component on top of outline)
    if (color.a > 0.0) {
        fragColor = color;
        return;
    }

    // Sample neighboring pixels in a circular pattern to find the edge
    float maxAlpha = 0.0;
    const int SAMPLES = 12;
    for (int i = 0; i < SAMPLES; i++) {
        float angle = float(i) * 6.283185 / float(SAMPLES);
        vec2 offset = vec2(cos(angle), sin(angle)) * uThickness / uSize;
        maxAlpha = max(maxAlpha, texture(uTexture, uv + offset).a);
    }

    if (maxAlpha > 0.0) {
        // Outline pixel found
        fragColor = uColor;
    } else {
        // Transparent pixel
        fragColor = vec4(0.0);
    }
}
