#!/usr/bin/env python3
"""Convert an image into Braille-dot ASCII art for the dashboard.

Every art file in ascii_art/ is built from Unicode Braille (U+2800..U+28FF),
where one character carries a 2x4 grid of dots. That gives 8x the resolution
of a plain character-ramp renderer, which is what makes the art look detailed
at ~60 columns.

Pipeline: composite alpha over white -> grayscale -> optional autocrop to the
inked bbox -> area-average downsample to the dot grid (this turns the source's
halftone speckle into real local ink density) -> tone shaping -> dithering ->
pack dots into Braille cells.

Output goes to the config's ascii_art/ directory by default, named after the
input image, so the dashboard picks it up with no extra steps.

Usage:
  scripts/ascii_art/img2braille.py scripts/ascii_art/image_input.png
  scripts/ascii_art/img2braille.py in.png -o skull --width 62
  scripts/ascii_art/img2braille.py in.png -o - --preview /tmp/check.png
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

# Dot (col, row) -> bit inside a Braille cell. Rows 0-2 are the classic
# 6-dot block; row 3 lives in the high bits.
DOT_BITS = (
    (0x01, 0x02, 0x04, 0x40),  # left column, rows 0..3
    (0x08, 0x10, 0x20, 0x80),  # right column, rows 0..3
)
BRAILLE_BASE = 0x2800

# scripts/ascii_art/img2braille.py -> the nvim config root -> ascii_art/
ART_DIR = Path(__file__).resolve().parents[2] / "ascii_art"


def resolve_output(output, image):
    """Default to ART_DIR/<image stem>.txt; '-' means stdout.

    A bare name (no separator) is also placed in ART_DIR, so `-o skull` and
    `-o skull.txt` both land next to the other dashboard art. Anything that
    looks like a path is used verbatim.
    """
    if output == "-":
        return None
    if output is None:
        return ART_DIR / (Path(image).stem + ".txt")
    candidate = Path(output)
    if len(candidate.parts) == 1:
        return ART_DIR / (candidate.name if candidate.suffix else candidate.name + ".txt")
    return candidate


def load_gray(path, background):
    im = Image.open(path)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        flat = Image.new("RGBA", im.size, (background,) * 3 + (255,))
        flat.alpha_composite(im)
        im = flat
    return im.convert("L")


def autocrop(gray, ink_is_dark, pad, tol):
    """Trim uniform margins so the subject fills the grid."""
    arr = np.asarray(gray, dtype=np.int16)
    ink = arr <= tol if ink_is_dark else arr >= 255 - tol
    if not ink.any():
        return gray
    rows = np.flatnonzero(ink.any(axis=1))
    cols = np.flatnonzero(ink.any(axis=0))
    top, bottom = rows[0], rows[-1] + 1
    left, right = cols[0], cols[-1] + 1
    h, w = arr.shape
    return gray.crop(
        (
            max(0, left - pad),
            max(0, top - pad),
            min(w, right + pad),
            min(h, bottom + pad),
        )
    )


def dot_grid(gray, cols, rows, cell_aspect):
    """Resize to the dot grid, deriving rows from the image aspect if unset.

    A dot occupies cell_w/2 by cell_h/4 on screen, so with the usual
    cell_aspect (height/width) of 2.0 dots are square and the art keeps the
    source proportions when rows = cols * img_aspect / cell_aspect.
    """
    w, h = gray.size
    if rows is None:
        rows = max(1, round(cols * (h / w) / cell_aspect))
    # BOX = plain area average: the honest way to read ink density out of a
    # halftoned source. LANCZOS ringing would invent detail that isn't there.
    resized = gray.resize((cols * 2, rows * 4), Image.BOX)
    return np.asarray(resized, dtype=np.float64) / 255.0, rows


def shape_tone(v, gamma, contrast, black, white):
    """Map the used tonal range onto 0..1, then apply gamma and contrast."""
    lo, hi = black, white
    if hi <= lo:
        lo, hi = 0.0, 1.0
    v = np.clip((v - lo) / (hi - lo), 0.0, 1.0)
    if gamma != 1.0:
        v = v ** (1.0 / gamma)
    if contrast != 1.0:
        v = np.clip((v - 0.5) * contrast + 0.5, 0.0, 1.0)
    return v


def dither(v, mode, threshold):
    """Return a boolean dot-on mask. `v` is 0=off .. 1=on intensity."""
    if mode == "none":
        return v >= threshold

    kernels = {
        # (dy, dx, weight) diffused forward from the current pixel
        "fs": (((0, 1, 7 / 16), (1, -1, 3 / 16), (1, 0, 5 / 16), (1, 1, 1 / 16))),
        "atkinson": (
            (0, 1, 1 / 8),
            (0, 2, 1 / 8),
            (1, -1, 1 / 8),
            (1, 0, 1 / 8),
            (1, 1, 1 / 8),
            (2, 0, 1 / 8),
        ),
    }
    kernel = kernels[mode]
    buf = v.astype(np.float64, copy=True)
    h, w = buf.shape
    out = np.zeros((h, w), dtype=bool)
    for y in range(h):
        for x in range(w):
            old = buf[y, x]
            on = old >= threshold
            out[y, x] = on
            err = old - (1.0 if on else 0.0)
            if err == 0.0:
                continue
            for dy, dx, weight in kernel:
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w:
                    buf[ny, nx] += err * weight
    return out


def pack(mask, cols, rows, blank_char):
    lines = []
    for cy in range(rows):
        line = []
        for cx in range(cols):
            bits = 0
            for dx in (0, 1):
                for dy in range(4):
                    if mask[cy * 4 + dy, cx * 2 + dx]:
                        bits |= DOT_BITS[dx][dy]
            line.append(blank_char if bits == 0 else chr(BRAILLE_BASE + bits))
        lines.append("".join(line))
    return lines


def write_preview(mask, path, scale):
    """Render the dot mask as pixels — no Braille font needed to eyeball it."""
    img = Image.fromarray(np.where(mask, 0, 255).astype(np.uint8), mode="L")
    w, h = img.size
    img.resize((w * scale, h * scale), Image.NEAREST).save(path)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("image")
    p.add_argument(
        "-o",
        "--output",
        help=f"output name or path (default: {{image name}}.txt in {ART_DIR}); '-' for stdout",
    )
    p.add_argument("--width", type=int, default=62, help="columns of Braille cells (default: 62)")
    p.add_argument("--rows", type=int, help="rows of cells (default: from image aspect)")
    p.add_argument(
        "--cell-aspect",
        type=float,
        default=2.0,
        help="terminal cell height/width ratio (default: 2.0)",
    )
    p.add_argument(
        "--ink",
        choices=("dark", "light"),
        default="dark",
        help="which tone is the subject in the source (default: dark)",
    )
    p.add_argument("--dither", choices=("fs", "atkinson", "none"), default="fs")
    p.add_argument("--threshold", type=float, default=0.5, help="dot-on cutoff, 0..1 (default: 0.5)")
    p.add_argument("--gamma", type=float, default=1.0, help=">1 keeps more dots in midtones")
    p.add_argument("--contrast", type=float, default=1.0)
    p.add_argument("--black", type=float, default=0.0, help="input level mapped to fully off")
    p.add_argument("--white", type=float, default=1.0, help="input level mapped to fully on")
    p.add_argument("--no-crop", action="store_true", help="keep the source margins")
    p.add_argument("--crop-tol", type=int, default=32, help="how far from pure background still counts as margin")
    p.add_argument("--crop-pad", type=int, default=0, help="pixels of margin to keep after cropping")
    p.add_argument("--space-blank", action="store_true", help="use ' ' instead of U+2800 for empty cells")
    p.add_argument("--preview", help="write a PNG of the dot grid for visual checking")
    p.add_argument("--preview-scale", type=int, default=4)
    args = p.parse_args()

    ink_is_dark = args.ink == "dark"
    gray = load_gray(args.image, background=255 if ink_is_dark else 0)
    if not args.no_crop:
        gray = autocrop(gray, ink_is_dark, args.crop_pad, args.crop_tol)
    if ink_is_dark:
        gray = ImageOps.invert(gray)  # from here on, bright == ink == dot on

    v, rows = dot_grid(gray, args.width, args.rows, args.cell_aspect)
    v = shape_tone(v, args.gamma, args.contrast, args.black, args.white)
    mask = dither(v, args.dither, args.threshold)
    lines = pack(mask, args.width, rows, " " if args.space_blank else chr(BRAILLE_BASE))

    text = "\n".join(lines) + "\n"
    dest = resolve_output(args.output, args.image)
    if dest is None:
        sys.stdout.write(text)
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
        print(f"{dest}: {args.width}x{rows} cells ({args.width * 2}x{rows * 4} dots)", file=sys.stderr)

    if args.preview:
        write_preview(mask, args.preview, args.preview_scale)
        print(f"{args.preview}: preview written", file=sys.stderr)


if __name__ == "__main__":
    main()
