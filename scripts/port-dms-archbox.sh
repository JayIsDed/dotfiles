#!/bin/bash
# port-dms-archbox.sh — stage DankMaterialShell on the archbox (taichi).
# Idempotent: every step checks before it acts, safe to re-run. Run as jay
# ON the box. Expects the binary/font payload at ~/dms-port-payload/
# (rsync'd from the laptop via 111 — same x86_64 builds the laptop runs:
# dms v1.5.3, dgop v0.2.3, the matugen 4.x --prefer shim).
#
# This STAGES only. Nothing switches until the flag file exists:
#   touch ~/.config/dms-adopted   → next Hyprland login runs dms
#   rm    ~/.config/dms-adopted   → next login falls back to waybar+swaync
# (gate lives in .config/hypr/autostart.lua)
set -u

PAYLOAD="$HOME/dms-port-payload"
REF_DIR="$HOME/git/reference/DankMaterialShell"
DMS_URL="https://github.com/AvengeMedia/DankMaterialShell.git"
DMS_REF="7b9b34b"   # laptop's exact checkout 2026-08-13
FAIL=0

# dotfiles root: prefer the clone this script lives in
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

say()  { printf '  %-52s %s\n' "$1" "$2"; }
need() { FAIL=1; say "$1" "MISSING — $2"; }

echo "== dms port: staging on $(hostname) =="

# 1 — packages (install needs sudo; report, don't attempt)
for pkg in quickshell matugen; do
    v=$(pacman -Q "$pkg" 2>/dev/null)
    [ -n "$v" ] && say "$pkg" "ok ($v)" || need "$pkg" "sudo pacman -S $pkg"
done

# 2 — font (user-level, from payload)
if fc-list 2>/dev/null | grep -qi "material symbols rounded"; then
    say "Material Symbols Rounded" "ok"
elif [ -f "$PAYLOAD/fonts/MaterialSymbolsRounded.ttf" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp "$PAYLOAD/fonts/MaterialSymbolsRounded.ttf" "$HOME/.local/share/fonts/"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    say "Material Symbols Rounded" "installed (user fonts)"
else
    need "Material Symbols Rounded" "no payload font"
fi

# 3 — reference clone + the REQUIRED dank-qml-common submodule
if [ -d "$REF_DIR/.git" ]; then
    say "reference clone" "ok ($(git -C "$REF_DIR" describe --tags --always 2>/dev/null))"
else
    mkdir -p "$(dirname "$REF_DIR")"
    git clone --quiet "$DMS_URL" "$REF_DIR" \
        && git -C "$REF_DIR" checkout --quiet "$DMS_REF" \
        && say "reference clone" "cloned @ $DMS_REF" \
        || need "reference clone" "clone failed"
fi
if [ -d "$REF_DIR/.git" ]; then
    git -C "$REF_DIR" submodule update --quiet --init --recursive \
        && say "dank-qml-common submodule" "ok" \
        || need "dank-qml-common submodule" "submodule update failed"
fi

# 4 — dms + dgop + matugen shim into ~/.local/bin
mkdir -p "$HOME/.local/bin"
for b in dms dgop matugen; do
    if [ -f "$PAYLOAD/bin/$b" ]; then
        install -m755 "$PAYLOAD/bin/$b" "$HOME/.local/bin/$b"
        say "~/.local/bin/$b" "installed from payload"
    elif [ -x "$HOME/.local/bin/$b" ]; then
        say "~/.local/bin/$b" "already present"
    else
        need "~/.local/bin/$b" "no payload"
    fi
done

# 5 — ~/.config/quickshell as a REAL dir (ledger: -c discovery fails
#     through a symlinked ~/.config/quickshell)
QS="$HOME/.config/quickshell"
if [ -L "$QS" ]; then rm "$QS"; fi
mkdir -p "$QS"
ln -sfn "$REF_DIR/quickshell" "$QS/dms"
ln -sfn "$DOTFILES/.config/quickshell/lilypad" "$QS/lilypad"
say "~/.config/quickshell/{dms,lilypad}" "linked"

# 6 — DankMaterialShell config: plugins symlink to dotfiles canon,
#     settings seeded once (never overwritten — the GUI owns them after)
DC="$HOME/.config/DankMaterialShell"
mkdir -p "$DC"
ln -sfn "$DOTFILES/.config/DankMaterialShell/plugins" "$DC/plugins"
say "plugins → dotfiles canon" "linked"
for f in settings.json plugin_settings.json; do
    if [ -f "$DC/$f" ]; then
        say "$f" "kept (existing)"
    elif [ -f "$DOTFILES/.config/DankMaterialShell/seed/$f" ]; then
        cp "$DOTFILES/.config/DankMaterialShell/seed/$f" "$DC/$f"
        say "$f" "seeded"
    else
        need "$f" "no seed in dotfiles"
    fi
done
# no battery on a desktop — drop the pill from a freshly seeded bar
if command -v jq >/dev/null && [ -f "$DC/settings.json" ] \
   && grep -q batteryPower "$DC/settings.json"; then
    jq '(.barConfigs[].rightWidgets) |= map(select(. != "batteryPower"))' \
        "$DC/settings.json" > "$DC/settings.json.tmp" \
        && mv "$DC/settings.json.tmp" "$DC/settings.json" \
        && say "batteryPower pill" "removed (no BAT0 here)"
fi

# 7 — relay legs the plugins depend on (archbox = fleet's self-probe)
for host in claude-dev docker-services archbox; do
    ssh -o BatchMode=yes -o ConnectTimeout=4 "$host" true 2>/dev/null \
        && say "ssh $host" "ok" || need "ssh $host" "key/alias missing"
done

# 8 — verdict
echo
if [ "$FAIL" -eq 0 ]; then
    cat <<EOF
staged clean. to adopt:  touch ~/.config/dms-adopted  && relog
rollback any time:       rm ~/.config/dms-adopted     && relog
(waybar + swaync remain the default until the flag exists; nvidia
 triple-head pixel check happens at the desk on first dms login)
EOF
else
    echo "staged with MISSING items above — fix those before touching the flag."
fi
exit "$FAIL"
