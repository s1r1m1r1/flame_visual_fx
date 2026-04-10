// flame_vfx.glsl
// Standard utilities for Flame Visual FX shaders.

/// Calculates Atlas UV coordinates from screen coordinates (fragCoord).
/// [fragCoord] The result of FlutterFragCoord().xy
/// [screenToAtlasUV] A 4x4 matrix mapping screen pixels to atlas UV space.
///                  Passed from ShaderDissolveDecorator.
vec2 get_flame_atlas_uv(vec2 fragCoord, mat4 screenToAtlasUV) {
    vec4 uv = screenToAtlasUV * vec4(fragCoord, 0.0, 1.0);
    // Standard perspective divide (w is usually 1.0 for affine transforms)
    return uv.xy / uv.w;
}
