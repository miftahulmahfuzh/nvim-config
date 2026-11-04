#!/usr/bin/env bash
# verify.sh: launch, drive and tear down a throwaway Neovim (this repo's config) inside a throwaway
# tmux server (this repo's .tmux.conf + .tmux.conf.local), with evidence.
#
# Every run gets its own XDG config/data/state/cache/runtime dirs, its own HOME, its own tmux
# socket, its own nvim socket and its own network namespace (no network at all: `unshare -n`).
# The config is a snapshot of the CURRENT checkout's working tree; plugins and Mason tools are a
# copy of the shared verify seed (built online, once, by `seed`), or with --live a copy of the
# owner's live environment. The owner's ~/.config/nvim, ~/.local/share/nvim and ~/.tmux.conf are
# only ever READ (by --live and `live`); ~/.local/state/nvim, the rest of ~/.cache/nvim and the
# owner's tmux server are never touched. Nothing the owner has is ever written.
#
#   verify.sh seed [--update]           ONLINE: build/refresh the shared plugin+Mason seed from this checkout
#   verify.sh up [--live|--bare] [--size CxR]  start nvim in a run-owned tmux server; prints RUN= EVIDENCE= WORK=
#                                       (default) plugins + Mason from the verify seed, the seed's lock
#                                       --live: a COPY of the owner's live plugins, Mason tools, lock and oh-my-tmux
#                                       --bare: empty data dir (no plugins, no Mason): a fresh machine offline
#   verify.sh live [RUN]                read-only drift report: the checkout vs the live ~/.config/nvim
#   verify.sh doctor RUN                is this run worth driving? (read-only)
#   verify.sh keys RUN [-l] KEY...      type into nvim's pane (tmux send-keys), then save the screen
#   verify.sh keys RUN --paste TEXT     paste TEXT into the pane (bracketed paste), then save the screen
#   verify.sh tmux RUN KEY...           press keys on the run's attached tmux client (prefix bindings)
#   verify.sh screen RUN [NAME]         save the visible pane text (and an .ansi copy)
#   verify.sh lua RUN 'EXPR|CHUNK|@F'   evaluate Lua (or the probe file F) in the running nvim; prints the result
#   verify.sh wait RUN 'EXPR' EXPECTED [SECS]  poll a Lua expression until tostring(value) == EXPECTED
#   verify.sh panes RUN                 tmux sessions/windows/panes of the run's server
#   verify.sh headless RUN [NVIM_ARGS]  one-shot `nvim --headless` with the run's config and dirs
#   verify.sh cli RUN CMD...            run a command in the run's namespace and env, cwd = WORK
#   verify.sh sync RUN                  re-snapshot the working tree's config and restart nvim in the pane
#   verify.sh note RUN "TEXT"           append a line to the run's evidence log
#   verify.sh down RUN|--all            stop everything the run started; evidence stays
#   verify.sh ls                        runs with state, mode and evidence count
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(dirname "$HERE")"
VERIFY_HOME="${VERIFY_HOME:-$HOME/.local/state/nvim-config-verify}"
SEED="$VERIFY_HOME/.seed"
NVIM_BIN="${VERIFY_NVIM:-/opt/nvim-linux-x86_64/bin/nvim}"
PY="$(command -v python3 || true)"
NODE="$(command -v node || true)"
GO="$(command -v go || true)"
CARGO="$(command -v cargo || true)"
REAL_HOME="$HOME"
LIVE_CONFIG="${VERIFY_LIVE_CONFIG:-$HOME/.config/nvim}"   # the owner's live config: read, never written
LIVE_DATA="${VERIFY_LIVE_DATA:-$HOME/.local/share/nvim}"
LIVE_TMUX_CONF="$(readlink -f "$HOME/.tmux.conf" 2>/dev/null || echo "$HOME/.tmux.conf")"

die() { echo "verify: $*" >&2; exit 1; }

repo_root() {
  local r
  r="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run from inside an nvim-config checkout"
  [ -f "$r/init.lua" ] && [ -f "$r/lua/plugin_specs.lua" ] || die "$r is not the nvim-config repo"
  echo "$r"
}

run_dir() {
  local run=${1:-}
  [ -n "$run" ] || die "missing RUN id (see: verify.sh ls)"
  [ -d "$VERIFY_HOME/$run" ] || die "no run $run under $VERIFY_HOME"
  echo "$VERIFY_HOME/$run"
}

meta() { sed -n "s/^$2=//p" "$1/meta" | tail -1; }

next_evidence() {
  local dir=$1/evidence kind=$2 slug=$3 n
  n=$(find "$dir" -maxdepth 1 -type f -name '[0-9][0-9]-*.txt' ! -name '00-*' | wc -l)
  printf '%s/%02d-%s-%s.txt' "$dir" $((n + 1)) "$kind" "$(printf %s "$slug" | tr -c 'a-zA-Z0-9_.-' '_' | cut -c1-40)"
}

# What the snapshot copies: the working tree minus git metadata, the gitignored lock and caches.
snapshot() {
  rsync -a --delete --itemize-changes --exclude /.git --exclude /.claude --exclude /lazy-lock.json \
    --exclude __pycache__/ --exclude '*_code_analyzer.md' "$1/" "$2/"
}

tree_hash() {
  (cd "$1" && find . \( -path ./.git -o -path ./.claude -o -name __pycache__ -o -name lazy-lock.json -o -name '*_code_analyzer.md' \) -prune \
    -o -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16)
}

# PATH for every process the run owns: nvim's own directory, the tools below and the system dirs.
# No per-user tool dir (~/.cargo, ~/.local/bin, a CLI installed under ~), nothing the caller exported.
run_path() {
  local p t d
  p="$(dirname "$NVIM_BIN")"
  # The interpreters Mason's servers need, plus the external tools the config shells out to (fzf for
  # fzf-lua, rg for live_grep, jq for the JSON prettify mapping, ctags for vista), each by its own
  # directory, so nothing else from the caller's PATH (cargo, ~/.local/bin, other dirs under ~) comes along.
  for t in "$PY" "$NODE" "$GO" fzf rg jq ctags; do
    t="$(command -v "$t" 2>/dev/null || true)"; [ -n "$t" ] || continue
    d="$(dirname "$t")"
    case ":$p:/usr/local/bin:/usr/bin:/bin:" in *":$d:"*) ;; *) p="$p:$d" ;; esac
  done
  echo "$p:/usr/local/bin:/usr/bin:/bin"
}

