//! Ceen Signal Hand — real-time generative ASCII wallpaper.
//!
//! Renders RGB frames live (no pre-baked loop) and writes them as rawvideo to
//! stdout, which a `mpvpaper` instance displays on the Hyprland background.
//! Motion is driven by real elapsed time, so it never loops; the hand clip is
//! the only periodic element. Procedural "weather"/raindrops are intentionally
//! gone — just the glyph hand, a faint signal grid, amber ripples, scanlines.

use std::io::{self, Write};
use std::process::Command;
use std::time::{Duration, Instant};

use ab_glyph::{Font, FontVec, Glyph, Point, ScaleFont};

// Glyph ramp: dark -> dense. Same family as the original Python renderer.
const RAMP: &[u8] = b" .'`^\",:;Il!i~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";

// Punchier, higher-contrast palette: hot amber core, cool teal shadows.
const AMBER: [f32; 3] = [244.0, 170.0, 60.0];
const FOREST: [f32; 3] = [46.0, 96.0, 92.0]; // cool teal-green low tones
const MIST: [f32; 3] = [150.0, 166.0, 162.0]; // slightly cool mid
const INK: [u8; 3] = [8, 11, 12];

struct Config {
    width: usize,
    height: usize,
    fps: u32,
    cell: usize,
    hand_scale: f32,
    source: String,
}

impl Config {
    fn cols(&self) -> usize {
        self.width / self.cell
    }
}

// A rasterized glyph: coverage bitmap plus pixel placement offsets.
struct AtlasGlyph {
    w: usize,
    h: usize,
    left: i32, // x offset from cell origin to bitmap left
    top: i32,  // y offset from cell origin to bitmap top
    cov: Vec<u8>,
}

struct Atlas {
    glyphs: Vec<AtlasGlyph>, // indexed parallel to RAMP
}

fn build_atlas(font: &FontVec, px: f32) -> Atlas {
    let scaled = font.as_scaled(px);
    let ascent = scaled.ascent();
    let mut glyphs = Vec::with_capacity(RAMP.len());
    for &ch in RAMP {
        let c = ch as char;
        let gid = font.glyph_id(c);
        let glyph: Glyph = gid.with_scale_and_position(px, Point { x: 0.0, y: ascent });
        if let Some(outline) = font.outline_glyph(glyph) {
            let bounds = outline.px_bounds();
            let w = bounds.width().ceil() as usize;
            let h = bounds.height().ceil() as usize;
            let mut cov = vec![0u8; w.max(1) * h.max(1)];
            outline.draw(|x, y, c| {
                let xi = x as usize;
                let yi = y as usize;
                if xi < w && yi < h {
                    cov[yi * w + xi] = (c * 255.0) as u8;
                }
            });
            glyphs.push(AtlasGlyph {
                w: w.max(1),
                h: h.max(1),
                left: bounds.min.x.floor() as i32,
                top: bounds.min.y.floor() as i32,
                cov,
            });
        } else {
            // Space / no outline.
            glyphs.push(AtlasGlyph { w: 1, h: 1, left: 0, top: 0, cov: vec![0] });
        }
    }
    Atlas { glyphs }
}

struct Frame {
    w: usize,
    h: usize,
    buf: Vec<u8>, // rgb24
}

impl Frame {
    fn new(w: usize, h: usize) -> Self {
        Frame { w, h, buf: vec![0u8; w * h * 3] }
    }

    fn clear(&mut self, c: [u8; 3]) {
        for px in self.buf.chunks_exact_mut(3) {
            px[0] = c[0];
            px[1] = c[1];
            px[2] = c[2];
        }
    }

    #[inline]
    fn blend(&mut self, x: i32, y: i32, c: [f32; 3], a: f32) {
        if x < 0 || y < 0 || x >= self.w as i32 || y >= self.h as i32 || a <= 0.0 {
            return;
        }
        let i = (y as usize * self.w + x as usize) * 3;
        let inv = 1.0 - a;
        self.buf[i] = (self.buf[i] as f32 * inv + c[0] * a) as u8;
        self.buf[i + 1] = (self.buf[i + 1] as f32 * inv + c[1] * a) as u8;
        self.buf[i + 2] = (self.buf[i + 2] as f32 * inv + c[2] * a) as u8;
    }

