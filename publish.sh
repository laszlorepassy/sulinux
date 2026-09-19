#!/bin/bash
# Az elkészült ISO közzététele az Internet Archive-on: https://archive.org/details/iskolinux
# Minden feltöltés ugyanabba az elembe kerül, azonos fájlnévvel, így a letöltési link állandó,
# és mindig a legfrissebb ISO-ra mutat. Csak Docker kell hozzá.
#
# Használat:
#   ./publish.sh --setup   egyszer: bejelentkezés az archive.org-fiókkal (e-mail, jelszó)
#   ./publish.sh           az out/ mappában lévő ISO és ellenőrzőösszeg feltöltése
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
ELEM=iskolinux
BEALLITAS="$HOME/.config/internetarchive"

hiba() { printf '\033[1;31mHiba:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }

command -v docker >/dev/null || hiba "Nincs telepítve a Docker."

# Az Internet Archive „ia” parancssori eszköze egy Python-konténerben
ia() {
    local tty=()
    [ -t 0 ] && [ -t 1 ] && tty=(-it)
    docker run --rm "${tty[@]}" \
        -v "$BEALLITAS:/root/.config/internetarchive" \
        -v "$ROOT/out:/out:ro" \
        python:3-slim sh -c 'pip install -q --root-user-action=ignore internetarchive >/dev/null && ia "$@"' ia "$@"
}

mkdir -p "$BEALLITAS"

if [ "${1:-}" = --setup ]; then
    info "Bejelentkezés az archive.org-fiókkal (fiók: https://archive.org/account/signup)"
    ia configure
    # A konténer rootként írja a beállítást; legyen a gépen futtató felhasználóé
    docker run --rm -v "$BEALLITAS:/c" python:3-slim chown -R "$(id -u):$(id -g)" /c
    exit 0
fi

[ -s "$BEALLITAS/ia.ini" ] || hiba "Előbb jelentkezz be egyszer: ./publish.sh --setup"

ISO=$(ls -t "$ROOT"/out/*.iso 2>/dev/null | head -1)
[ -n "$ISO" ] || hiba "Nincs ISO az out/ mappában. Előbb építsd meg (README: „Az ISO építése”)."
ISO=$(basename "$ISO")
[ -f "$ROOT/out/$ISO.sha256" ] || hiba "Hiányzik az ellenőrzőösszeg: out/$ISO.sha256"

info "Ellenőrzőösszeg"
(cd "$ROOT/out" && sha256sum -c "$ISO.sha256")

info "Feltöltés: $ISO → https://archive.org/details/$ELEM (a mérettől függően sokáig tarthat)"
ia upload "$ELEM" "/out/$ISO" "/out/$ISO.sha256" \
    --retries 10 \
    --metadata="mediatype:software" \
    --metadata="collection:open_source_software" \
    --metadata="title:IskoLinux" \
    --metadata="description:Magyar nyelvű, Debian 13 alapú oktatási Linux KDE Plasma felülettel, a digitális kultúra érettségi programjaival. Leírás: https://github.com/laszlorepassy/iskolinux" \
    --metadata="language:hun" \
    --metadata="subject:linux;debian;oktatás;érettségi;iskola"

cat <<EOF

Kész. Letöltési link (mindig a legfrissebb):
  https://archive.org/download/$ELEM/$ISO
Ellenőrzőösszeg:
  https://archive.org/download/$ELEM/$ISO.sha256
Az archive.org feldolgozása után a link néhány perc múlva él.
EOF
