# Utgard experiments (archive)

These are **research/debug scripts**, not part of the main chain. They were used
while trying to locate `SLOT_PHYS` (`sys_call_table[244]`) on the test box.

**Do not run these expecting a stable result.** They caused repeated GPU wedges
and box reboots during testing — see the root README for the full risk warning.

| Script | What it tried |
|---|---|
| `scan_slot.sh`, `scan_safe.sh` | Naive physical-page scans writing a machine-code canary (`movz x0,#0x1234; ret`). **Do not run** — the `scan_safe.sh` canary lives in persistent_ram (`0x07300000`), outside System RAM, which wedged/crashed the test box. |
| `scan_oracle.sh`, `scan_oracle2.sh`, `scan_oracle3.sh` | Scans using `kallsyms_lookup_name` as the canary and `kfunc sym` as the oracle. |
| `probe_one.sh` | Single-address write + resolve probe (one shot per reboot). |
| `retry_scan.sh` | Retried a few hand-picked SLOT_PHYS candidates with the KLN canary. |
| `try_offset.sh`, `try_sym.sh`, `try_survive.sh` | Offset variants and canary strategies during debugging. |

The main chain is `utgard/run.sh` — use that as the reference, not these.
