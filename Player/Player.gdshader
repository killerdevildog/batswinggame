shader_type canvas_item;

// Overall strength of the hit flash (0–1)
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// Color of the vignette (usually red)
uniform vec3 color : source_color = vec3(1.0, 0.0, 0.0);

// How soft or sharp the edge fade is
uniform float softness : hint_range(0.1, 2.0) = 1.0;

// Radius of the clear center (0 = full red, 1 = mostly clear center)
uniform float radius : hint_range(0.0, 1.0) = 0.7;


void fragment() {
    // UV goes from (0,0) bottom-left to (1,1) top-right.
    // Convert to −1..1 range so the center is at 0,0.
    vec2 uv = UV * 2.0 - 1.0;

    // Distance from center (circular gradient)
    float dist = length(uv);

    // Vignette fade edge using smoothstep for soft falloff
    float vignette = smoothstep(
        radius, 
        radius + softness * 0.3,
        dist
    );

    // Final overlay color: RGB + alpha driven by vignette * intensity
    COLOR = vec4(color, vignette * intensity);
}
