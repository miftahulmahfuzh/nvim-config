# Git mappings

## Sub-features

- fugitive (loaded on `User InGitRepo`, fired at VimEnter/DirChanged inside a repo): `,gt` status,
  `,ga` `Git add .`, `,gc` commit (opens COMMIT_EDITMSG), `,gp` `Git push`, `,gf` Flog.
- gitsigns (`,gd` diffthis), gitlinker, git tag helpers (`,gts`, `,gtl`, `,gtc`, `,gtS`).
- lualine runs `git fetch origin` in the background for ahead/behind counts.

## How to get to it (user POV)

In a repo: edit, `,ga`, `,gc`, write the message, `:wq`, `,gp`.

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

End state seen: `remote main: <sha> verify: commit through fugitive` (same sha as WORK's HEAD).

## Gotchas

- Never point WORK at a real remote. `GIT_SSH_COMMAND=/bin/false`, no credentials, and the
  namespace has no network, so a real push would fail anyway; the bare repo is what makes the
  success path provable.
- If the commit buffer stays in insert mode (a completion menu ate one Escape), `:wq` becomes
  message text. Always `Escape Escape`, then `wait` on the filetype going away if in doubt.
- Before `up` set the upstream (`push -u`), `,gp` ended in "The current branch main has no
  upstream branch." Fixtures now track `origin/main`.
