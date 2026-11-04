# img2braille

## Sub-features

- `scripts/ascii_art/img2braille.py IMAGE [-o NAME|PATH|-] [--width N] [--preview PNG]`:
  image to Braille art. A bare name writes `<config>/ascii_art/NAME.txt`, which the dashboard
  lists immediately. Needs numpy + Pillow (the run uses python3 from the caller's PATH dir).

## How to get to it (user POV)

Run the script on a picture, then pick the new art with `,bv` in nvim.

## Driving it with verify.sh

Run the **snapshot's** copy (`$CONFIG`), so the art lands in the run, never in the checkout:

```sh
$V cli RUN sh -c 'python3 "$CONFIG/scripts/ascii_art/img2braille.py" "$CONFIG/scripts/ascii_art/image_input.png" -o verify_art --width 40 && wc -lm "$CONFIG/ascii_art/verify_art.txt"'
$V keys RUN , b v; $V keys RUN -l verify_art; $V keys RUN Enter
$V keys RUN , b
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/dashboard_art.lua
git status --porcelain       # in the checkout: nothing from the drive
```

End state seen: `40x27 cells (80x108 dots)`, `27 1107 .../ascii_art/verify_art.txt`, then
`shown=verify_art saved=verify_art`.

## Gotchas

- `cli` refuses any argument naming the checkout or the owner's nvim dirs. Pass `$CONFIG/...`
  inside `sh -c '...'` (single quotes, so it expands in the run's env).
- The default output dir is relative to the script's own location, which is why the snapshot
  copy writes into the run.
