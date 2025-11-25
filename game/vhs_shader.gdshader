shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : source_color, filter_nearest;

// --- Grain / static controls ---
uniform float grain_strength    : hint_range(0.0,0.5) = 0.12;
uniform float grain_scale       : hint_range(0.1,8.0) = 2.0;
uniform float static_speed      : hint_range(0.0,3.0) = 0.6;
uniform float noise_intensity   : hint_range(0.0,0.5) = 0.05;

// --- VHS-style lines / glitches ---
uniform float vhs_line_strength : hint_range(0.0,0.4) = 0.08;
uniform float vhs_line_density  : hint_range(20.0,800.0) = 250.0;
uniform float vhs_line_speed    : hint_range(0.0,3.0) = 1.0;

// --- Color / vintage look ---
uniform float desaturate_amount  : hint_range(0.0,1.0) = 0.12;
uniform float color_shift_amount : hint_range(0.0,0.2) = 0.02;

// --- Chromatic aberration ---
uniform float chroma_shift : hint_range(0.0,0.01) = 0.0015;

// --- Vertical jitter (tape wobble) ---
uniform float jitter_strength : hint_range(0.0,0.03) = 0.004;
uniform float jitter_speed    : hint_range(0.0,3.0) = 0.8;

// --- RGB red / glow ---
uniform float red_strength : hint_range(0.0,0.06) = 0.015;
uniform float red_decay    : hint_range(0.0,1.0) = 0.6;

// --- Ghosting / duplicate faint layer ---
uniform float ghost_offset   : hint_range(0.0,0.05) = 0.01;
uniform float ghost_intensity: hint_range(0.0,1.0) = 0.25;

// --- Optional overall intensity / mix ---
uniform float effect_mix     : hint_range(0.0,1.0) = 1.0; // 0 = original, 1 = full effect

void fragment() {
    vec2 uv = SCREEN_UV;

    // apply vertical jitter/wobble
    float wobble = sin(TIME * jitter_speed + uv.y * 20.0) * jitter_strength;
    uv.y += wobble;

    // chromatic sample offsets
    vec2 chroma_uv_r = uv + vec2(chroma_shift, 0.0);
    vec2 chroma_uv_b = uv - vec2(chroma_shift, 0.0);

    // grain / static
    float grain = 0.0;
    if (textureSize(noise_tex, 0).x > 0) {
        vec2 gUV = uv * grain_scale + vec2(TIME * static_speed, TIME * static_speed * 0.7);
        grain = texture(noise_tex, gUV).r * 2.0 - 1.0;
    } else {
        grain = fract(sin(dot(uv * grain_scale + TIME * static_speed, vec2(12.9898,78.233))) * 43758.5453) * 2.0 - 1.0;
    }
    grain *= grain_strength;

    // extra procedural noise (kept as slider noise_intensity)
    float extra_noise = (fract(sin(dot(uv * 50.0 + TIME*5.0, vec2(93.9898,67.345))) * 43758.5453)*2.0-1.0) * noise_intensity;

    // horizontal scanline / line effect
    float line = sin((uv.y * vhs_line_density) + TIME * vhs_line_speed);
    float line_effect = line * vhs_line_strength;

    // main color read with chromatic aberration
    vec3 base;
    base.r = texture(SCREEN_TEXTURE, chroma_uv_r).r;
    base.g = texture(SCREEN_TEXTURE, uv).g;
    base.b = texture(SCREEN_TEXTURE, chroma_uv_b).b;

    // RGB red (shifted glow/trail to right)
    vec3 red = texture(SCREEN_TEXTURE, uv + vec2(red_strength, 0.0)).rgb;
    // tint red to give VHS-y smear (you can tweak the multipliers)
    red = red * vec3(1.0, 0.45, 0.65) * red_decay;

    // ghosting: faint blurred duplicate shifted horizontally (simulates tape ghost)
    vec3 ghost = texture(SCREEN_TEXTURE, uv + vec2(ghost_offset, 0.0)).rgb * ghost_intensity;

    // combine effects
    vec3 effected = base + red + ghost;
    effected += grain + extra_noise + line_effect;

    // desaturate / vintage toning
    float gray = dot(effected, vec3(0.299,0.587,0.114));
    effected = mix(effected, vec3(gray), desaturate_amount);

    // subtle color tint/shifts
    effected.r += color_shift_amount * 0.8;
    effected.g += color_shift_amount * -0.15;
    effected.b += color_shift_amount * 0.25;

    // mix with original based on effect_mix
    vec3 original = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    vec3 outCol = mix(original, clamp(effected, 0.0, 1.0), effect_mix);

    COLOR = vec4(outCol, 1.0);
}