# env -i plus the run's own values only. Git can never reach a credential (no global config, no
# askpass, no ssh) and the network namespace refuses everything anyway.
run_env() {
  local dir=$1
  echo env -i PATH="$(run_path)" HOME="$dir/home" USER="$(id -un)" SHELL=/bin/bash \
    TERM=xterm-256color LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=Asia/Jakarta \
    XDG_CONFIG_HOME="$dir/xdg/config" XDG_DATA_HOME="$dir/xdg/data" XDG_STATE_HOME="$dir/xdg/state" \
    XDG_CACHE_HOME="$dir/xdg/cache" XDG_RUNTIME_DIR="$dir/xdg/runtime" TMPDIR="$dir/tmp" \
    GIT_CONFIG_GLOBAL="$dir/home/.gitconfig" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
    GIT_ASKPASS=/bin/false SSH_ASKPASS=/bin/false GIT_SSH_COMMAND=/bin/false \
    GOPATH="$dir/tmp/go" GOMODCACHE="$dir/tmp/go/mod" GOCACHE="$dir/tmp/go/cache" GOFLAGS=-mod=mod GOTOOLCHAIN=local \
    npm_config_cache="$dir/tmp/npm" CONFIG="$dir/xdg/config/nvim" WORK="$dir/work"
}

tmx() { tmux -S "$1/tmux.sock" "${@:2}"; }

server_pid() { tmx "$1" display -p '#{pid}' 2>/dev/null || true; }

# Run a command inside the run's network + user namespace (joined through the tmux server).
in_ns() {
  local dir=$1 pid; shift
  pid="$(server_pid "$dir")"
  [ -n "$pid" ] || die "the run's tmux server is not running"
  nsenter -t "$pid" -U -n --preserve-credentials "$@"
}

# Every process in the run's network namespace: that is exactly what the run started.
ns_pids() {
  local ns=$1 p
  for p in /proc/[0-9]*; do
    [ "$(readlink "$p/ns/net" 2>/dev/null || true)" = "$ns" ] && echo "${p#/proc/}"
  done
  return 0
}

nvim_expr() {
  local dir=$1 expr=$2
  # shellcheck disable=SC2046
  timeout 10 $(run_env "$dir") "$NVIM_BIN" --clean --headless --server "$(nvim_sock "$dir")" --remote-expr "$expr" 2>&1
}

lua_eval() {
  local dir=$1 code=$2 f
  mkdir -p "$dir/tmp/lua"
  f="$(mktemp "$dir/tmp/lua/XXXXXX.lua")"
  printf '%s\n' "$code" >"$f"
  # An expression is compiled as `return <expr>`; anything that does not compile that way (a chunk
  # with its own `return`) runs as written. Tables come back through vim.inspect.
  nvim_expr "$dir" "luaeval('(function() local src = table.concat(vim.fn.readfile(\"$f\"), \"\\n\"); local fn, err = loadstring(\"return \" .. src); if not fn then fn, err = loadstring(src) end; if not fn then return \"lua error: \" .. err end; local ok, v = pcall(fn); if not ok then return \"lua error: \" .. tostring(v) end; if type(v) == \"table\" then return vim.inspect(v) end; return tostring(v) end)()')"
}

nvim_ready() {
  [ "$(lua_eval "$1" 'vim.v.vim_did_enter == 1 and (package.loaded["fzf-lua"] ~= nil or vim.g.verify_bare == 1)' 2>/dev/null || true)" = true ]
}

seed_lock() { mkdir -p "$VERIFY_HOME"; exec 9>"$VERIFY_HOME/.seed.lock"; flock "$@" 9; }

seed_manifest() { (cd "$SEED/data" && find . -printf '%p %s %T@\n' | LC_ALL=C sort | sha256sum | cut -c1-16); }

