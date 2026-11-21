# smartbox-tools

A collection of tools and scripts for customizing **Amlogic smart TV boxes (S905X / p212)** from an Android phone + Ubuntu chroot.
Focus: flashing via USB Burn Mode, root research, and chroot/Termux environment helpers.

**Why this exists:** most guides say you need a Windows PC + Amlogic USB Burning
Tool to flash these boxes. These tools do it **from the phone only** — no PC —
using the USB OTG port and a Python burn tool running inside a chroot.

> Note: this is a collection of research tools. It does **not** include firmware, APKs, or backup files.

## Contents

- [Quick start](#quick-start-the-4-steps-that-actually-worked)
- [⚠️ Read this before using anything](#-read-this-before-using-anything)
- [Device requirements](#device-requirements)
- [Layout](#layout)
- [Folder-by-folder guide](#folder-by-folder-guide)
- [Quick usage](#quick-usage)
- [Dependencies](#dependencies)
- [Notes](#notes)
- [Research status](#research-status)
- [License](#license)

## Quick start (the 4 steps that actually worked)

1. **Enter the chroot on the phone (from Termux):** copy
   `termux/chroot-mount.sh` to your Termux home (`$HOME/chroot-mount.sh`), then
   run `./termux/ubuntu`. Set `CHROOT_DIR` first (see `.env.example`).
2. **Make sure ADB sees the box first:** `adb devices` must show a `<serial> device`
   entry. If it is empty, the USB node may need a symlink (`/dev/bus/usb/...`
   from the host) or use network ADB: `adb connect <BOX_IP>:5555`.
   If it shows `offline` or `authorizing`, accept the "Allow USB debugging?"
   dialog on the TV and re-check (`adb kill-server && adb start-server`).
3. **Put the box in burn mode `1b8e:c003`:** with the box still running its
   original Android 7 (this is the state where `adb reboot fastboot` was verified
   to reach burn mode), run `adb reboot fastboot` — **from inside the chroot**
   (USB OTG connected).
   Verify with:
   ```bash
   python3 -c "import usb.core; print(bool(usb.core.find(idVendor=0x1b8e,idProduct=0xc003)))"
   ```
   It must print `True` before continuing. (On the tested box, holding the reset
   button only reached ADB `18d1:4ee7`, not burn mode — so use this path.)
   If the box is **already on Android 9**, this path was not verified here —
   entering burn mode from that state may need the box's hardware recovery
   method or a PC-based Amlogic tool.
4. **Flash (still inside the chroot):**
   ```bash
   cd ubt && python3 ubt.py --img ROM.img --no-erase-bootloader --reset
   ```

All four steps happen on the phone — no PC. Everything below is detail,
background, and research notes.

> ⚠️ **Before you actually flash:** read the risk warnings in the next section.
> A wrong ROM or an interrupted flash can permanently brick the box.

## ⚠️ Read this before using anything

**Flashing firmware can permanently damage your device. You do it at your own risk.**
These tools were tested on one specific box; they are not a universal recipe.

- **Hard-brick risk.** A partial/interrupted flash can leave the box unable to boot.
  Erasing or writing the bootloader (`--no-erase-bootloader` is used here, but
  other paths in `ubt.py` can still touch it) is destructive. Keep a known-good
  ROM and a recovery plan before starting.
- **Wrong ROM = brick.** The firmware must match the exact board **and the WiFi
  chip variant** (this box used the AMPAK / multi-WiFi build; a Realtek/Broadcom
  build killed WiFi on the same model). Do not flash a random "S905X" image.
- **USB instability is normal here.** Long transfers (system ~1 GB, vendor
  ~500 MB) can drop mid-write with `USBError: Input/Output error`. Several
  retries may be needed; check every partition with `Verify success` before
  trusting the flash. Use a **data-capable** USB-A–A cable, not charge-only.
- **The phone stays in host mode the whole time.** Keep it awake, charged, and
  do not unplug the OTG cable. A dying battery or a sleeping phone interrupts
  the transfer.
- **Root/exploit tools are research only.** `utgard/` and `dcow/` crashed the
  test box repeatedly and are **not stable**. Do not run them on a device you
  cannot afford to lose.
- **Secure boot / password-locked devices** will refuse unsigned images. Check
  the bootloader state first; a password is required on some units.
- **Warranty** is almost certainly void. No support, no guarantee.

## Device requirements

Verified working setup (adjust for your own hardware):

| Item | Requirement |
|---|---|
| Box | Amlogic **S905X / p212** (this is the tested platform; other Amlogic SoCs are untested) |
| Boot mode | Must be able to enter **Amlogic burn mode `1b8e:c003`** — otherwise `ubt/` cannot talk to it |
| Port | USB-A port (on this box, the one near the reset hole) |
| Cable | **USB-A–A data cable** + OTG adapter on the phone (charge-only cables will fail) |
| Phone | Rooted Android with **OTG host** support, Termux, and a working USB bind into the chroot |
| ROM | Matching image in Amlogic `aml_upgrade_package.img` format (ADNL or OPTIMUS — `ubt.py` detects it). Get it from your box manufacturer / a device-specific firmware source — **this repo does not ship ROM files**. |
| Power | Stable power to the box; do not power-cycle mid-flash |
| Extras | `pyusb`, `libusb-1.0` in the chroot, `adb`/`fastboot` on the host side |

See `.env.example` for the path variables used by the helper scripts.

## Layout

```
ubt/         USB Burn Tool — the actual ROM flashing tool (main tool)
pyamlboot/   standalone bootROM tools (RAM-boot, SoC ID)
utgard/      Utgard LPE root research (Mali-400 GPU write primitive)
dcow/        DirtyCow CVE-2016-5195 PoC
chroot/      scripts that run inside the Ubuntu chroot
termux/      scripts that run on the phone (Termux)
```

See the folder-by-folder guide below for purpose and usage of each.

**Terminology:** *burn mode* = the Amlogic bootROM USB mode (`1b8e:c003`) that
accepts a raw firmware image — this is what `ubt/` talks to. *chroot* = a Ubuntu
filesystem running on the rooted Android phone; it is where `ubt.py` runs (the
phone itself is the host, no PC involved).

## Folder-by-folder guide

### `ubt/` — USB Burn Tool (the main flashing tool)
Python tool that parses an Amlogic `aml_upgrade_package.img` and flashes every
partition to the box eMMC over USB Burn Mode. This is the tool that actually did
the successful Android 9 flash from the phone.

| File | Purpose | Usage |
|---|---|---|
| `ubt.py` | Entry point. Detects ADNL vs OPTIMUS protocol from the image and runs the matching burn flow. | `python3 ubt.py --img ROM.img --no-erase-bootloader --reset` |
| `adnl.py` | ADNL protocol burn implementation (used when the image contains `usb_flow`). | Called automatically by `ubt.py` |
| `pyamlboot/` | Bundled pyamlboot modules (OPTIMUS burn, image parser, USB backend, SoC ID). Modified for stability — see Quick usage. (`__init__.py` is just the package marker.) | Imported by `ubt.py` |

Run it **inside the chroot**, with the box already in burn mode `1b8e:c003`.
See "Flash a ROM from the phone" below for the full setup.

### `utgard/` — Utgard LPE root research (Mali-400 GPU write primitive)
Research into the Mali-400 (Utgard) GPU driver bug on Android 7 Amlogic boxes:
an arbitrary physical-memory write primitive. **Not stable** — see Research status.

| File | Purpose | Usage |
|---|---|---|
| `src/*.c` | C sources: write primitive (`gpwrite*`, `gpu_arb_write*`), syscall helpers (`kfunc`, `kread`), SLOT_PHYS scanners (`gpu_scan*`), ION probes, and `crash_for_core.c` (triggers the core dump that runs the `core_pattern` root helper). | Build with `make` (needs cross compiler) |
| `run.sh` | Drives the full chain: point syscall slots at `kallsyms_lookup_name`, resolve symbols, patch SELinux, trigger a root helper via `core_pattern`. | `SLOT_PHYS=... KLN_ADDR=... ./run.sh` |
| `roothelper.sh`, `root_cmd.sh` | Payload run as root after the chain succeeds (scripts), not compiled. | Used by `run.sh` |
| `experiments/` | Archived SLOT_PHYS scanning experiments (10 scripts, different canary strategies). **Research-only** — not part of the main chain, see `experiments/README.md`. | Reference only; do not run on a device you care about |

Firmware-specific addresses (`SLOT_PHYS`, `KLN_ADDR`) are **required** and must
be derived for your exact build — see `.env.example`.

### `chroot/` — scripts that run inside the Ubuntu chroot
Not Termux-side scripts — these run *inside* the chroot. Two small utilities:
one fixes the chroot after a reboot; the other is an **optional** SD-card image
writer (the verified flash path used `ubt/` over USB, not an SD card).

| File | Purpose | Usage |
|---|---|---|
| `chroot-mount-restore.sh` | Re-mount `/proc`, `/sys`, `/tmp` after a reboot (mounts are lost because the service starts via plain `chroot`, not the launcher). | `source chroot-mount-restore.sh`; for auto-mount at login, add `[ -n "$PS1" ] && . /path/to/chroot/chroot-mount-restore.sh` to `~/.bashrc` / `.zshrc` |
| `dd-throttled.py` | **Optional** — write an image to an SD card at 2 MB/s (avoids heat/voltage drops). Not needed for the USB flash path. **Double-check `DD_DST`** — wrong device destroys data. | `DD_SRC=img DD_DST=/dev/block/sdX python3 dd-throttled.py` |

### `dcow/` — DirtyCow (CVE-2016-5195) research
Classic Android root PoC over ADB. **Unstable on the tested firmware** — keep it as
research reference, not as a primary root path.

| File | Purpose |
|---|---|
| `dirtycow.c`, `dcow.c`, `run-as.c` | Exploit implementations (common DirtyCow variants). |
| `dirtycow-dbg.c`, `dcow-dbg-main.c` | Debug variants. |
| `Makefile` | Builds via `ndk-build` with ABI/SDK detected from `adb shell getprop`. Targets: `build`, `push`, `root`, `clean` (requires a connected ADB device). |
| `amlimage.py`, `aml_image_packer.py` | Amlogic firmware image parser/packer (from SaluteDevices, GPL-2.0/MIT). |
| `pyamlboot/` | Local copy of the pyamlboot modules used by the exploit. |
| `Android.mk` | NDK build script for `dirtycow` and `run-as` (referenced by `Makefile`). |

Usage (requires Android NDK + `adb`):
```bash
cd dcow
make root      # build -> push to device -> run
make clean
```

### `pyamlboot/` — Standalone Amlogic bootROM tools
Pure-Python tools that talk to the Amlogic bootROM while the device is in
**burn mode `1b8e:c003`**. Two scripts:

| File | Purpose | Usage |
|---|---|---|
| `boot.py` | RAM-boot the device: send DDR + U-Boot + image, run temporarily (no eMMC write). Useful for unbricking/exploration. | `python3 boot.py <board> [--board-files DIR] [--image FILE] [--script FILE] [--fdt FILE] [--ramfs FILE] [--timeout MS]` (see `choices` in source for boards) |
| `socid.py` | Read the SoC ID / chip identity from the bootROM. | `python3 socid.py` (device must be in burn mode) |

Requires `pyusb` + `libusb-1.0`. **Note:** `boot.py` loads board config files from
the `pyamlboot` Python package resources (`files/` in the installed distribution),
so install pyamlboot itself (`pip install pyamlboot`) rather than running this
script completely standalone. For a full eMMC flash, use `ubt/` instead — not this folder.

### `termux/` — scripts that run on the phone (Termux)
Scripts run **on the phone, in Termux**, not in the chroot.

| File | Purpose | Usage |
|---|---|---|
| `ubuntu` | Enter the Ubuntu chroot: check mounts, `su` + `chroot`, auto-unmount on exit. This is the entry point for running `ubt.py` on the phone. | `./ubuntu`, then `exit` to leave |
| `chroot-mount.sh` | Mounts `/proc`, `/sys`, `/dev`, `/tmp` into the chroot and copies `resolv.conf`. Called automatically by `ubuntu` — copy it to your Termux home (`$TERMUX_HOME/chroot-mount.sh`) before running `./ubuntu`. | Called by `ubuntu`; can also be run manually |

All paths use environment variables — configure them via `.env.example` first.

## Quick usage

### Flash a ROM from the phone (no PC required — verified)
This was **actually done on an Android phone only**, no PC involved:

- Phone: a rooted Android phone (Android 16 in the tested setup) running **Termux**
- Ubuntu **chroot** (path set via `CHROOT_DIR`, entered via `./termux/ubuntu`)
- **USB OTG cable** (phone host → box USB-A port near the reset hole)
- Box put into **burn mode** `1b8e:c003` via `adb reboot fastboot` sent from the phone
- `ubt.py` run **inside the chroot** on the phone, flashing the full ROM (all partitions) to the box eMMC

The box must enter **burn mode** `1b8e:c003` (previously achieved via `adb reboot fastboot` from Android 7).

```bash
cd ubt
python3 ubt.py --img /path/to/aml_upgrade_package.img --no-erase-bootloader --reset
```

Other `ubt.py` options (from `--help`): `--wipe {no,normal,all}` (destructive —
`all` erases all partitions), `--password FILE` (for password-locked bootloaders).
The command above uses the tested defaults: no bootloader erase, normal wipe,
reset after success.

`optimus.py` and `pyamlboot.py` were modified with the following fixes:
- `wait_device()` timeout raised to 90 seconds (the 10s default was too short when the box re-enumerates after erasing the bootloader)
- `wait_device(identify=False)` in `do_burn()` (some newer bootloaders do not answer `REQ_IDENTIFY_HOST`)
- removed the standalone `low_power` step from the main burn sequence (it left the box stuck and killed USB). Note: `low_power` is still sent inside `BurnStepEraseBootloader` as part of the upstream erase flow — that one is required and was kept.
- `devRead` / `epout.write` timeouts raised to 5000 ms (large partition transfers are more resilient)

### Enter the chroot from Termux
```bash
./termux/ubuntu
# inside the chroot, mounts are restored automatically by chroot-mount-restore.sh
```

## Dependencies
Only needed for the tool you actually use — most are optional.

| Tool | Needs |
|---|---|
| `ubt/` (flashing — the main tool) | Python 3 in the chroot with `pyusb` + `libusb-1.0`; `adb`/`fastboot` to reach burn mode |
| `pyamlboot/` (RAM-boot / SoC ID) | Same Python 3 + `pyusb`/`libusb-1.0` |
| `utgard/` (root research, build C) | Cross compiler `aarch64-linux-gnu-gcc` / `arm-linux-gnueabihf-gcc` |
| `dcow/` (root research, build C) | **Android NDK** (`ndk-build`) + `adb` — see `dcow/Makefile` |
| All of it on-device | Termux on the rooted phone + Ubuntu chroot (`CHROOT_DIR`)

Python dependencies can be installed with `pip install pyusb` (the only Python
package the current tools need). The C sources and root scripts use
`/data/local/tmp` on the **Android device** as their scratch path — that is
intentional, not a configurable option.

## Notes

Device-specific paths have been replaced with environment variables (see `.env.example`).
Copy it, adjust the values for your device, and source it before running helpers:

```bash
set -a; . ./.env; set +a
```


`utgard/run.sh` also accepts firmware-specific overrides (`SLOT_PHYS`, `KLN_ADDR`,
`GW`, `KF`) — see `.env.example`. These are **device/firmware-specific addresses**;
never guess them on a device you care about.

**If the box never appears as `1b8e:c003`:** you cannot flash with `ubt/`.
Recheck the OTG cable (data-capable), the ADB connection, and the burn-mode
entry path in Quick start. On this box, a PC-based Amlogic tool was the fallback
for a box already on Android 9.

## Research status
- ✅ Flashing Android 9 (atvXperience) from the phone via `ubt.py` — **successful**
- ⚠️ `utgard/`: the write primitive works, but SLOT_PHYS is hard to find and the GPU wedges easily — not stable
- ⚠️ `dcow/`: unsuccessful on this firmware

## License
This repo is a collection of third-party research tools. Each file keeps its
original license (SPDX headers where present — mostly GPL-2.0/MIT for the
SaluteDevices Amlogic tools and Apache-2.0/MIT for pyamlboot). Scripts without
an explicit header are provided as-is for research; do not assume a single
license covers the whole repository.
