"""CM/26 monogram for the Ly greeter, in console cells.

One source for both the canvas mockup and the shipped .dur file. Pixels are
drawn 2 cells wide x 1 cell tall (console cells are ~1:2), then scaled.
Colours are VT palette indices (Ouranos remap in modules/common.nix):
  0 ground #0a0c11 · 4 cobalt #3b6bff · 8 slate #3a4152 · 15 lightest #f4f7fc
"""

GLYPHS = {
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "6": ["00111", "01000", "10000", "11110", "10001", "10001", "01110"],
}
TEXT = "CM/26"
SCALE_Y = 2  # each glyph pixel row -> 2 console rows
SCALE_X = 2  # each glyph pixel col -> 2 px -> 4 console cells
LETTER, SLASH, SHADOW = 15, 4, 4


def bitmap():
    """Return (pixels, colour) grids at glyph resolution x scale."""
    rows = 7
    pix, col = [[0] * 0 for _ in range(rows)], [[0] * 0 for _ in range(rows)]
    for i, ch in enumerate(TEXT):
        g = GLYPHS[ch]
        c = SLASH if ch == "/" else LETTER
        for y in range(rows):
            if i:
                pix[y].append(0)
                col[y].append(0)
            for bit in g[y]:
                pix[y].append(int(bit))
                col[y].append(c)
    # scale
    out_p, out_c = [], []
    for y in range(rows):
        for _ in range(SCALE_Y):
            rp, rc = [], []
            for x in range(len(pix[y])):
                rp += [pix[y][x]] * SCALE_X
                rc += [col[y][x]] * SCALE_X
            out_p.append(rp)
            out_c.append(rc)
    return out_p, out_c


def resolve(pix, col, step):
    """Portfolio2's resolve: average step x step blocks, majority wins."""
    if step <= 1:
        return pix, col
    h, w = len(pix), len(pix[0])
    rp = [[0] * w for _ in range(h)]
    rc = [[0] * w for _ in range(h)]
    for by in range(0, h, step):
        for bx in range(0, w, step):
            cells = [(y, x) for y in range(by, min(by + step, h)) for x in range(bx, min(bx + step, w))]
            on = sum(pix[y][x] for y, x in cells)
            if on * 2 >= len(cells):
                c = max((col[y][x] for y, x in cells if pix[y][x]), default=LETTER)
                for y, x in cells:
                    rp[y][x], rc[y][x] = 1, c
    return rp, rc


def cells(pix, col):
    """Glyph pixels -> console cells with a 1px cobalt offset shadow.

    Returns rows of (char, fg) where each pixel is two cells ("██")."""
    h, w = len(pix), len(pix[0])
    H, W = h + 1, (w + 1) * 2
    out = [[(" ", 0)] * W for _ in range(H)]
    for y in range(h):  # shadow first, offset +1,+1 px
        for x in range(w):
            if pix[y][x]:
                for dx in (0, 1):
                    out[y + 1][(x + 1) * 2 + dx] = ("█", SHADOW)
    for y in range(h):
        for x in range(w):
            if pix[y][x]:
                for dx in (0, 1):
                    out[y][x * 2 + dx] = ("█", col[y][x])
    return out


STEPS = [6, 4, 3, 2, 1]  # coarse -> sharp, then hold


if __name__ == "__main__":
    p, c = bitmap()
    for row in cells(p, c):
        print("".join(ch for ch, _ in row))
