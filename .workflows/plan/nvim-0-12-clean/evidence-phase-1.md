# Phase 1 evidence: verify.sh sync keeps run_path, doctor checks PATH, Go tools on run PATH

Base for "before": `9cea538`'s verify skill, extracted with `git archive` to
`~/.local/state/nvim-config-verify/phase1-base-9cea538/` and run from the worktree root.
Evidence root: `~/.local/state/nvim-config-verify/<RUN>/evidence/`.

| Journey | Mode | Script | Run | Result | Evidence |
|---|---|---|---|---|---|
| J1 before: PATH after sync, doctor | live | base | `1104-130336-2985618` | `PATH-AFTER-SYNC: DIFF` (P2 = caller's PATH: `~/.opencode/bin`, `~/.cargo/bin`, `/mnt/c/...`); `doctor-exit=0`, `doctor-path-lines=0` | `01-lua-vim.env.PATH.txt` vs `02-lua-vim.env.PATH.txt`, `doctor-after-sync.txt` |
| J1 before: checkhealth go after sync | live | base | `1104-130336-2985618` | `health-ERROR=0 health-missing=0`: masked, the leaked caller PATH has the Go bin (see J1b) | `05-lua-table.concat_vim.api.nvim_buf_get_lines_.txt` |
| J1b before: checkhealth go, no sync | live | base | `1104-130357-2992108` | `health-ERROR=1 health-missing=19`, `ENOENT ... 'golangci-lint'` | `03-lua-table.concat_vim.api.nvim_buf_get_lines_.txt` |
| J2 before: checkhealth go (no sync), then PATH after sync, doctor | seeded | base | `1104-130404-2996131` | `health-ERROR=1 health-missing=19`; `PATH-AFTER-SYNC: DIFF` with caller dirs; `doctor-exit=0`, `doctor-path-lines=0` | `03-lua-table.concat_vim.api.nvim_buf_get_lines_.txt`, `05-` vs `06-lua-vim.env.PATH.txt`, `doctor-after-sync.txt` |
| J3 after: PATH kept, doctor path ok, checkhealth go, gofumpt/gopls from Mason, Go format on save | live | new | `1104-130537-3002073` | `GOBIN-DIR-ON-RUN-PATH: yes`, `PATH-AFTER-SYNC: SAME`, `PATH-IS-RUN-PATH: yes`, `doctor-exit=0` `path ok`; gofumpt/gopls under `mason/bin`, lint under `~/.gvm/pkgsets/go1.25.7/global/bin`; diff `-	var x = a+b` / `+	x := a + b`; `health-ERROR=0 health-missing=0`, `golangci-lint version: 2.10`; `doctor-end-exit=0` `path ok`, `messages ok` | `01-`/`02-lua-vim.env.PATH.txt`, `doctor-after-sync.txt`, `04-lua-__gofumpt___vim.fn.exepath__gofumpt____g.txt`, `07-cli-git_diff_main.go.txt`, `09-lua-table.concat_vim.api.nvim_buf_get_lines_.txt`, `doctor-end.txt` |
| J4 after: same | seeded | new | `1104-130602-3008952` | same as J3 (13 environment warnings, identical list) | same files as J3 |
| J5 fault injection: doctor path FAIL | seeded | new | `1104-130609-3013951` | first `path     ok`; after `:/leak/bin`: `path     FAIL ...:/leak/bin (run_path: ...)`, `doctor-exit=1` | `01-lua-vim.fn.setenv__PATH___vim.env.PATH_..___.txt`, `doctor-leak.txt` |
| Neighbor: `--bare` doctor | bare | new | `1104-130614-3017536` | `doctor-exit=0`, `path     ok` | `doctor-bare.txt` |

Analysis repro (live, base, earlier): `1104-121901-2809686` `evidence/16-lua-vim.env.PATH.txt` vs
`evidence/17-lua-vim.env.PATH.txt`; original `1104-112534-2226714`.

Notes:
- Drift from the plan's J1 script: on the base, `:checkhealth go` run *after* `sync` shows no ERROR,
  because `sync` leaked the caller's PATH, Go bin included. J1b/J2 run it before `sync` to show the
  base failure; J1's after-sync PATH diff is unchanged.
- Remaining `:checkhealth go` warnings (both modes, after): `GOBIN is not in PATH`, six optional
  treesitter parsers, `Some binaries are not installed`, `nvim-dap`/`nvim-dap-ui`/`nvim-dap-virtual-text:
  not installed/loaded`, `Not all plugin installed`, `nvim-treesitter main module loaded, WIP`. The
  three dap lines and `Not all plugin installed` were not in the plan's handoff list; phase 4's
  allow-list gets them.
- `shellcheck` is not installed on this machine; `bash -n` passes.
