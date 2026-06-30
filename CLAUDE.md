# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A shell-driven fio benchmark suite that runs read/write workloads at several
block sizes and queue depths, parses fio's text output to CSV, and produces
EPS throughput plots.

## Pipeline

Two shell drivers wrap a single fio invocation per (workload, iodepth,
block-size) cell:

```
fiodriver.sh        sweeps TESTFILES × IODEPTH × { rand-write, rand-read,
  ↓                 write, read }
runfio.sh           sweeps block_sizes for one (testfile, iodepth, .fio job)
  ↓ runs fio        passes vars via env: TESTFILE, SIZE, BLOCK_SIZE,
  ↓                 IODEPTH, NJOBS — these are interpolated into the .fio job
parser.sh           per-bs fio stdout → out.txt (CSV: "Block Size (KB),
  ↓                 Throughput (MB/s|KB/s)"); unit is decided by the largest
  ↓                 block-size run and rows are converted to match.
                    Branches on fio major version (3 uses `bw=`, older uses
                    `aggrb=`).
plotall.sh          driver-only; fans out plotfio.py once per workload class
plotfio.py          one CSV-set → one EPS
```

`scripts/*.fio` are fio job templates with `${TESTFILE}`, `${SIZE}`,
`${BLOCK_SIZE}`, `${IODEPTH}`, `${NJOBS}` placeholders — all populated by
`runfio.sh`. Adding a new workload means adding a `.fio` here and wiring it
into `fiodriver.sh`'s per-iodepth block.

## Output-directory naming contract

`fiodriver.sh` writes results to `<output-dir>/<YYYY-MM-DD_HH:MM>/` with
per-run subdirectories whose names are load-bearing:

```
rand_w_<LABEL>_<IOD>iodepth_<THREADS>threads/
rand_r_<LABEL>_<IOD>iodepth_<THREADS>threads/
seq_w_<LABEL>_<IOD>iodepth/
seq_r_<LABEL>_<IOD>iodepth/
```

`plotall.sh` reconstructs these paths from `(LABEL, THREADS, IODEPTHS...)`
positional args, so the naming pattern in `fiodriver.sh` and the
reconstruction in `plotall.sh` must stay in sync. `LABEL` is currently
derived from the test file's basename (extension stripped).

## Safety invariants (do not regress)

The suite was refactored from raw-block-device targeting to file-based I/O
on branch `safe-file-based-fio`. The destructive paths must stay removed:

- `scripts/*.fio` use `filename=${TESTFILE}` — never `/dev/${DEVICE}`.
- `runfio.sh` does not call `blkdiscard` and does not need `sudo`.
- `runfio.sh`'s `-t` flag rejects any path under `/dev/`.

Keep `direct=1` in the .fio jobs so numbers reflect the device, not the
page cache.

## Branches

- `master` — original upstream interface (raw block device, blkdiscard,
  size=80%). Destructive on a boot drive. Do not develop new features here;
  rebase off `safe-file-based-fio`.
- `safe-file-based-fio` — file-based refactor, the working baseline.
- `cdm-config` — `safe-file-based-fio` plus a 2-line trim of `block_sizes`
  and `IODEPTH` to a CrystalDiskMark-style matrix (full run ≈ 8 min vs ≈ 80
  min).

## Common commands

Full sweep (edit `TESTFILES` in `fiodriver.sh` first):
```bash
./fiodriver.sh -o <output-dir>
```

Single workload + iodepth (file size override via `SIZE`, default 1G):
```bash
SIZE=1G ./runfio.sh -t ./fio_testfile.dat -n 1 -i 32 \
  -f scripts/rand-write.fio -o out_rand_w_q32
```

Re-plot an existing run without re-benchmarking:
```bash
./plotall.sh <output-dir>/<timestamp> <LABEL> <THREADS> <IOD1> <IOD2> ...
```

Syntax-check the shell scripts:
```bash
bash -n fiodriver.sh runfio.sh parser.sh plotall.sh
```

## Gotchas

- **`helpers/plotall_merged.sh` is stale.** It's a hand-edit template for
  cross-device comparison plots (HDD vs SSD vs NVMe), still using the old
  device-based directory naming (`rand_w_sdb_*`, `rand_w_nvme1n1_*`). If
  you regenerate cross-device plots, update both the absolute paths at the
  top and the directory names to match the current basename-derived label.
- **`parser.sh` reads the *largest* block-size file first** to decide the
  unit (KB/s vs MB/s) for the whole CSV, then converts other rows. If you
  change `block_sizes`, the last element of the array still drives unit
  selection.
- **`plotfio.py`'s `-m` (markers) has no length check** — passing fewer
  markers than `-f` files crashes with `IndexError`.
- **`fiodriver.sh` deletes the test file after each `TESTFILES` entry** —
  intentional cleanup, but means a crashed run can leave the file behind.
