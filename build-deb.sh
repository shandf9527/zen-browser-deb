#!/usr/bin/env bash
# Repackage the official Zen Browser Linux tarball into a Debian .deb.
#
# Usage:
#   ./build-deb.sh --version 1.23.4b --arch amd64 --tarball zen.linux-x86_64.tar.xz [--outdir dist]
#
# The result is a plain "copy the upstream build into /opt" package: no source
# is compiled, so the output is byte-identical to what Zen ships, only wrapped
# with a proper Debian layout (desktop entry, icons, /usr/bin symlink).
set -euo pipefail
umask 022

VERSION=""
ARCH=""
TARBALL=""
OUTDIR="dist"
PKGNAME="zen-browser"
MAINTAINER="${MAINTAINER:-shandf9527 <shandf9527@users.noreply.github.com>}"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="${2:?}"; shift 2 ;;
    --arch)    ARCH="${2:?}";    shift 2 ;;
    --tarball) TARBALL="${2:?}"; shift 2 ;;
    --outdir)  OUTDIR="${2:?}";  shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$VERSION" ] || die "--version is required"
[ -n "$ARCH" ]    || die "--arch is required (amd64|arm64)"
[ -f "$TARBALL" ] || die "tarball not found: $TARBALL"

case "$ARCH" in
  amd64) DEB_ARCH=amd64 ;;
  arm64) DEB_ARCH=arm64 ;;
  *) die "unsupported arch: $ARCH" ;;
esac

# Upstream versions look like 1.23.4b; Debian wants a digit to start, which is
# already the case, so no epoch is needed. -1 is our own packaging revision.
DEB_VERSION="${VERSION}-1"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SRC="$WORK/src"
PKGROOT="$WORK/pkg"
mkdir -p "$SRC" "$PKGROOT"

echo "==> extracting $TARBALL"
tar -xJf "$TARBALL" -C "$SRC"
[ -d "$SRC/zen" ] || die "unexpected tarball layout: no top-level zen/ directory"

APPDIR="$PKGROOT/opt/zen-browser"
mkdir -p "$APPDIR" \
         "$PKGROOT/usr/bin" \
         "$PKGROOT/usr/share/applications" \
         "$PKGROOT/usr/share/doc/$PKGNAME" \
         "$PKGROOT/DEBIAN"

shopt -s dotglob
mv "$SRC/zen"/* "$APPDIR"/
shopt -u dotglob

# The upstream tarball has no desktop entry and keeps its icons deep inside the
# application dir, so both are generated here.
install -d "$PKGROOT/usr/share/icons/hicolor"
for size in 16 32 48 64 128; do
  src="$APPDIR/browser/chrome/icons/default/default${size}.png"
  [ -f "$src" ] || continue
  case "$size" in
    16) dir=16x16 ;; 32) dir=32x32 ;; 48) dir=48x48 ;;
    64) dir=64x64 ;; 128) dir=128x128 ;;
  esac
  install -Dm644 "$src" "$PKGROOT/usr/share/icons/hicolor/$dir/apps/$PKGNAME.png"
done

cat > "$PKGROOT/usr/share/applications/$PKGNAME.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Name=Zen Browser
GenericName=Web Browser
Comment=Browse the web with a calm, privacy-focused Firefox-based browser
Exec=/opt/zen-browser/zen %u
TryExec=/opt/zen-browser/zen
Icon=zen-browser
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/mailto;
StartupNotify=true
StartupWMClass=zen
Actions=new-window;private-window;

[Desktop Action new-window]
Name=New Window
Exec=/opt/zen-browser/zen --new-window %u

[Desktop Action private-window]
Name=New Private Window
Exec=/opt/zen-browser/zen --private-window %u
EOF

ln -sf /opt/zen-browser/zen "$PKGROOT/usr/bin/$PKGNAME"

cat > "$PKGROOT/usr/share/doc/$PKGNAME/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Zen Browser
Source: https://github.com/zen-browser/desktop

Files: *
Copyright: Zen Browser contributors
License: MPL-2.0
 This package only repackages the unmodified upstream Linux build.
 On Debian systems the full text of the MPL-2.0 can be found in
 /usr/share/common-licenses/MPL-2.0.
EOF

INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "$PKGROOT" | cut -f1)"

# Dependencies are the shared libraries Firefox/Gecko links against at runtime;
# everything else (libxul, nss, sqlite, codecs) ships inside the tarball.
cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: $PKGNAME
Version: $DEB_VERSION
Architecture: $DEB_ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Section: web
Priority: optional
Homepage: https://zen-browser.app
Depends: libgtk-3-0, libx11-xcb1, libxcomposite1, libxdamage1, libxrandr2, libxfixes3, libxext6, libxtst6, libdbus-glib-1-2, libasound2t64 | libasound2, libpulse0, libpango-1.0-0, libcairo2, libfreetype6, libfontconfig1, libglib2.0-0, libstdc++6
Recommends: fonts-noto-color-emoji
Description: Zen Browser - a calmer, privacy-focused Firefox-based browser
 Zen is an open-source web browser built on Firefox, with a focus on
 productivity, privacy and a distraction-free interface.
 .
 This package repackages the official upstream Linux build into /opt/zen-browser
 and adds a desktop entry and icons. It does not patch or recompile anything.
EOF

mkdir -p "$OUTDIR"
DEBFILE="$OUTDIR/${PKGNAME}_${VERSION}_${DEB_ARCH}.deb"
echo "==> building $DEBFILE"
# -Zxz: smaller package; --root-owner-group: no fakeroot needed on CI.
dpkg-deb --build --root-owner-group -Zxz "$PKGROOT" "$DEBFILE" >/dev/null

echo "==> done: $DEBFILE ($(du -h "$DEBFILE" | cut -f1))"
