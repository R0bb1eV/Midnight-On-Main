shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_tex : source_color, filter_nearest;

// --- Grain / static controls ---
uniform float grain_strength    : hint_range(0.0,0.5) = 0.12;
uniform float grain_scale       : hint_range(0.1,8.0) = 2.0;
uniform float static_speed      : hint_range(0.0,3.0) = 0.6;
uniform float noise_intensity   : hint_range(0.0,0.5) = 0.05;

// --- VHS horizontal lines ---
uniform float vhs_line_strength : hint_range(0.0,0.4) = 0.08;
uniform float vhs_line_density  : hint_range(20.0,800.0) = 250.0;
uniform float vhs_line_speed    : hint_range(0.0,3.0) = 1.0;
uniform float scanline_variation: hint_range(0.0,0.1) = 0.02;
uniform float scanline_shimmer_intensity : hint_range(0.0,0.05) = 0.01;

// --- Color / vintage look ---
uniform float desaturate_amount  : hint_range(0.0,1.0) = 0.12;
uniform float color_shift_amount : hint_range(0.0,0.2) = 0.02;
uniform float color_quantization_amount : hint_range(0.0,0.1) = 0.0;

// --- Chromatic aberration ---
uniform float chroma_shift : hint_range(0.0,0.01) = 0.0015;
uniform float chroma_vertical_shift : hint_range(0.0,0.005) = 0.001;
uniform float chroma_flicker_amount : hint_range(0.0,0.02) = 0.005;
uniform float chroma_flicker_speed : hint_range(0.0,10.0) = 5.0;

// --- Vertical jitter / tape wobble ---
uniform float jitter_strength : hint_range(0.0,0.03) = 0.004;
uniform float jitter_speed    : hint_range(0.0,3.0) = 0.8;

// --- RGB red / glow ---
uniform float red_strength : hint_range(0.0,0.06) = 0.015;
uniform float red_decay    : hint_range(0.0,1.0) = 0.6;

// --- Ghosting / duplicate faint layer ---
uniform float ghost_offset   : hint_range(0.0,0.05) = 0.01;
uniform float ghost_intensity: hint_range(0.0,1.0) = 0.25;

// --- Scratches / dust overlay ---
uniform float scratch_strength : hint_range(0.0,0.2) = 0.05;
uniform float scratch_speed    : hint_range(0.0,3.0) = 0.5;
uniform float dust_intensity   : hint_range(0.0,0.2) = 0.03;
uniform float dust_speed       : hint_range(0.0,3.0) = 0.2;
uniform float dust_size        : hint_range(1.0,5.0) = 3.0;
uniform float streak_intensity : hint_range(0.0,0.1) = 0.03;
uniform float streak_speed     : hint_range(0.0,3.0) = 0.1;

// --- Flicker / brightness modulation ---
uniform float flicker_strength : hint_range(0.0,0.1) = 0.02;
uniform float flicker_speed    : hint_range(0.0,5.0) = 1.0;

// --- Vignette ---
uniform float vignette_strength : hint_range(0.0,0.2) = 0.05;
uniform float vignette_tint_amount : hint_range(0.0,0.05) = 0.02;

// --- Glitch / tape jump ---
uniform float glitch_chance    : hint_range(0.0,0.5) = 0.05;
uniform float glitch_intensity : hint_range(0.0,0.1) = 0.02;
uniform float glitch_speed     : hint_range(0.0,5.0) = 2.0;

// --- Frame jitter / shake ---
uniform float frame_jitter_intensity : hint_range(0.0,0.02) = 0.005;

// --- Color bleed / smearing ---
uniform float bleed_strength : hint_range(0.0,0.05) = 0.01;

// --- Barrel distortion ---
uniform float barrel_amount : hint_range(0.0,0.05) = 0.01;

// --- Temporal / rolling artifacts ---
uniform float roll_intensity : hint_range(0.0,0.05) = 0.0;
uniform float roll_speed     : hint_range(0.0,5.0) = 0.0;

// --- Flare / bloom ---
uniform float flare_intensity : hint_range(0.0,0.05) = 0.01;
uniform float flare_size      : hint_range(0.0,0.2) = 0.05;

// --- Horizontal blur ---
uniform float hblur_amount : hint_range(0.0,0.02) = 0.005;

// --- RGB roll ---
uniform float rgb_roll_intensity : hint_range(0.0,0.02) = 0.005;
uniform float rgb_roll_speed     : hint_range(0.0,5.0) = 1.0;

// --- Noir / black-and-white mode ---
uniform bool noir_mode = false;
uniform float noir_contrast : hint_range(0.5, 2.0) = 1.2;

