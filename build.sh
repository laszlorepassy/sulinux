#!/bin/bash
# Sulinux ISO építése. Mindig Docker-konténerben (debian:trixie) fut, minden gépen ugyanazzal
# az egy paranccsal (Linux, macOS, Windows PowerShell), abból a mappából indítva, ahová az
# ISO-t kéred (lásd PARANCS lent, és a README „Az ISO építése” fejezetét).
#
# Ha a parancsot a projekt mappájában indítod, az ott lévő (akár módosított) változat épül;
# máshol a GitHubon lévő legfrissebb. Az ISO az indító mappa out/ almappájába kerül.
# A letöltött csomagok a sulinux-build Docker-kötetben megmaradnak a következő építéshez;
# tiszta újrakezdés: docker volume rm sulinux-build
set -euo pipefail

TAROLO=https://github.com/laszlorepassy/sulinux
PARANCS='docker run --rm --privileged --platform linux/amd64 -v sulinux-build:/build -v "${PWD}:/host" debian:trixie bash -c "apt-get update -qq && apt-get install -y -qq curl >/dev/null && curl -fsSL https://raw.githubusercontent.com/laszlorepassy/sulinux/main/build.sh | bash"'

hiba() { printf '\033[1;31mHiba:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[1;34m>>>\033[0m %s\n' "$*"; }

if [ ! -f /.dockerenv ] || [ ! -d /host ] || [ ! -d /build ]; then
    echo "Az ISO-t ezzel az egy paranccsal építsd (abban a mappában, ahová az ISO-t kéred):"
    echo
    echo "  $PARANCS"
    exit 1
fi

# A projekt mappájából indítva az ott lévő build.sh fusson (ez lehet módosított változat)
if [ -f /host/build.sh ] && [ "${BASH_SOURCE[0]:-}" != /host/build.sh ]; then
    exec bash /host/build.sh
fi

info "Építőeszközök telepítése"
apt-get update -qq
apt-get install -y -qq live-build git ca-certificates >/dev/null

if [ -f /host/build.sh ]; then
    info "A projekt mappájában lévő változat épül"
    FORRAS=/host
else
    info "A legfrissebb változat letöltése: $TAROLO"
    rm -rf /tmp/sulinux
    git clone -q --depth 1 "$TAROLO" /tmp/sulinux
    FORRAS=/tmp/sulinux
fi

# A forrás frissen kerül a kötetbe, a letöltési gyorsítótár (cache/) marad az előző építésből
find /build -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} +
tar -C "$FORRAS" --exclude=./.git --exclude=./out --exclude=./cache --exclude=./chroot \
    --exclude=./binary --exclude=./.build -cf - . | tar -C /build -xf -
cd /build
. config/sulinux.conf

# Az építési beállításokat a chrootban futó hook is látja
install -d config/includes.chroot_after_packages/etc/sulinux
cat > config/includes.chroot_after_packages/etc/sulinux/build.conf <<EOF
DISTRO_NAME="$DISTRO_NAME"
DISTRO_VERSION="$DISTRO_VERSION"
EOF

# A képek a repóban csak az images/ mappában vannak; a háttérképeket a hook innen készíti
install -d config/includes.chroot_after_packages/usr/share/sulinux/images
cp images/*.svg config/includes.chroot_after_packages/usr/share/sulinux/images/

# Újabb kernel a backports tárolóból (ha be van kapcsolva)
PREF=config/archives/kernel-backports.pref
install -d config/archives
if [ "$BACKPORTS_KERNEL" = 1 ]; then
    for stage in chroot binary; do
        cat > "$PREF.$stage" <<'EOF'
Package: linux-image-* linux-headers-* linux-kbuild-* firmware-*
Pin: release n=trixie-backports
Pin-Priority: 900
EOF
    done
else
    rm -f "$PREF.chroot" "$PREF.binary"
fi

# Az out/ mappa a parancsot indító felhasználóé legyen (Linuxon a konténer rootként ír)
KI=/host/out
TULAJ=$(stat -c %u:%g /host)
mkdir -p "$KI"

info "Építés (30–90 perc; a napló: out/build.log)"
lb clean
lb config
lb build || true   # az auto/build tee-n át naplóz, a hibát az ISO hiánya jelzi

ISO=$(ls -t ./*.hybrid.iso ./*.iso 2>/dev/null | head -1)
if [ -z "$ISO" ]; then
    cp -f build.log "$KI/" 2>/dev/null || true
    chown -R "$TULAJ" "$KI"
    hiba "Az építés nem sikerült. A hiba oka az out/build.log fájl végén látható."
fi
ISO=$(basename "$ISO")
mv "$ISO" "$KI/"
cp -f build.log "$KI/"
(cd "$KI" && sha256sum "$ISO" > "$ISO.sha256")
chown -R "$TULAJ" "$KI"

cat <<EOF

Kész: out/$ISO ($(du -h "$KI/$ISO" | cut -f1))
      (abban a mappában, ahonnan a parancsot indítottad)
Ellenőrzőösszeg: out/$ISO.sha256

Pendrive-ra írás (legalább 8 GB; a pendrive-on lévő MINDEN adat törlődik):
  1. Töltsd le és indítsd el a balenaEtchert: https://etcher.balena.io/
     (Windowson, macOS-en és Linuxon is ugyanígy működik)
  2. Flash from file → válaszd ki az out/$ISO fájlt.
  3. Select target → válaszd ki a pendrive-ot.
  4. Flash! – a végén magától ellenőrzi az írást.
EOF
