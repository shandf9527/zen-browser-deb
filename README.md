# zen-browser-deb

Private, automated Debian packaging of [Zen Browser](https://zen-browser.app).

Every day a GitHub Actions workflow checks the latest official Zen release and, if it
is not published here yet, builds `.deb` packages and attaches them to a GitHub
Release in this repository.

## What this builds (and what it does not)

The workflow **does not compile anything**. Compiling Firefox/Zen from source needs
~30–40 GB of disk and hours of CPU on a 16-vCPU paid runner — that does not fit in a
free GitHub-hosted runner (4 vCPU / 16 GB RAM / ~14 GB disk, 6 h job limit).

Instead it downloads the official Linux tarballs (`zen.linux-x86_64.tar.xz`,
`zen.linux-aarch64.tar.xz`) from `zen-browser/desktop` and repackages them:

| added by this repo | value |
|---|---|
| payload | unmodified upstream build, installed to `/opt/zen-browser` |
| launcher | `/usr/bin/zen-browser` → `/opt/zen-browser/zen` |
| desktop entry | `/usr/share/applications/zen-browser.desktop` (incl. new/private window actions) |
| icons | hicolor 16/32/48/64/128 px |
| deps | only the runtime libraries Gecko links against (GTK3, X11, ALSA, Pulse…) |

## Install / upgrade

Download the `.deb` for your architecture from the newest release and install it:

```bash
sudo apt install ./zen-browser_<version>_amd64.deb
```

`apt` will pull in any missing runtime library automatically. Upgrading is the same
command with the new file; your profile in `~/.zen` is untouched.

## Triggers

- `schedule`: daily at 03:17 UTC (11:17 Asia/Shanghai).
- `workflow_dispatch`: manual run, optionally pinning a version, e.g. `1.23.4b`,
  and optionally `force` to rebuild an already published version.

Versions are skipped automatically when a release with the same tag already exists,
so the daily run is a no-op unless upstream publishes something new.

## Local build

```bash
curl -LO https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz
./build-deb.sh --version 1.23.4b --arch amd64 --tarball zen.linux-x86_64.tar.xz --outdir dist
```

Requires only `dpkg-deb` and `xz-utils` — no fakeroot, no build toolchain.

## Notes

- Zen's own updater is left intact but the deb should be upgraded through `apt`
  so that the package database stays consistent.
- Unofficial packaging. Bugs in the packaging belong here; bugs in the browser
  belong to [zen-browser/desktop](https://github.com/zen-browser/desktop/issues).