// --- Optional overall intensity / mix ---
uniform float effect_mix     : hint_range(0.0,1.0) = 1.0;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 orig_uv = uv;

    // ---- barrel distortion ----
    vec2 center = vec2(0.5);
    vec2 to_center = uv - center;
    uv = center + to_center * (1.0 + barrel_amount * dot(to_center,to_center));

    // ---- vertical jitter / tape wobble ----
    uv.y += sin(TIME * jitter_speed + uv.y * 20.0) * jitter_strength;

    // ---- frame jitter ----
    uv += vec2(rand(vec2(TIME*5.0, uv.y)) - 0.5, rand(vec2(uv.x, TIME*5.0)) - 0.5) * frame_jitter_intensity;

    // ---- glitch / tape jumps ----
    float glitch = step(1.0 - glitch_chance, rand(vec2(uv.y * 100.0, TIME * glitch_speed)));
    float glitch_offset = glitch * glitch_intensity;
    uv.x += glitch_offset;

    // ---- temporal rolling artifacts ----
    uv.y += sin(TIME*roll_speed + uv.x*10.0)*roll_intensity;

    // ---- chromatic aberration + RGB roll ----
    float chroma_flicker = sin(TIME * chroma_flicker_speed) * chroma_flicker_amount;
    float rgb_roll = sin(TIME*rgb_roll_speed)*rgb_roll_intensity;
    vec2 chroma_uv_r = uv + vec2(chroma_shift + glitch_offset + chroma_flicker + rgb_roll, chroma_vertical_shift*sin(TIME*0.5));
    vec2 chroma_uv_b = uv - vec2(chroma_shift + glitch_offset + chroma_flicker + rgb_roll, chroma_vertical_shift*sin(TIME*0.5));

    // ---- grain / static ----
    float grain = 0.0;
    if (textureSize(noise_tex,0).x>0){
        vec2 gUV = uv * grain_scale + vec2(TIME * static_speed, TIME * static_speed * 0.7);
        grain = texture(noise_tex, gUV).r * 2.0 -1.0;
    } else {
        grain = rand(uv*grain_scale + vec2(TIME*static_speed, TIME*static_speed*0.3))*2.0-1.0;
    }
    grain *= grain_strength;
    float extra_noise = (rand(uv*50.0 + vec2(TIME*5.0, TIME*3.0))*2.0-1.0) * noise_intensity;

    // ---- VHS horizontal lines + shimmer ----
    float line = sin((uv.y*vhs_line_density) + TIME*vhs_line_speed);
    float line_effect = line * vhs_line_strength * (1.0 + rand(vec2(uv.y*100.0, TIME*2.0))*scanline_variation);
    line_effect += rand(vec2(TIME*10.0,uv.y*100.0))*scanline_shimmer_intensity;

    // ---- main color read with chromatic aberration ----
    vec3 base;
    base.r = texture(SCREEN_TEXTURE, chroma_uv_r).r;
    base.g = texture(SCREEN_TEXTURE, uv).g;
    base.b = texture(SCREEN_TEXTURE, chroma_uv_b).b;

    // ---- RGB red / glow ----
    vec3 red = texture(SCREEN_TEXTURE, uv + vec2(red_strength,0.0)).rgb * vec3(1.0,0.45,0.65) * red_decay;

    // ---- ghosting ----
    vec3 ghost = texture(SCREEN_TEXTURE, uv + vec2(ghost_offset,0.0)).rgb * ghost_intensity;

    // ---- scratches / dust / streaks ----
    float scratch = (texture(noise_tex, uv*40.0 + vec2(0.0, TIME*scratch_speed)).r*2.0-1.0) * scratch_strength;
    float dust = (texture(noise_tex, uv*dust_size + vec2(TIME*dust_speed, TIME*dust_speed*0.5)).r*2.0-1.0) * dust_intensity;
    float streak = (texture(noise_tex, uv*dust_size + vec2(TIME*streak_speed, TIME*streak_speed*0.3)).r*2.0-1.0) * streak_intensity;

    // ---- color bleed / smearing ----
    vec3 bleed = texture(SCREEN_TEXTURE, uv + vec2(bleed_strength,0.0)).rgb * bleed_strength;

    // ---- combine effects ----
    vec3 effected = base + red + ghost + grain + extra_noise + line_effect + scratch + dust + streak + bleed;

    // ---- flicker / brightness modulation ----
    effected *= 1.0 + sin(TIME*flicker_speed + uv.y*10.0) * flicker_strength;

    // ---- desaturate / vintage toning ----
    float gray = dot(effected, vec3(0.299,0.587,0.114));
    effected = mix(effected, vec3(gray), desaturate_amount);

    // ---- subtle color tint/shifts ----
    effected.r += color_shift_amount * 0.8;
    effected.g += color_shift_amount * -0.15;
    effected.b += color_shift_amount * 0.25;

    // ---- vignette / corner tint ----
    float dist = distance(orig_uv, vec2(0.5));
    effected *= 1.0 - dist*vignette_strength;
    effected += vec3(0.02, -0.01, 0.03) * vignette_tint_amount * dist;

    // ---- flare / bloom (simple additive) ----
    effected += vec3(flare_intensity) * smoothstep(0.0, 1.0, 1.0-dist) * flare_size;

    // ---- horizontal blur (3-sample simple) ----
    vec3 hblur = (texture(SCREEN_TEXTURE, uv + vec2(hblur_amount,0.0)).rgb +
                  texture(SCREEN_TEXTURE, uv - vec2(hblur_amount,0.0)).rgb +
                  effected) / 3.0;
    effected = mix(effected, hblur, hblur_amount*10.0);

    // ---- color quantization / bit-depth reduction ----
    if (color_quantization_amount > 0.0) {
        float steps = 1.0 / color_quantization_amount;
        effected = floor(effected * steps) / steps;
    }

    // ---- noir / black-and-white mode ----
    if (noir_mode) {
        float luma = dot(effected, vec3(0.299,0.587,0.114));
        luma = pow(luma, 1.0/noir_contrast);
        effected = vec3(luma);
    }

    // ---- mix with original based on effect_mix ----
    vec3 original = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    vec3 outCol = mix(original, clamp(effected,0.0,1.0), effect_mix);

    COLOR = vec4(outCol,1.0);
}