# Git mappings

## Sub-features

- fugitive (loaded on `User InGitRepo`, fired at VimEnter/DirChanged inside a repo): `,gt` status,
  `,ga` `Git add .`, `,gc` commit (opens COMMIT_EDITMSG), `,gp` `Git push`, `,gf` Flog.
- gitsigns (`,gd` diffthis), gitlinker, git tag helpers (`,gts`, `,gtl`, `,gtc`, `,gtS`).
- lualine runs `git fetch origin` in the background for ahead/behind counts.
- git-conflict.nvim (`stryukovsky/git-conflict.nvim@63c5b42`: upstream `a1badcd` plus only the nvim 0.12
  deprecation fixes; loaded at VeryLazy): in a buffer with conflict markers, `co` ours, `ct` theirs, `cb` both,
  `c0` none, `]x`/`[x` next/previous conflict; `:GitConflictListQf` puts every conflict of the repo in the
  quickfix list. `config/git-conflict.lua` refreshes that list on `User GitConflictResolved` (a buffer's last
  conflict resolved).

## How to get to it (user POV)

In a repo: edit, `,ga`, `,gc`, write the message, `:wq`, `,gp`.

After a merge with conflicts: open the file, `co`/`ct` on each conflict (`]x` to the next), `:w`.

## Driving it with verify.sh

WORK's `origin` is a bare repo inside the run (tracked by `main`), so a push is real and lands
nowhere else:

```sh
$V keys RUN : e Space notes.md Enter
$V keys RUN G o; $V keys RUN --paste 'written in the run'; $V keys RUN Escape Escape; $V keys RUN , w
$V keys RUN , g a
$V keys RUN , g c
$V wait RUN 'vim.bo.filetype' gitcommit 15
$V keys RUN i; $V keys RUN --paste 'verify: commit through fugitive'; $V keys RUN Escape Escape
$V keys RUN : w q Enter
$V keys RUN , g p
git -C ~/.local/state/nvim-config-verify/RUN/remote.git log --oneline -1 main
```

End state seen: `remote main: <sha> verify: commit through fugitive` (same sha as WORK's HEAD). Also with
blink.cmp v1 (seeded `1104-133105-3259740`, `--live` `1104-133102-3257898`).

### Merge conflicts (git-conflict.nvim)

A real merge conflict made with the CLI in WORK: `conflict_a.txt` with two conflicts (top and bottom line),
`conflict_b.txt` with one. The quickfix probe lists the file names in the quickfix list.

```sh
QF='table.concat(vim.fn.uniq(vim.fn.sort(vim.tbl_map(function(i) return vim.fn.fnamemodify(vim.fn.bufname(i.bufnr), ":t") end, vim.fn.getqflist()))), ",")'
$V cli RUN bash -c 'set -e; printf "top\nkeep 1\nkeep 2\nkeep 3\nkeep 4\nkeep 5\nkeep 6\nkeep 7\nkeep 8\nbottom\n" >conflict_a.txt; printf "only\n" >conflict_b.txt; git add conflict_a.txt conflict_b.txt; git commit -qm "conflict: base"; git checkout -qb theirs; sed -i "s/^top\$/top theirs/; s/^bottom\$/bottom theirs/" conflict_a.txt; printf "only theirs\n" >conflict_b.txt; git commit -qam "conflict: theirs"; git checkout -q main; sed -i "s/^top\$/top ours/; s/^bottom\$/bottom ours/" conflict_a.txt; printf "only ours\n" >conflict_b.txt; git commit -qam "conflict: ours"; git merge -q theirs >/dev/null 2>&1 || true; git diff --name-only --diff-filter=U'
$V keys RUN : e Space conflict_a.txt Enter
$V wait RUN 'require("git-conflict").conflict_count(0)' 2 30
$V lua RUN 'vim.fn.maparg("co", "n") .. " " .. vim.fn.maparg("ct", "n") .. " " .. vim.fn.maparg("]x", "n")'
$V keys RUN : GitConflictListQf Enter
$V wait RUN "$QF" conflict_a.txt,conflict_b.txt 15
$V keys RUN : cclose Enter
$V keys RUN g g c o
$V wait RUN 'require("git-conflict").conflict_count(0)' 1 15
$V keys RUN g g ] x
$V lua RUN 'tostring(vim.fn.line(".") >= 10)'
$V keys RUN c t
$V wait RUN "$QF" conflict_b.txt 15
$V keys RUN : cclose Enter
$V keys RUN : w Enter
$V cli RUN cat conflict_a.txt
$V lua RUN @.claude/skills/verify-nvim-config/features/lua/deprecations.lua
```

End states seen (seeded `1104-133105-3259740` and `--live` `1104-133102-3257898`, nvim 0.12.6, fork `63c5b42`):
- the CLI prints `conflict_a.txt` and `conflict_b.txt`; `conflict_count` is `2`;
- the mappings are `<Plug>(git-conflict-ours) <Plug>(git-conflict-theirs) <Plug>(git-conflict-next-conflict)`;
- `:GitConflictListQf` lists `conflict_a.txt,conflict_b.txt`;
- `co` leaves `1` conflict, `]x` lands on line `>= 10` (`true`), and `ct` resolves the last one;
- `GitConflictResolved` refreshes the quickfix list to `conflict_b.txt`;
- the file on disk is `top ours`, `keep 1`…`keep 8`, `bottom theirs`, with no markers;
- the probe prints `0`.

Before (akinsho `v2.1.0`, seeded `1104-132444-3165892` and `--live` `1104-132441-3164010`): the same end states, and
`:checkhealth vim.deprecated` listed `vim.highlight is deprecated` (`git-conflict.lua:109`) and
`vim.validate is deprecated` (`git-conflict/colors.lua:12`) (the completion runs' `:checkhealth`, seeded
`1104-132438-3160384`, `--live` `1104-132435-3158849`). After, neither names `git-conflict.nvim`.

## Gotchas

- Never point WORK at a real remote. `GIT_SSH_COMMAND=/bin/false`, no credentials, and the
  namespace has no network, so a real push would fail anyway; the bare repo is what makes the
  success path provable.
- If the commit buffer stays in insert mode (a completion menu ate one Escape), `:wq` becomes
  message text. Always `Escape Escape`, then `wait` on the filetype going away if in doubt.
- Before `up` set the upstream (`push -u`), `,gp` ended in "The current branch main has no
  upstream branch." Fixtures now track `origin/main`.
- git-conflict finds conflicted files when a buffer is read (`BufRead` in a cwd with `.git`) and through a
  watcher on `.git`. Make the conflict **before** opening the file, then `wait` on `conflict_count`. The
  `co`/`ct`/`]x` mappings exist only in a buffer where conflicts were detected.
- `:GitConflictListQf` and the Resolved refresh run `copen`, which moves the cursor into the quickfix window.
  Use `:cclose` before pressing a mapping or `:w`.
- The conflict journey leaves WORK mid-merge (`conflict_b.txt` unresolved). Run it last, or in its own run.
- Do not use `version = "*"` on the fork: forks carry upstream's tags, so it would resolve to the deprecated
  `v2.1.0`. The spec pins `commit`.