    // Darken a pixel toward black (for scanlines).
    #[inline]
    fn darken(&mut self, x: i32, y: i32, k: f32) {
        if x < 0 || y < 0 || x >= self.w as i32 || y >= self.h as i32 {
            return;
        }
        let i = (y as usize * self.w + x as usize) * 3;
        self.buf[i] = (self.buf[i] as f32 * k) as u8;
        self.buf[i + 1] = (self.buf[i + 1] as f32 * k) as u8;
        self.buf[i + 2] = (self.buf[i + 2] as f32 * k) as u8;
    }

    fn blit_glyph(&mut self, g: &AtlasGlyph, ox: i32, oy: i32, color: [f32; 3]) {
        for gy in 0..g.h {
            let py = oy + g.top + gy as i32;
            for gx in 0..g.w {
                let a = g.cov[gy * g.w + gx];
                if a == 0 {
                    continue;
                }
                let px = ox + g.left + gx as i32;
                self.blend(px, py, color, a as f32 / 255.0);
            }
        }
    }

    fn hline(&mut self, y: i32, color: [f32; 3], a: f32) {
        for x in 0..self.w as i32 {
            self.blend(x, y, color, a);
        }
    }

    fn vline(&mut self, x: i32, color: [f32; 3], a: f32) {
        for y in 0..self.h as i32 {
            self.blend(x, y, color, a);
        }
    }

    // Anti-aliased-ish circle outline by sampling angles.
    fn circle(&mut self, cx: f32, cy: f32, radius: f32, color: [f32; 3], thickness: f32, a: f32) {
        if radius <= 0.0 {
            return;
        }
        let steps = ((2.0 * std::f32::consts::PI * radius).ceil() as usize).max(16);
        let half = (thickness * 0.5).max(0.5);
        for s in 0..steps {
            let th = s as f32 / steps as f32 * std::f32::consts::PI * 2.0;
            let (sn, cs) = th.sin_cos();
            let mut r = -half;
            while r <= half {
                let x = (cx + cs * (radius + r)).round() as i32;
                let y = (cy + sn * (radius + r)).round() as i32;
                self.blend(x, y, color, a);
                r += 1.0;
            }
        }
    }
}

#[inline]
fn mix(a: [f32; 3], b: [f32; 3], t: f32) -> [f32; 3] {
    let t = t.clamp(0.0, 1.0);
    [
        a[0] * (1.0 - t) + b[0] * t,
        a[1] * (1.0 - t) + b[1] * t,
        a[2] * (1.0 - t) + b[2] * t,
    ]
}

#[inline]
fn scale(c: [f32; 3], k: f32) -> [f32; 3] {
    [c[0] * k, c[1] * k, c[2] * k]
}

fn find_font() -> FontVec {
    let mut paths: Vec<String> = Vec::new();
    // CEEN_FONT lets the Nix wrapper pin a store-path font (purity, no fontconfig).
    if let Ok(p) = std::env::var("CEEN_FONT") {
        if !p.is_empty() {
            paths.push(p);
        }
    }
    // Otherwise prefer fc-match so we don't hardcode a /nix/store path.
    if let Ok(out) = Command::new("fc-match")
        .args(["-f", "%{file}", "DejaVu Sans Mono"])
        .output()
    {
        if out.status.success() {
            let p = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !p.is_empty() {
                paths.push(p);
            }
        }
    }
    paths.push("/run/current-system/sw/share/X11/fonts/TTF/DejaVuSansMono.ttf".into());
    for p in paths {
        if let Ok(bytes) = std::fs::read(&p) {
            if let Ok(f) = FontVec::try_from_vec(bytes) {
                eprintln!("[ceen-live] font: {p}");
                return f;
            }
        }
    }
    panic!("[ceen-live] no usable DejaVuSansMono font found");
}