cmd_seed() {
  local update=0
  [ "${1:-}" = --update ] && update=1
  local root; root="$(repo_root)"
  seed_lock -x
  mkdir -p "$SEED"/{config/nvim,data,state,cache,home,tmp,runtime}
  chmod 700 "$SEED/runtime"
  snapshot "$root" "$SEED/config/nvim" >/dev/null
  # The lock: the seed's own once it has one; the first seed starts from the owner's LIVE lock (read
  # only), so seeded runs install the plugin commits the owner actually runs. --update = latest.
  local lock_from=seed
  if [ -f "$SEED/lazy-lock.json" ]; then cp "$SEED/lazy-lock.json" "$SEED/config/nvim/lazy-lock.json"
  elif [ -f "$LIVE_CONFIG/lazy-lock.json" ]; then cp "$LIVE_CONFIG/lazy-lock.json" "$SEED/config/nvim/lazy-lock.json"; lock_from="live@$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse --short HEAD)"
  else rm -f "$SEED/config/nvim/lazy-lock.json"; lock_from=none; fi
  [ "$update" = 1 ] && { rm -f "$SEED/config/nvim/lazy-lock.json"; lock_from=latest; }
  rm -f "$SEED/lock.orig.json"; [ -f "$SEED/config/nvim/lazy-lock.json" ] && cp "$SEED/config/nvim/lazy-lock.json" "$SEED/lock.orig.json"
  [ -d "$SEED/data" ] && chmod -R u+w "$SEED/data"
  : >"$SEED/seed.log"
  local path="$(dirname "$NVIM_BIN")"
  for t in "$PY" "$NODE" "$GO"; do [ -n "$t" ] && path="$path:$(dirname "$t")"; done
  # cargo is deliberately NOT on PATH: blink.cmp's `cargo build --release` would make rustup install
  # a nightly toolchain into the owner's ~/.rustup. blink downloads its prebuilt fuzzy library instead.
  echo "verify: seeding $SEED/data from $root (online: GitHub, npm, PyPI, Go proxy; this takes minutes)" >&2
  local rc=0
  env -i PATH="$path:/usr/bin:/bin" HOME="$SEED/home" USER="$(id -un)" SHELL=/bin/bash TERM=xterm-256color \
    LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    XDG_CONFIG_HOME="$SEED/config" XDG_DATA_HOME="$SEED/data" XDG_STATE_HOME="$SEED/state" \
    XDG_CACHE_HOME="$SEED/cache" XDG_RUNTIME_DIR="$SEED/runtime" TMPDIR="$SEED/tmp" \
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/bin/false \
    SSH_ASKPASS=/bin/false GIT_SSH_COMMAND=/bin/false \
    GOPATH="$SEED/tmp/go" GOMODCACHE="$SEED/tmp/go/mod" GOCACHE="$SEED/tmp/go/cache" GOTOOLCHAIN=auto \
    npm_config_cache="$SEED/tmp/npm" LIVE_LAZY="$LIVE_DATA/lazy" SEED_LOCK_ORIG="$SEED/lock.orig.json" SEED_LOG="$SEED/seed.log" SEED_UPDATE=$update \
    timeout 1800 "$NVIM_BIN" --headless -c "luafile $HERE/seed.lua" </dev/null >"$SEED/nvim.out" 2>&1 || rc=$?
  cat "$SEED/seed.log"
  # The seed's lock = the commits actually checked out (lazy's rewrite misses the pins seed.lua made).
  if [ -f "$SEED/lock.orig.json" ]; then cp "$SEED/lock.orig.json" "$SEED/lazy-lock.json"
  elif [ -f "$SEED/config/nvim/lazy-lock.json" ]; then cp "$SEED/config/nvim/lazy-lock.json" "$SEED/lazy-lock.json"; fi
  # Files in the seed are read-only so a run's hard-linked copy can never write through into it
  # (an in-place write fails with EACCES in the run instead). Directories stay writable.
  find "$SEED/data" -type f -perm /222 -exec chmod a-w {} +
  {
    echo "repo=$root"
    echo "head=$(git -C "$root" rev-parse --short HEAD)"
    echo "seeded=$(date -Iseconds)"
    echo "lock_from=$lock_from"
    echo "plugins=$(find "$SEED/data/nvim/lazy" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    echo "mason=$(find "$SEED/data/nvim/mason/packages" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    echo "manifest=$(seed_manifest)"
  } >"$SEED/meta"
  cat "$SEED/meta"
  grep -q '^done' "$SEED/seed.log" || die "seed did not finish (exit $rc; see $SEED/nvim.out)"
  ! grep -q '^FAIL' "$SEED/seed.log" || die "seed finished with failures (above)"
}

# Each nvim start gets its own socket (nvim-N.sock): on a restart the old nvim removes its socket
# while the new one is already listening on the same path, which left a dead socket behind.
nvim_sock() { echo "$1/nvim-$(meta "$1" nvim_gen).sock"; }

start_nvim_cmd() {
  # The pane runs the user's real entry point: `nvim`, from WORK, with a socket the driver reads.
  echo "$NVIM_BIN --listen $(nvim_sock "$1")"
}

# Absolute symlinks and Mason's wrapper scripts name the data dir they were installed into; point
# them at the run's copy, so a run never executes (or lets an LSP write logs into) the source.
repoint_data() {
  local dir=$1 from=$2 to="$1/xdg/data"
  find "$dir/xdg/data/nvim" -type l -lname "$from/*" -print0 | while IFS= read -r -d '' l; do
    ln -sfn "$(readlink "$l" | sed "s#^$from#$to#")" "$l"
  done
  # Every text file under mason/ (bin/ AND packages/*: lua-language-server's launcher script names its
  # libexec by absolute path, and lua_ls writes log/ and meta/ next to the binary it runs).
  { grep -rIlF --null "$from" "$dir/xdg/data/nvim/mason" 2>/dev/null </dev/null || true; } | while IFS= read -r -d '' f; do
    [ -L "$f" ] && continue
    # A new file (sed + rename), never an in-place edit: f may be a hard link into the seed.
    sed "s#$from#$to#g" "$f" >"$f.tmp" && chmod "$(stat -c %a "$f")" "$f.tmp" && chmod u+w "$f.tmp" && mv -f "$f.tmp" "$f"
  done
  return 0
}

# Read-only fingerprint of the owner's live dirs (names, sizes, mtimes; contents are never hashed
# into anything that could change them). up records it, doctor and down compare.
live_fingerprint() {
  { find "$LIVE_CONFIG" -path "$LIVE_CONFIG/.git" -prune -o -printf '%p %s %T@\n'
    find "$LIVE_DATA/lazy" "$LIVE_DATA/mason" -maxdepth 2 -printf '%p %s %T@\n'
    stat -c '%n %s %Y' "$LIVE_TMUX_CONF" "$REAL_HOME/.tmux.conf.local"
  } 2>/dev/null | LC_ALL=C sort | sha256sum | cut -c1-16
}

cmd_up() {
  local mode=seeded size=160x45
  while [ $# -gt 0 ]; do
    case "$1" in
      --bare) mode=bare ;;
      --live) mode=live ;;
      --size) size=${2:?--size COLSxROWS}; shift ;;
      *) die "up: unknown flag $1" ;;
    esac
    shift
  done
  local root run dir cols rows
  root="$(repo_root)"
  cols=${size%x*}; rows=${size#*x}
  command -v unshare >/dev/null && command -v nsenter >/dev/null || die "unshare/nsenter (util-linux) are required for the network fence"
  unshare --map-current-user -n true 2>/dev/null || die "this kernel refuses unprivileged network namespaces; no fence, no run"
  case "$mode" in
    seeded) [ -f "$SEED/meta" ] || die "no seed yet: run 'verify.sh seed' once (online), then up" ;;
    live) [ -d "$LIVE_DATA/lazy" ] && [ -f "$LIVE_CONFIG/init.lua" ] || die "no live environment at $LIVE_CONFIG / $LIVE_DATA" ;;
  esac
  run="$(date +%m%d-%H%M%S)-$$"
  dir="$VERIFY_HOME/$run"
  mkdir -p "$dir"/{evidence,xdg/config/nvim,xdg/data/nvim,xdg/state,xdg/cache/nvim,xdg/runtime,home,tmp}
  chmod 700 "$dir/xdg/runtime"
  snapshot "$root" "$dir/xdg/config/nvim" >/dev/null
  local filled=""
  case "$mode" in
    seeded)
      seed_lock -s
      [ -f "$SEED/lazy-lock.json" ] && cp "$SEED/lazy-lock.json" "$dir/xdg/config/nvim/lazy-lock.json"
      # Hard links: under a second instead of a 740 MB copy. Seed files are read-only (see seed), so
      # nothing a run does can write through.
      rmdir "$dir/xdg/data/nvim"
      cp -al "$SEED/data/nvim" "$dir/xdg/data/nvim"
      repoint_data "$dir" "$SEED/data"
      flock -u 9
      ;;
    live)
      # The checkout's update on top of the owner's live environment: the live lock, the live
      # plugins and Mason tools, the live oh-my-tmux. Full copies (never hard links: the owner's
      # files are writable, so a link would let the run write into them). Only lazy/, mason/ and
      # rplugin.vim: the rest of ~/.local/share/nvim (avante/, backup/, telescope_history) is
      # private state a verify run has no use for.
      echo "live_fp=$(live_fingerprint)" >"$dir/live.before"
      cp "$LIVE_CONFIG/lazy-lock.json" "$dir/xdg/config/nvim/lazy-lock.json"
      cp -a "$LIVE_DATA/lazy" "$LIVE_DATA/mason" "$dir/xdg/data/nvim/"
      [ -f "$LIVE_DATA/rplugin.vim" ] && cp -a "$LIVE_DATA/rplugin.vim" "$dir/xdg/data/nvim/"
      repoint_data "$dir" "$(dirname "$LIVE_DATA")"
      # A plugin the update adds is not in the live dirs yet (live nvim would fetch it online on
      # the next start). Take it from the verify seed, and say so.
      if [ -d "$SEED/data/nvim/lazy" ]; then
        local p
        for p in "$SEED/data/nvim/lazy"/*/; do
          p="$(basename "$p")"
          [ -e "$dir/xdg/data/nvim/lazy/$p" ] && continue
          grep -q "\"$p\"" "$dir/xdg/config/nvim/lua/plugin_specs.lua" "$SEED/lazy-lock.json" 2>/dev/null || continue
          cp -a "$SEED/data/nvim/lazy/$p" "$dir/xdg/data/nvim/lazy/" && chmod -R u+w "$dir/xdg/data/nvim/lazy/$p"
          filled="$filled $p"
        done
      fi
      [ -f "$REAL_HOME/.cache/nvim/dashboard_ascii_art.txt" ] && cp "$REAL_HOME/.cache/nvim/dashboard_ascii_art.txt" "$dir/xdg/cache/nvim/"
      ;;
  esac
  # HOME holds the tmux config under test (oh-my-tmux finds it as ~/.tmux.conf, then .local).
  # Live mode keeps the oh-my-tmux the owner's ~/.tmux.conf really points at; the checkout's
  # .tmux.conf.local is the change under test either way.
  if [ "$mode" = live ]; then cp "$LIVE_TMUX_CONF" "$dir/home/.tmux.conf"; else cp "$dir/xdg/config/nvim/.tmux.conf" "$dir/home/.tmux.conf"; fi
  cp "$dir/xdg/config/nvim/.tmux.conf.local" "$dir/home/.tmux.conf.local"
  printf '[user]\n\tname = verify\n\temail = verify@localhost\n[init]\n\tdefaultBranch = main\n[safe]\n\tdirectory = *\n' >"$dir/home/.gitconfig"
  # WORK: the fixture project nvim edits, a git repo whose origin is a bare repo in the run (so
  # `<leader>gp` pushes somewhere provable and nowhere real).
  cp -a "$SKILL/features/fixtures/work" "$dir/work"
  git init -q --bare "$dir/remote.git"
  # shellcheck disable=SC2046
  (cd "$dir/work" && $(run_env "$dir") sh -c 'git init -q && git add -A && git commit -qm "fixture: initial" && git remote add origin "$0" && git push -q -u origin main' "$dir/remote.git")
  {
    echo "repo=$root"
    echo "head=$(git -C "$root" rev-parse --short HEAD)"
    echo "dirty=$(git -C "$root" status --porcelain | wc -l)"
    echo "tree=$(tree_hash "$root")"
    echo "mode=$mode"
    echo "seed_manifest=$([ "$mode" = seeded ] && meta "$SEED" manifest || echo none)"
    if [ "$mode" = live ]; then
      echo "live_head=$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse --short HEAD)"
      echo "live_dirty=$(git -C "$LIVE_CONFIG" --no-optional-locks status --porcelain | wc -l)"
      echo "filled_from_seed=${filled# }"
      sed -n 's/^live_fp=/live_fp=/p' "$dir/live.before"
    fi
    echo "size=$size"
    echo "nvim_gen=1"
  } >"$dir/meta"

  # The tmux server (and everything it spawns: nvim, LSP servers, shells) lives in a fresh network
  # namespace: no route anywhere, loopback down. setsid + closed fds so no caller's pipe is held.
  # shellcheck disable=SC2046
  setsid unshare --map-current-user -n $(run_env "$dir") \
    tmux -S "$dir/tmux.sock" -f "$dir/home/.tmux.conf" new-session -d -s main -n nvim -x "$cols" -y "$rows" \
    -c "$dir/work" "$(start_nvim_cmd "$dir")" </dev/null >"$dir/tmux-start.log" 2>&1 || {
      cat "$dir/tmux-start.log" >&2; die "tmux failed to start (verify.sh down $run)"; }
  local pid=""
  for _ in $(seq 1 40); do pid="$(server_pid "$dir")"; [ -n "$pid" ] && break; sleep 0.25; done
  [ -n "$pid" ] || die "tmux server never answered (verify.sh down $run)"
  echo "netns=$(readlink "/proc/$pid/ns/net")" >>"$dir/meta"
  echo "server_pid=$pid" >>"$dir/meta"
  tmx "$dir" set-option -t main remain-on-exit on >/dev/null
  # A real client attached through a pty (inside the namespace), so prefix bindings can be pressed
  # with `send-keys -K`. Its output goes to /dev/null: nothing reaches the caller's terminal.
  # shellcheck disable=SC2046
  in_ns "$dir" setsid $(run_env "$dir") script -qfec "stty rows $rows cols $cols; tmux -S $dir/tmux.sock attach -t main" /dev/null \
    </dev/null >/dev/null 2>&1 &
  [ "$mode" = bare ] && echo "verify: --bare: no plugins, no Mason; nvim faces a fresh machine with no network" >&2
  [ -n "$filled" ] && echo "verify: --live: not in the live dirs, taken from the seed:$filled (live nvim would fetch these online on its next start)" >&2

  # Usable = nvim answers on its socket, VimEnter ran, and lazy's VeryLazy plugins (fzf-lua) loaded.
  local ok=0 dead=""
  for _ in $(seq 1 120); do
    dead="$(tmx "$dir" display -p -t main '#{pane_dead}' 2>/dev/null || true)"
    if [ "$dead" = 1 ]; then break; fi
    if [ -S "$(nvim_sock "$dir")" ]; then
      if [ "$mode" = bare ] && [ "$(lua_eval "$dir" 'vim.v.vim_did_enter' 2>/dev/null || true)" = 1 ]; then ok=1; break; fi
      nvim_ready "$dir" && { ok=1; break; }
    fi
    sleep 0.5
  done
  sleep 0.5
  local scr; scr="$dir/evidence/00-up-screen.txt"
  tmx "$dir" capture-pane -p -t main >"$scr" 2>/dev/null || true
  if [ "$ok" != 1 ]; then
    cat "$scr" >&2
    [ "$dead" = 1 ] && die "nvim exited during startup (screen above; verify.sh down $run)"
    [ "$mode" = bare ] || die "nvim not usable after 60s (screen above; verify.sh down $run)"
  fi
  lua_eval "$dir" 'vim.fn.execute("messages")' >"$dir/evidence/00-up-messages.txt" 2>&1 || true
  if [ -s "$dir/evidence/00-up-messages.txt" ] && grep -qE 'E[0-9]+:|Error|error' "$dir/evidence/00-up-messages.txt"; then
    echo "verify: startup :messages contain errors:" >&2
    sed 's/^/verify:   /' "$dir/evidence/00-up-messages.txt" >&2; echo >&2
  fi
  echo "RUN=$run"
  echo "EVIDENCE=$dir/evidence"
  echo "WORK=$dir/work"
  echo "MODE=$(meta "$dir" mode)"
}

cmd_doctor() {
  local dir run pid ns root ok=1
  dir="$(run_dir "${1:-}")"; run="$(basename "$dir")"
  root="$(meta "$dir" repo)"; ns="$(meta "$dir" netns)"
  pid="$(server_pid "$dir")"
  if [ -n "$pid" ] && [ "$pid" = "$(meta "$dir" server_pid)" ]; then echo "tmux     ok   server pid $pid on $dir/tmux.sock"; else echo "tmux     FAIL server not answering on the run's socket"; ok=0; fi
  if [ -n "$pid" ] && [ "$(readlink "/proc/$pid/ns/net" 2>/dev/null || true)" = "$ns" ] && [ "$ns" != "$(readlink /proc/self/ns/net)" ]; then
    echo "netns    ok   server in $ns (not the host's $(readlink /proc/self/ns/net)); $(ns_pids "$ns" | wc -l) processes inside"
  else
    echo "netns    FAIL server not in the run's own network namespace"; ok=0
  fi
  local dead; dead="$(tmx "$dir" display -p -t main '#{pane_dead} #{pane_current_command}' 2>/dev/null || true)"
  echo "pane     info main: dead/cmd = ${dead:-?}"
  if nvim_ready "$dir"; then echo "nvim     ok   answers on $(basename "$(nvim_sock "$dir")"), VimEnter done, VeryLazy plugins loaded"
  elif [ "$(meta "$dir" mode)" = bare ]; then echo "nvim     info --bare run: $(lua_eval "$dir" 'vim.v.vim_did_enter' 2>&1 | head -1)"
  else echo "nvim     FAIL not ready on $(basename "$(nvim_sock "$dir")")"; ok=0; fi
  echo "stdpath  info $(lua_eval "$dir" 'vim.fn.stdpath("config") .. " | " .. vim.fn.stdpath("data") .. " | " .. vim.fn.stdpath("state") .. " | " .. vim.fn.stdpath("cache")' 2>&1)"
  case "$(lua_eval "$dir" 'vim.fn.stdpath("data")' 2>&1)" in "$dir"/*) echo "stdpath  ok   data dir is the run's" ;; *) echo "stdpath  FAIL data dir is not under the run"; ok=0 ;; esac
  sed 's/^/meta     /' "$dir/meta"
  [ "$(git -C "$root" rev-parse --short HEAD)" = "$(meta "$dir" head)" ] || echo "code     WARN HEAD moved since up/sync"
  if [ "$(tree_hash "$root")" != "$(meta "$dir" tree)" ]; then
    echo "code     WARN the working tree changed since up/sync: nvim runs a stale snapshot (verify.sh sync $run)"
  else
    echo "code     ok   snapshot matches the working tree"
  fi
  # Egress: prove from inside the namespace that a real host is unreachable, without sending anything.
  local r=0
  in_ns "$dir" curl -sS -m 5 -o /dev/null https://github.com/ 2>/dev/null || r=$?
  if [ "$r" = 0 ]; then echo "egress   FAIL github.com reachable from the run's namespace"; ok=0; else echo "egress   ok   github.com unreachable from the run's namespace (curl exit $r)"; fi
  local cb; cb="$(lua_eval "$dir" 'vim.fn["provider#clipboard#Executable"]()' 2>&1 || true)"
  echo "clipbrd  info provider '${cb}' (tmux = the run's own server buffer)"
  local origin; origin="$(git -C "$dir/work" remote get-url origin 2>/dev/null || true)"
  if [ "$origin" = "$dir/remote.git" ]; then echo "git      ok   WORK's origin is the run's bare repo"; else echo "git      FAIL WORK's origin is '$origin'"; ok=0; fi
  if [ "$(meta "$dir" mode)" = seeded ]; then
    if [ "$(seed_manifest)" = "$(meta "$SEED" manifest)" ]; then echo "seed     ok   shared seed unchanged since it was built"; else echo "seed     FAIL the shared seed changed under a run (something wrote through a hard link)"; ok=0; fi
  fi
  if [ "$(meta "$dir" mode)" = live ]; then
    if [ "$(live_fingerprint)" = "$(meta "$dir" live_fp)" ]; then echo "live     ok   the owner's live config/plugins/Mason/tmux files unchanged since up"
    else echo "live     WARN the owner's live dirs changed since up (the owner may be using nvim; this run never writes them)"; fi
    echo "live     info live checkout @ $(meta "$dir" live_head) (dirty $(meta "$dir" live_dirty)), filled from seed: $(meta "$dir" filled_from_seed)"
  fi
  if ! cmp -s "$dir/home/.tmux.conf.local" "$dir/xdg/config/nvim/.tmux.conf.local"; then
    echo "tmuxconf WARN oh-my-tmux rewrote the run's ~/.tmux.conf.local (self-heal): diff -u $dir/xdg/config/nvim/.tmux.conf.local $dir/home/.tmux.conf.local"
  else
    echo "tmuxconf ok   ~/.tmux.conf.local unchanged by the running tmux"
  fi
  # The owner's tmux server's comm is "tmux: server", so match a prefix; a no-match is not an error.
  local owner; owner="$({ pgrep -u "$(id -u)" '^tmux' 2>/dev/null || true; } | while read -r p; do tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -qF "$VERIFY_HOME" || echo "$p"; done | tr '\n' ' ')"
  echo "owner    info tmux processes outside this run (the owner's, never contacted): ${owner:-none}"
  local msgs; msgs="$(lua_eval "$dir" 'vim.fn.execute("messages")' 2>&1 || true)"
  if grep -qE 'E[0-9]+:|Error' <<<"$msgs"; then echo "messages WARN errors in :messages:"; sed 's/^/messages   /' <<<"$msgs" | head -20; else echo "messages ok   no errors in :messages"; fi
  [ "$ok" = 1 ] || exit 1
}

save_screen() {
  local dir=$1 out=$2
  tmx "$dir" capture-pane -p -t main >"$out"
  tmx "$dir" capture-pane -p -e -t main >"${out%.txt}.ansi"
}

settle() {
  local dir=$1 a b
  a="$(tmx "$dir" capture-pane -p -t main)"
  for _ in $(seq 1 25); do
    sleep 0.2
    b="$(tmx "$dir" capture-pane -p -t main)"
    [ "$a" = "$b" ] && return 0
    a=$b
  done
}

cmd_keys() {
  local dir out; dir="$(run_dir "${1:-}")"; shift
  [ $# -gt 0 ] || die "keys: RUN [-l] KEY... | RUN --paste TEXT (tmux key names: Escape Enter C-o Space; -l = literal keys)"
  out="$(next_evidence "$dir" keys "$*")"
  if [ "$1" = --paste ]; then
    # A bracketed paste, as a terminal delivers one: no completion menu, no insert-mode mappings
    # (jk, the undo-break chars), no auto-pairs. The way to put text into a buffer.
    tmx "$dir" set-buffer -b verify-paste -- "${2:?--paste TEXT}"
    tmx "$dir" paste-buffer -p -d -b verify-paste -t main
  else
    tmx "$dir" send-keys -t main "$@"
  fi
  settle "$dir"
  { echo "> keys: $*"; echo "--- screen ---"; tmx "$dir" capture-pane -p -t main; } >"$out"
  tmx "$dir" capture-pane -p -e -t main >"${out%.txt}.ansi"
  cat "$out"
  echo "[evidence: $out]" >&2
}

cmd_tmux() {
  local dir out client; dir="$(run_dir "${1:-}")"; shift
  [ $# -gt 0 ] || die "tmux: RUN KEY... (e.g. C-b @ : the keys a person presses on the attached client)"
  client="$(tmx "$dir" list-clients -F '#{client_name}' 2>/dev/null | head -1 || true)"
  [ -n "$client" ] || die "no client attached to the run's server"
  out="$(next_evidence "$dir" tmux "$*")"
  tmx "$dir" send-keys -K -c "$client" "$@"
  sleep 1
  {
    echo "> client $client keys: $*"
    echo "--- sessions / windows / panes ---"
    tmx "$dir" list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} win=#{window_name} cmd=#{pane_current_command} active=#{pane_active} client_session=#{client_session}'
    echo "--- client is on: $(tmx "$dir" display -p -c "$client" '#{client_session}:#{window_index}.#{pane_index}' 2>/dev/null || true)"
  } >"$out"
  cat "$out"
  echo "[evidence: $out]" >&2
}

cmd_screen() {
  local dir out; dir="$(run_dir "${1:-}")"
  out="$(next_evidence "$dir" screen "${2:-screen}")"
  save_screen "$dir" "$out"
  cat "$out"
  echo "[evidence: $out]" >&2
}

cmd_lua() {
  local dir out res; dir="$(run_dir "${1:-}")"
  [ $# -ge 2 ] || die "lua: RUN 'EXPR or CHUNK with return' | RUN @PROBE.lua"
  local code=$2
  # @file: run a probe file (e.g. features/lua/dashboard_art.lua) by its absolute path.
  if [[ $code == @* ]]; then [ -f "${code#@}" ] || die "no such probe: ${code#@}"; code="return dofile('$(realpath "${code#@}")')"; fi
  out="$(next_evidence "$dir" lua "$2")"
  res="$(lua_eval "$dir" "$code")" || true
  { echo "> lua: $2"; echo "$res"; } >"$out"
  cat "$out"
  echo "[evidence: $out]" >&2
  [[ $res != "lua error:"* ]]
}

cmd_wait() {
  local dir expr want secs got=""; dir="$(run_dir "${1:-}")"; expr=${2:?EXPR}; want=${3?EXPECTED}; secs=${4:-30}
  local end=$((SECONDS + secs))
  while [ $SECONDS -lt $end ]; do
    got="$(lua_eval "$dir" "$expr" 2>&1 || true)"
    [ "$got" = "$want" ] && { echo "verify: wait ok: $expr == $want"; echo "$(date -Iseconds) wait ok: $expr == $want" >>"$dir/evidence/LOG.md"; return 0; }
    sleep 0.5
  done
  die "wait timed out after ${secs}s: $expr = '$got' (wanted '$want')"
}

cmd_panes() {
  local dir out; dir="$(run_dir "${1:-}")"
  out="$(next_evidence "$dir" panes state)"
  {
    tmx "$dir" list-sessions
    tmx "$dir" list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} win=#{window_name} cmd=#{pane_current_command} dead=#{pane_dead} path=#{pane_current_path}'
    tmx "$dir" list-clients -F 'client #{client_name} on #{client_session} #{client_width}x#{client_height}'
  } >"$out"
  cat "$out"
  echo "[evidence: $out]" >&2
}

cmd_headless() {
  local dir out r=0; dir="$(run_dir "${1:-}")"; shift
  out="$(next_evidence "$dir" headless "${*:-start}")"
  # shellcheck disable=SC2046
  (cd "$dir/work" && in_ns "$dir" $(run_env "$dir") timeout 120 "$NVIM_BIN" --headless "$@" +'qa!' </dev/null >"$out.out" 2>&1) || r=$?
  { echo "> nvim --headless $* +qa!   (cwd WORK)"; echo "< exit $r"; cat "$out.out"; } >"$out"
  rm -f "$out.out"
  cat "$out"
  echo "[evidence: $out]" >&2
  return $r
}

cmd_cli() {
  local dir out r=0 root a; dir="$(run_dir "${1:-}")"; shift
  [ $# -gt 0 ] || die "cli: RUN CMD... (\$CONFIG = the run's config snapshot, \$WORK = the fixture project)"
  root="$(meta "$dir" repo)"
  # Integrity: a drive never names the checkout (or the owner's dirs); it works on the snapshot.
  for a in "$@"; do
    case "$a" in
      "$root"|"$root"/*) die "cli: refuses a path inside the checkout ($a); use \$CONFIG/... (the run's snapshot)" ;;
      "$REAL_HOME/.config/nvim"*|"$REAL_HOME/.local/share/nvim"*|"$REAL_HOME/.local/state/nvim"*|"$REAL_HOME/.cache/nvim"*) die "cli: refuses the owner's nvim dirs ($a)" ;;
    esac
  done
  case "$1" in tmux) die "cli: drive tmux with 'verify.sh tmux' or 'verify.sh panes'" ;; esac
  out="$(next_evidence "$dir" cli "$*")"
  # shellcheck disable=SC2046
  (cd "$dir/work" && in_ns "$dir" $(run_env "$dir") timeout 300 bash -c 'exec "$@"' _ "$@" </dev/null >"$out.out" 2>&1) || r=$?
  { echo "> $*   (cwd WORK, run namespace)"; echo "< exit $r"; cat "$out.out"; } >"$out"
  rm -f "$out.out"
  cat "$out"
  echo "[evidence: $out]" >&2
  return $r
}

cmd_sync() {
  local dir root changes; dir="$(run_dir "${1:-}")"; root="$(meta "$dir" repo)"
  changes="$(snapshot "$root" "$dir/xdg/config/nvim" | grep -vE '^\.|^cd|^\*deleting +lazy-lock' || true)"
  {
    echo "head=$(git -C "$root" rev-parse --short HEAD)"
    echo "dirty=$(git -C "$root" status --porcelain | wc -l)"
    echo "tree=$(tree_hash "$root")"
  } >>"$dir/meta"
  [ -n "$changes" ] && echo "$changes" | sed 's/^/verify: synced /'
  if [ -n "$(sed -n '/\.tmux\.conf/p' <<<"$changes")" ]; then
    echo "verify: WARN the tmux config changed; the running server keeps the old one. down + up to drive the new one." >&2
  fi
  # A config change takes effect on the next nvim start, as for the owner: restart nvim in its pane.
  echo "nvim_gen=$(( $(meta "$dir" nvim_gen) + 1 ))" >>"$dir/meta"
  tmx "$dir" respawn-pane -k -t main -c "$dir/work" "$(start_nvim_cmd "$dir")"
  local ok=0
  for _ in $(seq 1 120); do
    [ -S "$(nvim_sock "$dir")" ] && nvim_ready "$dir" && { ok=1; break; }
    sleep 0.5
  done
  echo "$(date -Iseconds) sync: $(printf '%s' "$changes" | grep -c . || true) path(s), tree $(meta "$dir" tree), nvim restarted" >>"$dir/evidence/LOG.md"
  [ "$ok" = 1 ] || { tmx "$dir" capture-pane -p -t main >&2; die "nvim not ready after sync (screen above)"; }
  echo "verify: nvim restarted on the new snapshot"
}

cmd_live() {
  local root out lh rh; root="$(repo_root)"
  [ -d "$LIVE_CONFIG/.git" ] || die "no live checkout at $LIVE_CONFIG"
  if [ -n "${1:-}" ]; then out="$(next_evidence "$(run_dir "$1")" live drift)"; else mkdir -p "$VERIFY_HOME"; out="$VERIFY_HOME/live-$(date +%m%d-%H%M%S).txt"; fi
  # Read-only throughout: --no-optional-locks keeps `git status` from refreshing the live index.
  lh="$(git -C "$LIVE_CONFIG" --no-optional-locks rev-parse HEAD)"; rh="$(git -C "$root" rev-parse HEAD)"
  {
    echo "live:     $LIVE_CONFIG @ $(git -C "$LIVE_CONFIG" --no-optional-locks log --oneline -1)"
    echo "checkout: $root @ $(git -C "$root" log --oneline -1)  (working tree dirty: $(git -C "$root" status --porcelain | wc -l))"
    echo "live uncommitted:"; git -C "$LIVE_CONFIG" --no-optional-locks status --porcelain | sed 's/^/  /'
    if git -C "$root" cat-file -e "$lh^{commit}" 2>/dev/null; then
      echo "commits in the checkout that live lacks ($(git -C "$root" rev-list --count "$lh..$rh")):"; git -C "$root" log --oneline "$lh..$rh" | sed 's/^/  /'
      echo "commits in live that the checkout lacks ($(git -C "$root" rev-list --count "$rh..$lh")):"; git -C "$root" log --oneline "$rh..$lh" | sed 's/^/  /'
    else
      echo "live HEAD $lh is unknown to the checkout (fetch first; never fetched by verify)"
    fi
    echo "files that differ, live tree vs checkout working tree (what deploying would change):"
    diff -rq --exclude=.git --exclude=.claude --exclude=lazy-lock.json --exclude=__pycache__ --exclude='*_code_analyzer.md' "$LIVE_CONFIG" "$root" 2>&1 | sed "s#$LIVE_CONFIG#live#g; s#$root#checkout#g; s/^/  /" || true
    echo "tmux: ~/.tmux.conf -> $LIVE_TMUX_CONF; ~/.tmux.conf.local $(cmp -s "$REAL_HOME/.tmux.conf.local" "$root/.tmux.conf.local" && echo "== checkout's" || echo "DIFFERS from checkout's")"
    echo "live lock: $(jq length "$LIVE_CONFIG/lazy-lock.json" 2>/dev/null) plugins, modified $(date -d "@$(stat -c %Y "$LIVE_CONFIG/lazy-lock.json")" -Iseconds)"
    echo "deploy (the owner's step, never run by verify): git -C $LIVE_CONFIG pull --ff-only"
  } >"$out"
  cat "$out"
  echo "[evidence: $out]" >&2
}

cmd_note() {
  local dir; dir="$(run_dir "${1:-}")"
  echo "$(date -Iseconds) ${2:?TEXT}" >>"$dir/evidence/LOG.md"
}

stop_run() {
  local dir=$1 ns pids
  ns="$(meta "$dir" netns)"
  if [ -S "$(nvim_sock "$dir")" ]; then lua_eval "$dir" 'vim.fn.execute("messages")' >"$dir/evidence/messages-at-down.txt" 2>&1 || true; fi
  tmx "$dir" kill-server 2>/dev/null || true
  if [ -n "$ns" ]; then
    for sig in TERM TERM KILL; do
      pids="$(ns_pids "$ns")"
      [ -z "$pids" ] && break
      # shellcheck disable=SC2086
      kill -"$sig" $pids 2>/dev/null || true
      for _ in $(seq 1 20); do [ -z "$(ns_pids "$ns")" ] && break; sleep 0.25; done
    done
    [ -z "$(ns_pids "$ns")" ] || echo "verify: WARN processes left in $ns: $(ns_pids "$ns" | tr '\n' ' ')" >&2
  fi
  if [ "$(meta "$dir" mode)" = live ]; then
    if [ "$(live_fingerprint)" = "$(meta "$dir" live_fp)" ]; then echo "live dirs unchanged at down ($(meta "$dir" live_fp))" >"$dir/evidence/live-at-down.txt"
    else echo "live dirs CHANGED between up and down (the owner's own nvim, or a leak: investigate)" | tee "$dir/evidence/live-at-down.txt" >&2; fi
  fi
  [ -f "$dir/tmux-start.log" ] && cp "$dir/tmux-start.log" "$dir/evidence/"
  mkdir -p "$dir/evidence/logs"
  [ -d "$dir/xdg/state/nvim" ] && find "$dir/xdg/state/nvim" -maxdepth 1 -name '*.log' -exec cp {} "$dir/evidence/logs/" \;
  for _ in 1 2 3; do
    # Directories only: run files are hard links into the seed, and chmod on a link changes the
    # seed's file too (an earlier `chmod -R u+w` here made the seed writable again).
    find "$dir/xdg" "$dir/tmp" -type d ! -perm -200 -exec chmod u+w {} + 2>/dev/null || true
    rm -rf "$dir/xdg" "$dir/home" "$dir/work" "$dir/tmp" "$dir/remote.git" 2>/dev/null && break
    sleep 0.5
  done
  rm -f "$dir/tmux.sock" "$dir"/nvim-*.sock "$dir/tmux-start.log"
  echo "down" >"$dir/stopped"
  echo "verify: stopped $(basename "$dir"); evidence kept in $dir/evidence ($(find "$dir/evidence" -type f | wc -l) files)"
}

cmd_down() {
  if [ "${1:-}" = --all ]; then
    local d
    for d in "$VERIFY_HOME"/[0-9]*/; do [ -f "${d}stopped" ] || stop_run "${d%/}"; done
    return 0
  fi
  stop_run "$(run_dir "${1:-}")"
}

