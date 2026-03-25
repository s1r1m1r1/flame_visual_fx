The Bottleneck has shifted from Texture Creation to Draw Calls & Engine Overhead.

Global Cache Win: Since both versions now share baked silhouettes via the cacheKey, the heavy cost of toImage() is only paid once per animation frame (4 frames total). After that, both versions are just drawing a single textured quad per bird.
GPU Backend parity: In Flutter (impeller/skia), canvas.drawImage is essentially drawing a quad with a simple tint shader. canvas.drawRect with our custom fragment shader is also drawing a quad, but with a slightly more complex sampling loop. At 1200 components, the overhead of the Flutter engine managing 1200 objects and submitting 1200 draw calls dominates the actual time spent on the GPU running the shader.
Fill-rate similarities:
The CPU version draws the pre-baked silhouette (one texture pass).
The Shader version runs our edge-detection shader (one pass, but with 12 texture samples). On modern GPUs, 12 samples is still extremely fast, so the "cost" per pixel is negligible compared to the overhead of the draw calls themselves.
Where the Shader version will eventually "Win":
The Shader version becomes superior in two scenarios:

Very Large Thickness: If you set thickness: 50, the CPU version has to draw the component 78 times during the bake phase (max(16, (50 * 2 * pi / 4))). The Shader version still only does one bake and one shader pass.
Dynamic Thickness/Color: If you want to animate the outline thickness smoothly (e.g., a "breathing" effect), the CPU version would have to re-bake every frame (destroying performance). The Shader version can potentially be updated to take thickness and color as uniforms without re-baking the original silhouette (if we bake the original once and pass it as a sampler).
Summary Table (at 1200 components)
Metric	CPU (Canvas)	GPU (Shader)
FPS	44	44
Bake Cost	16-32 draw calls -> toImage()	1 draw call -> toImage()
Render Cost	1 Bitmap Draw + Tint	1 Shader Pass (12 samples)
Scalability	Decreases with Thickness	Constant with Thickness
You have successfully optimized the shader version to be production-ready! It is now just as lightweight as the most optimized "Canvas" version but with the added flexibility of a GPU pipeline.