fn decode_hand(cfg: &Config, hand_cols: usize, hand_rows: usize, src_fps: u32) -> Vec<Vec<u8>> {
    let vf = format!(
        "fps={src_fps},scale={hc}:{hr}:force_original_aspect_ratio=decrease,pad={hc}:{hr}:(ow-iw)/2:(oh-ih)/2,format=gray",
        hc = hand_cols,
        hr = hand_rows
    );
    let out = Command::new("ffmpeg")
        .args([
            "-v", "error", "-i", &cfg.source, "-vf", &vf, "-f", "rawvideo", "-pix_fmt", "gray", "-",
        ])
        .output()
        .expect("failed to launch ffmpeg");
    if !out.status.success() {
        panic!(
            "[ceen-live] ffmpeg decode failed: {}",
            String::from_utf8_lossy(&out.stderr)
        );
    }
    let fsize = hand_cols * hand_rows;
    let frames: Vec<Vec<u8>> = out
        .stdout
        .chunks_exact(fsize)
        .map(|c| c.to_vec())
        .collect();
    assert!(!frames.is_empty(), "[ceen-live] decoded zero hand frames");
    eprintln!("[ceen-live] hand: {hand_cols}x{hand_rows} cells, {} frames", frames.len());
    frames
}

// Percentile-style normalization bounds, cheap stride sampling.
fn norm_bounds(gray: &[u8]) -> (f32, f32) {
    let stride = (gray.len() / 600).max(1);
    let mut samples: Vec<u8> = gray.iter().step_by(stride).copied().collect();
    samples.sort_unstable();
    let lo = samples[(samples.len() as f32 * 0.08) as usize] as f32;
    let hi = samples[((samples.len() as f32 * 0.992) as usize).min(samples.len() - 1)] as f32;
    (lo, (hi - lo).max(10.0))
}

fn draw_background(frame: &mut Frame, cfg: &Config) {
    // Faint signal grid — structural, not raindrops.
    let mut y = 0i32;
    while y < cfg.height as i32 {
        frame.hline(y, [24.0, 35.0, 28.0], 0.5);
        y += (cfg.cell * 5) as i32;
    }
    let mut x = 0i32;
    while x < cfg.width as i32 {
        frame.vline(x, [18.0, 27.0, 22.0], 0.45);
        x += (cfg.cell * 8) as i32;
    }
}

#[allow(clippy::too_many_arguments)]
fn draw_hand(
    frame: &mut Frame,
    cfg: &Config,
    atlas: &Atlas,
    gray: &[u8],
    hand_cols: usize,
    hand_rows: usize,
    t: f32,
) -> (f32, f32, f32, f32) {
    let hand_w = hand_cols as f32 * cfg.cell as f32 * cfg.hand_scale;
    let hand_h = hand_rows as f32 * cfg.cell as f32 * cfg.hand_scale;
    // Centered, with a slow breathing drift.
    let left = cfg.width as f32 * 0.50 - hand_w * 0.5 + (t * 0.31).sin() * 22.0;
    let top = cfg.height as f32 * 0.50 - hand_h * 0.5 + (t * 0.23 + 1.7).sin() * 18.0;
    let draw_cell = cfg.cell as f32 * cfg.hand_scale;
    let (lo, span) = norm_bounds(gray);
    let shimmer = 0.10 * (t * 1.9).sin();

    for r in 0..hand_rows {
        let row_off = r * hand_cols;
        for c in 0..hand_cols {
            let raw = gray[row_off + c] as f32;
            let v = ((raw - lo) / span).clamp(0.0, 1.0);
            if v < 0.14 {
                continue;
            }
            let idx = (((v.powf(0.72)) * (RAMP.len() - 1) as f32) as usize).min(RAMP.len() - 1);
            let g = &atlas.glyphs[idx];
            let x = (left + c as f32 * draw_cell) as i32;
            let y = (top + r as f32 * draw_cell) as i32;
            let wave = 0.5 + 0.5 * (c as f32 * 0.09 - r as f32 * 0.045 + t * 1.35).sin();
            let mut color = mix(MIST, AMBER, (v * 0.60 + wave * 0.24 + shimmer).clamp(0.0, 1.0));
            if v < 0.35 {
                color = mix(FOREST, MIST, v * 0.65);
            }
            frame.blit_glyph(g, x, y, color);
        }
    }
    (left, top, left + hand_w, top + hand_h)
}

