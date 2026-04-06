"""
QuickNotes app icon — retro newspaper / aged-print style.

Visual language:
  • Warm sepia paper with vignette and grain
  • Classic newspaper masthead (dark ink banner + American Typewriter title)
  • Ornamental hairline-rule dividers
  • Simulated newspaper columns (varied-width ink lines)
  • Diagonal pencil with aged-yellow body, wood tip, gold ferrule, cream eraser
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math, os, random

FONT_TYPEWRITER  = "/System/Library/Fonts/Supplemental/AmericanTypewriter.ttc"
FONT_TIMES_BOLD  = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"

OUT = "QuickNotes/Assets.xcassets/AppIcon.appiconset"
os.makedirs(OUT, exist_ok=True)

# ── Colour palette ────────────────────────────────────────────────────────────
PAPER       = (242, 228, 188)
PAPER_DARK  = (210, 192, 145)
INK         = ( 28,  22,  14)      # near-black ink
INK_MID     = ( 72,  58,  38)      # medium ink brown
INK_LIGHT   = (155, 135,  95)      # faded ink
MASTHEAD_BG = ( 32,  22,  12)      # deep ink black
TITLE_COL   = (238, 215, 148)      # aged gold / cream
RULE_COL    = ( 90,  70,  40)      # thin rule colour
PEN_BODY    = (210, 172,  52)      # aged yellow pencil
PEN_SHADE   = (165, 128,  30)      # pencil side shading
PEN_WOOD    = (180, 132,  72)      # wood cone
PEN_GRAPH   = ( 50,  45,  40)      # graphite tip
PEN_FERR    = (175, 152,  85)      # gold ferrule
PEN_ERASER  = (225, 195, 165)      # aged rubber eraser

# ── Helpers ───────────────────────────────────────────────────────────────────

def lerp(a, b, t):
    return a + (b - a) * t

def lerp_color(c1, c2, t):
    return tuple(max(0, min(255, int(lerp(c1[i], c2[i], t)))) for i in range(3))

def rect_pts(cx, cy, hl, hw, a):
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + ox*ca - oy*sa, cy + ox*sa + oy*ca)
            for ox, oy in [(-hl,-hw),(hl,-hw),(hl,hw),(-hl,hw)]]

def safe_font(path, size, index=0):
    try:
        return ImageFont.truetype(path, size=size, index=index)
    except Exception:
        return ImageFont.load_default()

# ── Main draw ─────────────────────────────────────────────────────────────────

def make_icon(size: int) -> Image.Image:
    s   = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rng = random.Random(42)          # deterministic grain

    # ── 1. Paper background (sepia gradient + grain) ──────────────────────────
    for y in range(s):
        t = y / s
        c = lerp_color(PAPER, PAPER_DARK, t * 0.35)
        ImageDraw.Draw(img).line([(0, y), (s, y)], fill=c + (255,))

    # Grain
    grain = img.copy()
    gd    = ImageDraw.Draw(grain)
    for _ in range(s * s // 6):
        gx = rng.randint(0, s - 1)
        gy = rng.randint(0, s - 1)
        v  = rng.randint(-18, 10)
        px = img.getpixel((gx, gy))
        grain.putpixel((gx, gy), tuple(max(0, min(255, px[i] + v)) for i in range(3)) + (255,))
    img = grain

    # Vignette (darken edges)
    vig = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    vd  = ImageDraw.Draw(vig)
    steps = 18
    for i in range(steps):
        t   = i / steps
        inset = int(s * t * 0.45)
        alpha = int(90 * (1 - t) ** 1.6)
        vd.rounded_rectangle([inset, inset, s-inset, s-inset],
                              radius=int(s * 0.22 * (1 - t)),
                              outline=(0, 0, 0, alpha), width=max(1, int(s * 0.01)))
    img = Image.alpha_composite(img.convert("RGBA"), vig)

    draw = ImageDraw.Draw(img)

    # ── 2. Outer border (double rule) ─────────────────────────────────────────
    b1, b2 = int(s * 0.045), int(s * 0.060)
    bw = max(2, int(s * 0.007))
    draw.rounded_rectangle([b1, b1, s-b1, s-b1],
                            radius=int(s * 0.175), outline=INK, width=bw)
    draw.rounded_rectangle([b2, b2, s-b2, s-b2],
                            radius=int(s * 0.16),  outline=INK_MID, width=max(1, bw//2))

    # ── 3. Masthead (dark ink banner) ─────────────────────────────────────────
    mh_t = int(s * 0.075)
    mh_b = int(s * 0.285)
    mh_l, mh_r = b1 + bw, s - b1 - bw
    draw.rounded_rectangle([mh_l, mh_t, mh_r, mh_b],
                            radius=max(2, int(s * 0.015)),
                            fill=MASTHEAD_BG)

    # Masthead inner hairline border
    hi = max(2, int(s * 0.009))
    draw.rectangle([mh_l+hi, mh_t+hi, mh_r-hi, mh_b-hi],
                   outline=TITLE_COL, width=max(1, int(s * 0.003)))

    # Title: "QUICK NOTES"
    title_font_sz = int(s * 0.115)
    sub_font_sz   = int(s * 0.038)
    title_font = safe_font(FONT_TYPEWRITER, title_font_sz)
    sub_font   = safe_font(FONT_TYPEWRITER, sub_font_sz)

    mh_cx = (mh_l + mh_r) // 2
    mh_cy = (mh_t + mh_b) // 2

    # "QUICK" above, "NOTES" below
    for i, word in enumerate(["QUICK", "NOTES"]):
        offset_y = int(s * 0.042) * (i - 0.5)
        bb = draw.textbbox((0, 0), word, font=title_font)
        tw, th = bb[2]-bb[0], bb[3]-bb[1]
        draw.text((mh_cx - tw//2, mh_cy - th//2 + offset_y),
                  word, font=title_font, fill=TITLE_COL)

    # Small ornamental stars flanking title
    star_y  = mh_cy - int(s * 0.005)
    star_r  = max(3, int(s * 0.014))
    for sx in [mh_l + int((mh_r-mh_l)*0.08), mh_r - int((mh_r-mh_l)*0.08)]:
        for angle_deg in range(0, 360, 45):
            a  = math.radians(angle_deg)
            x1 = sx + int(star_r * math.cos(a))
            y1 = star_y + int(star_r * math.sin(a))
            x2 = sx + int(star_r * 0.38 * math.cos(a + math.radians(22.5)))
            y2 = star_y + int(star_r * 0.38 * math.sin(a + math.radians(22.5)))
            draw.line([(sx, star_y), (x1, y1)], fill=TITLE_COL, width=max(1, int(s*0.004)))

    # Subtitle: "EST. 2026"
    sub_str = "EST. 2026"
    bb2 = draw.textbbox((0, 0), sub_str, font=sub_font)
    sw  = bb2[2] - bb2[0]
    draw.text((mh_cx - sw//2, mh_b - int(s*0.065)),
              sub_str, font=sub_font, fill=TITLE_COL + (140,))

    # ── 4. Ornamental rule under masthead ─────────────────────────────────────
    rl_y = mh_b + int(s * 0.022)
    rl_l = b2 + int(s * 0.03)
    rl_r = s - b2 - int(s * 0.03)

    def draw_ornamental_rule(y, l, r, thick=1):
        mid = (l + r) // 2
        draw.line([(l, y), (r, y)], fill=INK, width=max(1, thick*2))
        draw.line([(l, y+int(s*0.007)), (r, y+int(s*0.007))],
                  fill=INK_MID, width=max(1, thick))
        # Central diamond ornament
        d = int(s * 0.013)
        draw.polygon([(mid, y-d), (mid+d, y+int(s*0.0035)),
                       (mid, y+d*2+int(s*0.0035)), (mid-d, y+int(s*0.0035))],
                     fill=INK)
        # Small fleur-ish dashes
        for ox in [-int(s*0.045), int(s*0.045)]:
            draw.line([(mid+ox-int(s*0.018), y+int(s*0.0035)),
                       (mid+ox+int(s*0.018), y+int(s*0.0035))],
                      fill=INK, width=max(1, thick*2))

    draw_ornamental_rule(rl_y, rl_l, rl_r, thick=max(1, int(s*0.003)))

    # ── 5. Newspaper columns (simulated typeset text) ─────────────────────────
    col_t   = rl_y + int(s * 0.030)
    col_b   = s - b2 - int(s * 0.085)
    n_cols  = 2
    gutter  = int(s * 0.022)
    col_w   = (rl_r - rl_l - gutter) // n_cols

    line_rng = random.Random(7)
    for col in range(n_cols):
        cx0 = rl_l + col * (col_w + gutter)
        cx1 = cx0 + col_w
        ly  = col_t
        while ly < col_b - int(s * 0.02):
            # Vary line width for natural typeset look
            lw_frac = line_rng.uniform(0.72, 1.0)
            lw_px   = max(1, int(s * 0.007))
            draw.rectangle([cx0, ly, cx0 + int(col_w * lw_frac), ly + lw_px],
                           fill=INK_LIGHT)
            ly += int(s * 0.030) + line_rng.randint(0, int(s * 0.005))

    # Vertical column rule between columns
    cg_x = rl_l + col_w + gutter // 2
    draw.line([(cg_x, col_t), (cg_x, col_b)],
              fill=INK_MID, width=max(1, int(s * 0.003)))

    # ── 6. Pencil (diagonal, across lower-right corner) ──────────────────────
    pen_canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd  = ImageDraw.Draw(pen_canvas)

    # Pencil drawn vertically, point upward, then rotated
    pcx  = s // 2
    p_t  = int(s * 0.05)
    p_b  = int(s * 0.89)
    phw  = int(s * 0.030)
    tot  = p_b - p_t
    tip_h  = int(tot * 0.12)
    ferr_h = int(tot * 0.055)
    era_h  = int(tot * 0.085)
    body_t = p_t + tip_h
    body_b = p_b - ferr_h - era_h

    # Body (aged yellow, flat sides)
    pd.rectangle([pcx - phw, body_t, pcx + phw, body_b], fill=PEN_BODY)
    # Right shading strip
    sw2 = max(1, phw // 3)
    pd.rectangle([pcx + phw - sw2, body_t, pcx + phw, body_b], fill=PEN_SHADE)
    # Highlight strip
    pd.rectangle([pcx - phw, body_t, pcx - phw + sw2, body_b],
                 fill=tuple(min(255, c+35) for c in PEN_BODY) + (255,))

    # Wood cone
    wood_pts = [(pcx - phw, body_t), (pcx + phw, body_t), (pcx, p_t + int(tip_h*0.28))]
    pd.polygon(wood_pts, fill=PEN_WOOD)

    # Graphite tip
    gph_hw  = max(1, phw // 4)
    gph_cut = p_t + int(tip_h * 0.28)
    gph_pts = [(pcx - gph_hw, gph_cut), (pcx + gph_hw, gph_cut), (pcx, p_t)]
    pd.polygon(gph_pts, fill=PEN_GRAPH)

    # Ferrule (gold band)
    pd.rectangle([pcx - phw, body_b, pcx + phw, body_b + ferr_h], fill=PEN_FERR)
    # Ferrule highlight
    hi_w = max(1, phw // 2)
    pd.rectangle([pcx - hi_w, body_b, pcx + hi_w, body_b + int(ferr_h * 0.4)],
                 fill=tuple(min(255, c + 30) for c in PEN_FERR) + (255,))
    # Ferrule ring line
    ring_y = body_b + int(ferr_h * 0.55)
    pd.line([(pcx - phw, ring_y), (pcx + phw, ring_y)],
            fill=tuple(max(0, c - 30) for c in PEN_FERR), width=max(1, int(s * 0.003)))

    # Eraser (aged cream)
    pd.rectangle([pcx - phw, body_b + ferr_h, pcx + phw, p_b], fill=PEN_ERASER)

    # Rotate pencil and shift to bottom-right
    pen_rot = pen_canvas.rotate(42, resample=Image.BICUBIC, center=(s//2, s//2))
    sx, sy  = int(s * 0.225), int(s * 0.19)
    shifted = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    shifted.paste(pen_rot, (sx, sy))
    img = Image.alpha_composite(img, shifted)

    # ── 7. Rounded-square mask ────────────────────────────────────────────────
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s, s],
                                            radius=int(s * 0.22), fill=255)
    img.putalpha(mask)

    return img


# ── Export ────────────────────────────────────────────────────────────────────

SIZES = [
    (  16, "icon_16x16.png"),
    (  32, "icon_16x16@2x.png"),
    (  32, "icon_32x32.png"),
    (  64, "icon_32x32@2x.png"),
    ( 128, "icon_128x128.png"),
    ( 256, "icon_128x128@2x.png"),
    ( 256, "icon_256x256.png"),
    ( 512, "icon_256x256@2x.png"),
    ( 512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

print("Drawing master icon at 1024×1024 …")
master = make_icon(1024)

for px_size, filename in SIZES:
    out = master if px_size == 1024 else master.resize((px_size, px_size), Image.LANCZOS)
    out.save(os.path.join(OUT, filename), "PNG")
    print(f"  ✓  {filename:38s}  {px_size}×{px_size}")

print("\nDone.")