cmd_ls() {
  [ -d "$VERIFY_HOME" ] || return 0
  [ -f "$SEED/meta" ] && echo "seed: $(meta "$SEED" plugins) plugins, $(meta "$SEED" mason) Mason packages, seeded $(meta "$SEED" seeded) @ $(meta "$SEED" head)"
  local d state
  for d in "$VERIFY_HOME"/[0-9]*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    state=stopped
    [ -f "$d/stopped" ] || { [ -n "$(server_pid "$d")" ] && state=up; }
    printf '%-20s %-8s %-7s %3s evidence  %s @ %s\n' "$(basename "$d")" "$state" "$(meta "$d" mode)" \
      "$(find "$d/evidence" -type f | wc -l)" "$(meta "$d" repo)" "$(meta "$d" head)"
  done
}

sub=${1:-}; shift || true
case "$sub" in
  seed) cmd_seed "$@" ;;
  up) cmd_up "$@" ;;
  doctor) cmd_doctor "$@" ;;
  keys) cmd_keys "$@" ;;
  tmux) cmd_tmux "$@" ;;
  screen) cmd_screen "$@" ;;
  lua) cmd_lua "$@" ;;
  wait) cmd_wait "$@" ;;
  panes) cmd_panes "$@" ;;
  headless) cmd_headless "$@" ;;
  cli) cmd_cli "$@" ;;
  sync) cmd_sync "$@" ;;
  live) cmd_live "$@" ;;
  note) cmd_note "$@" ;;
  down) cmd_down "$@" ;;
  ls) cmd_ls ;;
  *) sed -n '2,/^set -e/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
