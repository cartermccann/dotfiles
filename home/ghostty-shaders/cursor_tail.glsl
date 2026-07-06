// cursor tail — kitty-style comet trail for ghostty (1.2+ cursor uniforms).
// A capped-length trail chases the cursor: the head arrives first, the tail
// reels in behind it. Vendored from
// https://github.com/sahaj-b/ghostty-cursor-shaders (MIT); trail tint follows
// iCurrentCursorColor so it tracks the azure caret. Alternate to
// cursor_warp.glsl — switch in ghostty.nix.

// sRGB -> Linear conversion (ghostty passes sRGB; the pipeline is linear)
vec3 sRGBToLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// --- CONFIGURATION ---
vec4 TRAIL_COLOR = vec4(sRGBToLinear(iCurrentCursorColor.rgb), 0.9);
const float DURATION = 0.11; // seconds
const float MAX_TRAIL_LENGTH = 0.2; // cap, in normalized units
const float THRESHOLD_MIN_DISTANCE = 1.5; // min travel to trail (cursor widths)
const float BLUR = 2.0; // antialias blur in pixels

// --- EASING (swap by commenting; one `ease` must be active) ---

// EaseOutCirc
float ease(float x) {
    return sqrt(1.0 - pow(x - 1.0, 2.0));
}

// // EaseOutExpo
// float ease(float x) {
//     return x == 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x);
// }

// // EaseOutQuint
// float ease(float x) {
//     return 1.0 - pow(1.0 - x, 5.0);
// }

float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// iq-style polygon SDF edge: accumulates squared distance + winding sign.
float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    float flip = mix(1.0, -1.0, step(0.5, allCond + noneCond));
    s *= flip;
    return d;
}

float getSdfParallelogram(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);

    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);

    return s * sqrt(d);
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialising(float distance) {
    return 1. - smoothstep(0., normalize(vec2(BLUR, BLUR), 0.).x, distance);
}

float determineIfTopRightIsLeading(vec2 a, vec2 b) {
    float condition1 = step(b.x, a.x) * step(a.y, b.y); // a.x < b.x && a.y > b.y
    float condition2 = step(a.x, b.x) * step(b.y, a.y); // a.x > b.x && a.y < b.y
    return 1.0 - max(condition1, condition2);
}

vec2 getRectangleCenter(vec4 rectangle) {
    return vec2(rectangle.x + (rectangle.z / 2.), rectangle.y - (rectangle.w / 2.));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord){
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    // normalization & setup (-1..1 coords)
    vec2 vu = normalize(fragCoord, 1.);
    vec2 offsetFactor = vec2(-.5, 0.5);

    vec4 currentCursor = vec4(normalize(iCurrentCursor.xy, 1.), normalize(iCurrentCursor.zw, 0.));
    vec4 previousCursor = vec4(normalize(iPreviousCursor.xy, 1.), normalize(iPreviousCursor.zw, 0.));

    vec2 centerCC = currentCursor.xy - (currentCursor.zw * offsetFactor);
    vec2 centerCP = previousCursor.xy - (previousCursor.zw * offsetFactor);

    vec2 delta = centerCP - centerCC;
    float lineLength = length(delta);

    float sdfCurrentCursor = getSdfRectangle(vu, centerCC, currentCursor.zw * 0.5);

    vec4 newColor = vec4(fragColor);

    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;
    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (lineLength > minDist) {
        // head leads, tail follows after a delay proportional to travel
        float tail_delay_factor = MAX_TRAIL_LENGTH / lineLength;
        float isLongMove = step(MAX_TRAIL_LENGTH, lineLength);

        float head_eased_short = ease(progress);
        float tail_eased_short = ease(smoothstep(tail_delay_factor, 1.0, progress));
        float head_eased_long = 1.0;
        float tail_eased_long = ease(progress);

        float head_eased = mix(head_eased_long, head_eased_short, isLongMove);
        float tail_eased = mix(tail_eased_long, tail_eased_short, isLongMove);

        // detect straight moves
        vec2 delta_abs = abs(centerCC - centerCP);
        float threshold = 0.001;
        float isHorizontal = step(delta_abs.y, threshold);
        float isVertical = step(delta_abs.x, threshold);
        float isStraightMove = max(isHorizontal, isVertical);

        // -- parallelogram SDF (diagonal move) --
        vec2 head_pos_tl = mix(previousCursor.xy, currentCursor.xy, head_eased);
        vec2 tail_pos_tl = mix(previousCursor.xy, currentCursor.xy, tail_eased);

        float isTopRightLeading = determineIfTopRightIsLeading(currentCursor.xy, previousCursor.xy);
        float isBottomLeftLeading = 1.0 - isTopRightLeading;

        vec2 v0 = vec2(head_pos_tl.x + currentCursor.z * isTopRightLeading, head_pos_tl.y - currentCursor.w);
        vec2 v1 = vec2(head_pos_tl.x + currentCursor.z * isBottomLeftLeading, head_pos_tl.y);
        vec2 v2 = vec2(tail_pos_tl.x + currentCursor.z * isBottomLeftLeading, tail_pos_tl.y);
        vec2 v3 = vec2(tail_pos_tl.x + currentCursor.z * isTopRightLeading, tail_pos_tl.y - previousCursor.w);

        float sdfTrail_diag = getSdfParallelogram(vu, v0, v1, v2, v3);

        // -- rectangle SDF (straight move) --
        vec2 head_center = mix(centerCP, centerCC, head_eased);
        vec2 tail_center = mix(centerCP, centerCC, tail_eased);

        vec2 min_center = min(head_center, tail_center);
        vec2 max_center = max(head_center, tail_center);

        vec2 box_size = (max_center - min_center) + currentCursor.zw;
        vec2 box_center = (min_center + max_center) * 0.5;

        float sdfTrail_rect = getSdfRectangle(vu, box_center, box_size * 0.5);

        // -- select and draw --
        float sdfTrail = mix(sdfTrail_diag, sdfTrail_rect, isStraightMove);

        vec4 trail = TRAIL_COLOR;
        float trailAlpha = antialising(sdfTrail);
        newColor = mix(newColor, trail, trailAlpha);

        // punch a hole where the live cursor sits so it stays crisp on top
        newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.));
    }

    fragColor = newColor;
}
