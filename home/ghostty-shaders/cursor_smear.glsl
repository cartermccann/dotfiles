// cursor smear — smooth cursor motion for ghostty (1.2+ cursor uniforms).
// When the cursor jumps, a parallelogram "smear" is drawn between the previous
// and current cursor quads and eased away over DURATION. Trail tint comes from
// iCurrentCursorColor, so it follows the azure caret automatically.
//
// Coordinate note (verified against the 1.3.2 embedded shader docs):
// iCurrentCursor.xy is the -X,+Y corner of the cursor (top-left in GL y-up
// space), .zw is width/height. The rect therefore extends DOWN (-y) from .xy.

const float DURATION = 0.22; // seconds the smear takes to collapse
const float TRAIL_ALPHA = 0.55; // peak trail opacity (glass-friendly, not neon)

float sdRectangle(in vec2 p, in vec2 center, in vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// One edge of the parallelogram SDF; accumulates squared distance and the
// inside/outside winding sign (iq-style polygon SDF).
float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    d = min(d, dot(p - proj, p - proj));

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    s *= mix(1.0, -1.0, step(0.5, allCond + noneCond));
    return d;
}

float sdParallelogram(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);
    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);
    return s * sqrt(d);
}

// Pick which cursor corners the smear connects, based on travel direction,
// so the parallelogram never self-intersects.
float startVertexFactor(vec2 a, vec2 b) {
    float c1 = step(b.x, a.x) * step(a.y, b.y); // moved left-down
    float c2 = step(a.x, b.x) * step(b.y, a.y); // moved right-up
    return 1.0 - max(c1, c2);
}

vec2 norm(vec2 v, float isPosition) {
    return (v * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float easeOutCubic(float x) {
    return 1.0 - pow(1.0 - x, 3.0);
}

float antialias(float d) {
    return 1.0 - smoothstep(0.0, 2.0 * (2.0 / iResolution.y), d);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    vec2 vu = norm(fragCoord, 1.0);

    vec4 cur = vec4(norm(iCurrentCursor.xy, 1.0), norm(iCurrentCursor.zw, 0.0));
    vec4 prev = vec4(norm(iPreviousCursor.xy, 1.0), norm(iPreviousCursor.zw, 0.0));

    float progress = easeOutCubic(clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0));

    // No movement (typing in place / blink) or finished — nothing to draw.
    float travel = distance(cur.xy, prev.xy);
    if (travel < 0.001 || progress >= 1.0) {
        return;
    }

    // Trail tail slides from the previous cursor toward the current one.
    vec2 tail = mix(prev.xy, cur.xy, progress);

    float vf = startVertexFactor(cur.xy, prev.xy);
    float ivf = 1.0 - vf;
    vec2 v0 = vec2(cur.x + cur.z * vf,  cur.y - cur.w);
    vec2 v1 = vec2(cur.x + cur.z * ivf, cur.y);
    vec2 v2 = vec2(tail.x + cur.z * ivf, tail.y);
    vec2 v3 = vec2(tail.x + cur.z * vf,  tail.y - prev.w);

    float dTrail = sdParallelogram(vu, v0, v1, v2, v3);
    float dCursor = sdRectangle(vu, cur.xy + vec2(cur.z, -cur.w) * 0.5, cur.zw * 0.5);

    vec4 trailColor = vec4(iCurrentCursorColor.rgb, 1.0);
    float fade = (1.0 - progress) * TRAIL_ALPHA;

    // Smear body, fading as it collapses; the live cursor quad stays crisp.
    fragColor = mix(fragColor, trailColor, antialias(dTrail) * fade);
    fragColor = mix(fragColor, trailColor, antialias(dCursor) * (1.0 - progress) * 0.9);
}
