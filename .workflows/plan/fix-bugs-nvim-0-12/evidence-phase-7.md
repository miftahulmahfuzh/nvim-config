## Phase 7

R5: no per-start `get_package("gofumpt"):install()`. Installed nvim 0.11.5, harness `.claude/skills/verify-nvim-config`.
Base = `b95f249` (phase-6 tip; base files swapped in per execution rule 2), fix = `874410c` (rebased onto the set branch at `cc43485`, carrying phase 1).
Evidence dirs are `~/.local/state/nvim-config-verify/<RUN>/evidence`; `mason.log` is `<RUN>/xdg/state/nvim/mason.log`.

- J1 before seeded: RUN=1104-113136-2342409 ~/.local/state/nvim-config-verify/1104-113136-2342409/evidence, `wait` for `Installation failed for Package(name=gofumpt)` ok; `Executing installer for Package(name=gofumpt)` = 1, `Installation failed` = 1, `Failed to update registries` = 2
- J1 before live: RUN=1104-113140-2344840 ~/.local/state/nvim-config-verify/1104-113140-2344840/evidence, `wait` ok; executing = 1, failed = 1, registries = 1
- J3 before (seeded, same run as J1): `01-headless-_lua_local_r___require__mason-registry__.txt` = `installing=gofumpt` + `[mason.nvim] Neovim exited while the following packages were installing. Installation was aborted. - gofumpt`
- J2 after seeded: RUN=1104-113158-2349813 ~/.local/state/nvim-config-verify/1104-113158-2349813/evidence, after a 15 s window: executing = 0, failed = 0, `InstallRunner.*gofumpt` = 0, registries = 1 (refresh only); `is_installed()` = true (`02-lua-*`); `test -x .../mason/bin/gofumpt` exit 0; doctor exit 0, `messages ok`, `seed ok`
- J2 after live: RUN=1104-113223-2357110 ~/.local/state/nvim-config-verify/1104-113223-2357110/evidence, executing = 0, failed = 0, registries = 1; `is_installed()` = true; `mason/bin/gofumpt` present; doctor exit 0, `live ok`, `messages ok`
- J3 after (seeded, RUN=1104-113158-2349813): `03-headless-_lua_local_r___require__mason-registry__.txt` = `installing=` (empty), no abort line
- J4 after live (missing gofumpt): RUN=1104-113258-2368613 ~/.local/state/nvim-config-verify/1104-113258-2368613/evidence, executing = 0 before the `rm`; after `rm` + `sync`: executing = 1, failed = 1 (`go` cannot fetch `mvdan.cc/gofumpt` offline); `02-lua-*` notify history = `{ { "gofumpt: installing" }, { "gofumpt: failed to install" } }`; `:messages` empty (`01-lua-*`)
- Neighbour (Go format-on-save) after seeded: RUN=1104-113158-2349813 `07-cli-git_diff_main.go.txt` = `-	var x = a+b` / `+	x := a + b`, `+	fmt.Println(add(1, 2))`
- Neighbour after live: RUN=1104-113223-2357110 `06-cli-git_diff_main.go.txt`, same diff
- Invariant 1 on the rebased fix commit (clean tree): seeded RUN=1104-113349-2387106 and live RUN=1104-113408-2398102, executing = 0, failed = 0, doctor exit 0 (`code ok`, `seed ok` / `live ok`, `messages ok`)

Build check: `nvim --headless -u NONE` `loadfile` of `lua/plugin_specs.lua` and `scripts/seed.lua` exit 0; `stylua --check` (Mason's stylua) exit 0 on both. `git grep -n 'get_package("gofumpt")'` matches only `docs/`, `.workflows/` and startup.md's historical parenthesis.
Decision: the plan's journey text said mason-tool-installer's `gofumpt: installing` lands in `:messages`; measured, it lands in nvim-notify's history and `:messages` stays empty. startup.md documents the measured end state (`require("notify").history()`).
Proof: verified-first-pass (every journey passed on the first run, no fix iterations).
