# img2braille

Converts an image into Braille-dot art in the same format as everything in
`ascii_art/`, which the dashboard renders on startup.

## Why Braille

The existing art is not a character ramp (`@#%*+=-.`). It is Unicode Braille
(`U+2800`–`U+28FF`), where one character carries a **2×4 dot grid** — so a
62-column file is really a 124-dot-wide bitmap, 8× the resolution of a plain
ramp at the same size. Empty cells use `U+2800` (blank Braille), not spaces,
which is what keeps every line the same display width.

## Usage

Output lands in `ascii_art/` automatically, named after the input image:

```bash
scripts/ascii_art/img2braille.py scripts/ascii_art/image_input.png
# -> ascii_art/image_input.txt   (62x42 cells, 124x168 dots)
```

Pick the art name, or print instead of writing:

```bash
scripts/ascii_art/img2braille.py in.png -o skull          # -> ascii_art/skull.txt
scripts/ascii_art/img2braille.py in.png -o /tmp/out.txt   # a path is used as-is
scripts/ascii_art/img2braille.py in.png -o -              # stdout
```

The dashboard scans `ascii_art/` at startup, so a new file is picked up with no
config change. `image_input.png` is the bundled sample (it produced
`ascii_art/skull.txt`).

## Checking the result

Braille is hard to judge in a terminal that lacks the glyphs. `--preview`
renders the dot grid straight to pixels, no font involved:

```bash
scripts/ascii_art/img2braille.py in.png --preview /tmp/check.png
```

## Options that matter

| Flag | Effect |
|---|---|
| `--width N` | Columns of Braille cells. Default `62`, matching the rest of `ascii_art/`. Raise for more detail. |
| `--rows N` | Force row count. Omit and it follows the image aspect. |
| `--cell-aspect R` | Terminal cell height/width, default `2.0`. Lower it if the art comes out stretched vertically. |
| `--ink light` | Source subject is light on a dark background (default assumes dark on light). |
| `--dither fs\|atkinson\|none` | Default `fs` (Floyd–Steinberg). `none` is a hard threshold — crisper edges, but flattens texture. |
| `--threshold`, `--gamma`, `--contrast`, `--black`, `--white` | Tone shaping when the result is too dark or washed out. |
| `--no-crop` | Keep the source margins instead of trimming to the subject. |
| `--space-blank` | Use `' '` for empty cells instead of `U+2800`. |

## How it works

1. Composite alpha over the background, convert to grayscale.
2. Autocrop to the inked bounding box so the subject fills the grid.
3. Resize to the dot grid. Rows default to `cols × img_aspect / cell_aspect`,
   because a dot occupies `cell_w/2 × cell_h/4` on screen — square at the usual
   2.0 cell ratio.
4. Downsample with `Image.BOX` (plain area average). This matters for halftoned
   or textured sources: area-averaging reads the speckle as real local ink
   density, where Lanczos would ring and invent detail.
5. Shape tone (levels → gamma → contrast), then dither to a 1-bit dot mask.
6. Pack each 2×4 dot block into one Braille codepoint.

Requires Pillow and NumPy.
