# smartbox-tools

[![CI](https://github.com/marufalfan8-blip/smartbox-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/marufalfan8-blip/smartbox-tools/actions/workflows/ci.yml)

A collection of tools and scripts for customizing **Amlogic smart TV boxes (S905X / p212)** from an Android phone + Ubuntu chroot.

Focus: flashing via USB Burn Mode, root research, and chroot/Termux environment helpers.

**Why this exists:** most guides say you need a Windows PC + Amlogic USB Burning Tool to flash these boxes. These tools do it **from the phone only** — no PC — using the USB OTG port and a Python burn tool running inside a chroot.

> Note: this is a collection of research tools. It does **not** include firmware, APKs, or backup files.

## Contents

- [Quick start](#quick-start-the-4-steps-that-actually-worked)
- [⚠️ Read this before using anything](#-read-this-before-using-anything)
- [Device requirements](#device-requirements)
- [Layout](#layout)
- [Folder-by-folder guide](#folder-by-folder-guide)
- [Quick usage](#quick-usage)
- [One-command entrypoint](#one-command-entrypoint)
- [Dependencies](#dependencies)
- [Notes](#notes)
- [Research status](#research-status)
- [License](#license)

## Quick start (the 4 steps that actually worked)

Prerequisite: `CHROOT_DIR` set and `.env` sourced (see **Notes → Configuration**),
and `termux/chroot-mount.sh` copied to your Termux home.

1. **Enter the chroot:** from Termux, run `./termux/ubuntu`.
2. **Confirm ADB sees the box:** `adb devices` must show `<serial> device`
   (if empty/offline/authorizing, see **Notes → If the box never enters burn mode**).
3. **Enter burn mode `1b8e:c003`:** with the box still on its original Android 7,
   run `adb reboot fastboot` from inside the chroot, then verify:
   ```bash
   python3 -c "import usb.core; print(bool(usb.core.find(idVendor=0x1b8e,idProduct=0xc003)))"
   ```
   must print `True`. (Android 9 boxes: this path is unverified — see **Notes**.)
4. **Flash:**
   ```bash
   cd ubt && python3 ubt.py --img ROM.img --no-erase-bootloader --reset
   ```

All on the phone — no PC. For details (tool modifications, `ubt.py` options),
see **Quick usage**; for problems, see **Notes**.

> ⚠️ **Before flashing:** read the risk warnings next — a wrong ROM or an
> interrupted flash can permanently brick the box.

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
- **Root/exploit tools are research only.** `research/utgard/` and
  `research/dcow/` crashed the test box repeatedly and are **not stable**. Do
  not run them on a device you cannot afford to lose.
- **`research/utgard/roothelper.sh` is a backdoor by design.** It can install a
  setuid-root `su` from `/data/local/tmp/su` and can enable **adb over TCP
  (port 5555)** if `/data/local/tmp/ENABLE_ADB_TCP` exists. adb TCP exposes
  root access on the network. Use it only on an isolated box and follow
  **[Cleanup after root research](#cleanup-after-root-research)** afterwards.
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

See `.env.example` for the path variables used by the helper scripts.

## Layout

```
ubt/              USB Burn Tool — the actual ROM flashing tool (main tool)
bootrom-scripts/  standalone bootROM scripts (RAM-boot, SoC ID)
chroot/           scripts that run inside the Ubuntu chroot
termux/           scripts that run on the phone (Termux)
research/         archived experiments — NOT production paths
  utgard/         Utgard LPE root research (Mali-400 GPU write primitive)
  dcow/           DirtyCow CVE-2016-5195 PoC
smartbox          single entrypoint: check / flash / rescue / socid
setup.sh          copy the Termux mount helper and check dependencies
requirements.txt  Python dependencies
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

### `research/utgard/` — Utgard LPE root research (Mali-400 GPU write primitive)
Archived research into the Mali-400 (Utgard) GPU driver bug on Android 7 Amlogic
boxes: an arbitrary physical-memory write primitive. **Not stable** — see
Research status. Not part of the flashing workflow.

| File | Purpose | Usage |
|---|---|---|
| `src/*.c` | C sources: write primitive (`gpwrite*`, `gpu_arb_write*`), syscall helpers (`kfunc`, `kread`), SLOT_PHYS scanners (`gpu_scan*`), ION probes, and `crash_for_core.c` (triggers the core dump that runs the `core_pattern` root helper). Some files (`gpwrite-ion.c`, `ionprobe*.c`, `gpu_arb_write64.c`, `gpu_scan_slot.c`) are unused research leftovers — not built by the default `Makefile`. | Build with `make` (needs cross compiler) |
| `run.sh` | Drives the full chain: point syscall slots at `kallsyms_lookup_name`, resolve symbols, patch SELinux, trigger a root helper via `core_pattern`. | `SLOT_PHYS=... KLN_ADDR=... ./run.sh` |
| `roothelper.sh`, `root_cmd.sh` | Payload run as root after the chain succeeds (scripts), not compiled. `roothelper.sh` can install a setuid su (if `/data/local/tmp/su` exists) and enables adb TCP only if `/data/local/tmp/ENABLE_ADB_TCP` exists; see **[Cleanup after root research](#cleanup-after-root-research)**. | Used by `run.sh` |
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
| `dd-throttled.py` | **Optional** — write an image to an SD card at 2 MB/s (avoids heat/voltage drops). Not needed for the USB flash path. Requires `CONFIRM=yes` and a block device as `DD_DST`; it also refuses an image larger than the device. **Double-check `DD_DST`** — wrong device destroys data. | `DD_SRC=img DD_DST=/dev/block/sdX CONFIRM=yes python3 dd-throttled.py` |

### `research/dcow/` — DirtyCow (CVE-2016-5195) research
Archived classic Android root PoC over ADB. **Unstable on the tested firmware** —
keep it as research reference, not as a primary root path.

| File | Purpose |
|---|---|
| `dirtycow.c`, `dcow.c`, `run-as.c` | Exploit implementations (common DirtyCow variants). |
| `dirtycow-dbg.c`, `dcow-dbg-main.c` | Debug variants. |
| `Makefile` | Builds via `ndk-build` with ABI/SDK detected from `adb shell getprop`. Targets: `build`, `push`, `root`, `clean` (requires a connected ADB device). |
| `aml_image_packer.py` | Amlogic firmware image packer (from SaluteDevices, GPL-2.0/MIT). It imports `amlimage` from the single bundled copy in `ubt/pyamlboot/` (path bootstrap at the top of the file) — there is no local duplicate. |
| `Android.mk` | NDK build script for `dirtycow` and `run-as` (referenced by `Makefile`). |

Usage (requires Android NDK + `adb`):
```bash
cd research/dcow
make root      # build -> push to device -> run
make clean
```

### `bootrom-scripts/` — Standalone Amlogic bootROM scripts
Pure-Python tools that talk to the Amlogic bootROM while the device is in
**burn mode `1b8e:c003`**. Two scripts:

| File | Purpose | Usage |
|---|---|---|
| `boot.py` | RAM-boot the device: send DDR + U-Boot + image, run temporarily (no eMMC write). Useful for unbricking/exploration. | `python3 boot.py <board> [--board-files DIR] [--image FILE] [--script FILE] [--fdt FILE] [--ramfs FILE] [--timeout MS]` (see `choices` in source for boards) |
| | **Note:** this folder holds only 2 scripts — the `pyamlboot` Python package itself (`pyamlboot.py`, board `files/`) is imported from the installed distribution, not bundled here. | |
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
`all` erases all partitions), `--password FILE` (for password-locked
bootloaders), `--no-erase-bootloader` (skip the separate bootloader-erase step).
`--password` and `--no-erase-bootloader` apply to **OPTIMUS images only**; the
tool rejects them for ADNL images instead of silently ignoring them.
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

### One-command entrypoint

`smartbox` wraps the common workflows. From the repo root, after `./setup.sh`
and sourcing `.env`:

```bash
./smartbox check                                  # burn mode 1b8e:c003? (read-only)
./smartbox flash --img ROM.img --no-erase-bootloader --reset
./smartbox rescue --img ROM.img                   # wait for burn mode, then flash
./smartbox socid                                  # read SoC ID from bootROM
```

`flash` passes arguments straight to `ubt/ubt.py` and falls back to `ROM_IMG`
from `.env` when `--img` is omitted. `rescue` polls up to 60 s for the device,
flashes with the tested defaults, and retries at most 5 times for the usual USB
dropouts — it never erases the bootloader. `./setup.sh` copies
`termux/chroot-mount.sh` into `$TERMUX_HOME` and checks dependencies;
`./setup.sh --install` also installs `requirements.txt`.

## Dependencies
Software to install (the hardware requirements are in Device requirements above).
Only what the tool you actually use needs — most are optional.

| Tool | Needs |
|---|---|
| `ubt/` (flashing — the main tool) | Python 3 in the chroot with `pyusb` + `libusb-1.0`; `adb`/`fastboot` to reach burn mode |
| `bootrom-scripts/` (RAM-boot / SoC ID) | Same Python 3 + `pyusb`/`libusb-1.0` |
| `research/utgard/` (archived, build C) | Cross compiler `aarch64-linux-gnu-gcc` / `arm-linux-gnueabihf-gcc` |
| `research/dcow/` (archived, build C) | **Android NDK** (`ndk-build`) + `adb` — see `research/dcow/Makefile` |
| All of it on-device | Termux on the rooted phone + Ubuntu chroot (`CHROOT_DIR`)

Python dependencies: `pip install -r requirements.txt` (or just `pip install
pyusb`). Note that `ubt/pyamlboot/` is bundled on purpose — the pip `pyamlboot`
package alone does not contain `optimus.py`, `amlimage.py` or `usb_backend.py`.
The C sources and root scripts use
`/data/local/tmp` on the **Android device** as their scratch path — that is
intentional, not a configurable option.

## Notes

### Configuration
Device-specific paths were replaced with environment variables (see `.env.example`).
`TERMUX_PREFIX` (default `/data/data/com.termux/files/usr`) is where
`chroot-mount.sh` reads Termux's `resolv.conf`; `TERMUX_HOME` is where the
mount helper is copied. Copy `.env.example`, adjust the values for your device,
and source it before running helpers:

```bash
set -a; . ./.env; set +a
```

`research/utgard/run.sh` also accepts firmware-specific overrides (`SLOT_PHYS`, `KLN_ADDR`,
`GW`, `KF`) — see `.env.example`. These are **device/firmware-specific addresses**;
never guess them on a device you care about.

### If the box never enters burn mode
If the verify command in Quick start step 3 keeps printing `False`, `ubt/` cannot
flash. Check, in order:

1. **Cable** — USB-A–A must be data-capable (charge-only cables silently fail).
2. **ADB** — `adb devices` must show `<serial> device`, not `offline`/`authorizing`.
3. **Entry path** — `adb reboot fastboot` must be sent while the box is still on
   its original Android 7 (see Quick start step 3).

For a box already on Android 9, this entry path is unverified — see the note in
Quick start step 3 for the PC-tool fallback.

### Cleanup after root research
If `research/utgard/run.sh` reached stage 5 and `roothelper.sh` ran, undo its changes:

1. **Disable adb over TCP** (only enabled if you created the marker):
   ```sh
   rm -f /data/local/tmp/ENABLE_ADB_TCP
   setprop service.adb.tcp.port ""
   setprop persist.adb.tcp.port ""
   ```
2. **Remove the setuid su** you installed (do not delete a su that shipped with
   the device):
   ```sh
   mount -o rw,remount /system
   rm -f /system/xbin/su
   ```
3. **Re-enable SELinux:** `setenforce 1` (verify with `getenforce`).
4. **Reset `core_pattern`:** a reboot is the simplest and restores the default;
   otherwise `echo core > /proc/sys/kernel/core_pattern`.
5. **Delete the research files** from `/data/local/tmp` (binaries, scripts,
   `root.log`, `su`), then reboot.

A reboot clears the non-persistent `service.adb.tcp.port`; the `persist.*` prop
survives until you clear it.

## Research status

| Path | Result | Notes |
|---|---|---|
| Flash ROM from phone (`ubt/`) | ✅ **Success** | Android 9 (atvXperience) flashed end-to-end from the phone, no PC. This is the working path. |
| Root via Utgard LPE (`research/utgard/`) | ⚠️ Unstable | The arbitrary physical-write primitive works, but locating `SLOT_PHYS` (`sys_call_table[244]`) was never reliable — GPU wedges and box crashes ended the attempt. Kept as a research archive, not a usable root method. |
| Root via DirtyCow (`research/dcow/`) | ❌ Unsuccessful | The race never won on this firmware. Kept as reference only. |

The two root paths are **archived failures**, not recommended methods — they are
included so the research is not lost. The flashing path is the one that works.

## License
Files written for this repo carry `SPDX-License-Identifier: MIT` and are covered
by [LICENSE](LICENSE). Third-party components keep their original licenses —
there is no single repo-wide license. Check the SPDX header in each file before
reuse.

| Group | License (from SPDX headers) |
|---|---|
| `ubt/` (SaluteDevices Amlogic tools) | mostly `GPL-2.0 OR MIT`; `ubt/pyamlboot/pyamlboot.py` is `Apache-2.0 OR MIT` |
| `research/dcow/` (DirtyCow PoC + image packer) | `GPL-2.0 OR MIT` |
| `bootrom-scripts/` (standalone scripts) | `Apache-2.0 OR MIT` |
| `chroot/`, `termux/`, `research/utgard/` (scripts and C sources written for this repo), `chroot/dd-throttled.py`, `smartbox`, `setup.sh` | `MIT` — see [LICENSE](LICENSE) |
| `__init__.py` package markers | provided as-is for research |

`ubt/pyamlboot/` is the single bundled pyamlboot package (with the stability
fixes used by the successful flash). The old byte-identical copies formerly in
`dcow/` were removed; `research/dcow/aml_image_packer.py` imports from `ubt/` via a path
bootstrap. The `bootrom-scripts/` folder holds two **scripts** that use the
pip-installed package — it is not a second package copy. Do not assume one
license covers the whole repository.