fn draw_ripples(frame: &mut Frame, cfg: &Config, t: f32, bbox: (f32, f32, f32, f32)) {
    let (x0, y0, x1, y1) = bbox;
    let anchors = [
        (x0 + (x1 - x0) * 0.56, y0 + (y1 - y0) * 0.27),
        (x0 + (x1 - x0) * 0.64, y0 + (y1 - y0) * 0.34),
        (x0 + (x1 - x0) * 0.69, y0 + (y1 - y0) * 0.44),
    ];
    let wscale = cfg.width as f32 / 1920.0;
    for (idx, &(cx, cy)) in anchors.iter().enumerate() {
        let pulse = (t * 0.50 + idx as f32 * 0.24).rem_euclid(1.0);
        for ring in 0..4 {
            let r = (pulse + ring as f32 * 0.20).rem_euclid(1.0);
            let radius = (22.0 + r * 175.0) * wscale;
            let intensity = (1.0 - r).max(0.0).powf(1.5);
            let color = scale(AMBER, 0.34 + 0.62 * intensity);
            let thick = (2.4 * intensity).max(1.0);
            frame.circle(cx, cy, radius, color, thick, (0.42 + 0.55 * intensity).min(1.0));
        }
    }
}

fn draw_scanlines(frame: &mut Frame, phase: i32) {
    let mut y = phase.rem_euclid(4);
    while y < frame.h as i32 {
        for x in 0..frame.w as i32 {
            frame.darken(x, y, 0.82);
        }
        y += 4;
    }
}

fn parse_args() -> Config {
    let mut cfg = Config {
        width: 1920,
        height: 1080,
        fps: 60,
        cell: 12,
        hand_scale: 0.98,
        // CEEN_HAND lets the Nix wrapper point at the store-bundled clip.
        source: std::env::var("CEEN_HAND").unwrap_or_else(|_| "source/hand.mp4".into()),
    };
    let args: Vec<String> = std::env::args().collect();
    let mut i = 1;
    while i < args.len() {
        let val = || args.get(i + 1).cloned().unwrap_or_default();
        match args[i].as_str() {
            "--width" => cfg.width = val().parse().unwrap(),
            "--height" => cfg.height = val().parse().unwrap(),
            "--fps" => cfg.fps = val().parse().unwrap(),
            "--cell" => cfg.cell = val().parse().unwrap(),
            "--source" => cfg.source = val(),
            other => panic!("unknown arg: {other}"),
        }
        i += 2;
    }
    cfg
}

fn main() {
    let cfg = parse_args();
    let font = find_font();
    let atlas = build_atlas(&font, (cfg.cell as f32 * 1.15).max(8.0));

    let src_fps = 30u32; // native rate of hand.mp4
    let hand_cols = (cfg.cols() as f32 * 0.52) as usize;
    let hand_cols = hand_cols.max(54);
    let hand_rows = ((hand_cols as f32 * 480.0 / 512.0) as usize).max(50);
    let hand_frames = decode_hand(&cfg, hand_cols, hand_rows, src_fps);

    let mut frame = Frame::new(cfg.width, cfg.height);
    let stdout = io::stdout();
    let mut out = stdout.lock();

    let frame_dt = Duration::from_secs_f64(1.0 / cfg.fps as f64);
    let start = Instant::now();
    let mut next = start;
    let mut n: u64 = 0;

    eprintln!(
        "[ceen-live] {}x{} @ {}fps, cell {} — streaming rawvideo to stdout",
        cfg.width, cfg.height, cfg.fps, cfg.cell
    );

    loop {
        let t = start.elapsed().as_secs_f32();
        let hand_idx = ((t * src_fps as f32) as usize) % hand_frames.len();

        frame.clear(INK);
        draw_background(&mut frame, &cfg);
        let _bbox = draw_hand(
            &mut frame,
            &cfg,
            &atlas,
            &hand_frames[hand_idx],
            hand_cols,
            hand_rows,
            t,
        );
        // Ripples removed by request — keep draw_ripples() around for later.
        let _ = draw_ripples;
        draw_scanlines(&mut frame, n as i32);

        if out.write_all(&frame.buf).is_err() {
            // Sink (mpv) closed the pipe — exit cleanly.
            break;
        }

        n += 1;
        next += frame_dt;
        let now = Instant::now();
        if next > now {
            std::thread::sleep(next - now);
        } else {
            // Behind schedule; resync to avoid spiral.
            next = now;
        }
    }
}
