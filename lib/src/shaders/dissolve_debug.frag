#version 460 core
#include <flutter/runtime_effect.glsl>

layout(location = 0) uniform vec4 uScreenToUV[4]; // Matrix mapping Screen -> AtlasUV
layout(location = 4) uniform vec2 uSize;         // Local size of the component
layout(location = 5) uniform float uProgress;    // Dissolve progress (0.0 to 1.0)
layout(location = 6) uniform float uType;        // Pattern type index
layout(location = 7) uniform float uNoiseWeight; // Weight of noise vs geometry
layout(location = 8) uniform float uTime;        // Animation time
layout(location = 9) uniform sampler2D uTexture;

out vec4 fragColor;

// --- UTILS ---
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    return fract(p.x * p.y * 43758.5453123);
}

void main() {
    // 1. Calculate Atlas UV using the standard mapping
    mat4 m = mat4(uScreenToUV[0], uScreenToUV[1], uScreenToUV[2], uScreenToUV[3]);
    vec4 atlasPos = m * vec4(FlutterFragCoord().xy, 0.0, 1.0);
    vec2 uv = atlasPos.xy / atlasPos.w;
    
    // Safety check for sprite bounds
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // 2. Sample texture
    vec4 sprite = texture(uTexture, uv);
    if (sprite.a < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    // 3. Local pattern UV (already calculated by mapping if we were precise, 
    // but we can also use atlasPos relative to local logic if needed. 
    // Actually, our mapping already gives us [0..1] range relative to the sprite).
    vec2 localUV = uv; // Result of matrix mapping Screen -> Atlas [0..1] relative to sprite

    // 4. Dissolve Calculation
    float n = hash(uv * 100.0 + uTime * 0.1); // Dynamic noise
    
    float geometry = 0.0;
    if (uType < 0.5) geometry = 0.0;                      
    else if (uType < 1.5) geometry = localUV.y;               
    else if (uType < 2.5) geometry = 1.0 - localUV.y;         
    else if (uType < 3.5) geometry = localUV.x;               
    else if (uType < 4.5) geometry = 1.0 - localUV.x;         
    else geometry = distance(localUV, vec2(0.5)) * 1.414;     

    float threshold = mix(geometry, n, uNoiseWeight);
    
    if (threshold < uProgress) {
        fragColor = vec4(0.0);
    } else {
        fragColor = sprite;
    }
}
