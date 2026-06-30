# Description
This is a FIO benchmark suite. Using the scripts below you can generate
datasets and plots regarding filesystem/storage throughput.

The scripts run fio against a **regular file** on a mounted filesystem — they
do not write to raw block devices and do not issue `blkdiscard`. This means
they are safe to run on a live system (including the boot drive), at the cost
of measuring filesystem throughput rather than raw-device throughput. Heavy
I/O can still make the system feel sluggish during a run.

# Dependencies

**System packages**
- `fio` — the benchmark itself. Install via your package manager
  (e.g. `apt install fio` on Debian/Ubuntu, `dnf install fio` on Fedora,
  `brew install fio` on macOS).
- `bash`, `coreutils` — used by the shell drivers.
- Python 3.6+ — used by `plotfio.py` for plotting.

**Python packages** (used only by `plotfio.py`)
- `matplotlib` — renders the throughput plots (EPS output via the `Agg`
  backend, so no display server required).
- `numpy` — used for evenly spacing the (power-of-2) block-size ticks on
  the x-axis.

Install the Python dependencies one of two ways:

- **System packages (recommended on Debian/Ubuntu)** — both libraries are
  packaged, so apt is simplest:
  ```bash
  sudo apt install python3-matplotlib python3-numpy
  ```
  On Fedora: `sudo dnf install python3-matplotlib python3-numpy`.

- **pip / virtualenv** — if you want isolated versions or are on a distro
  without these packages. Recent Debian/Ubuntu marks the system Python as
  externally managed (PEP 668), so use a venv:
  ```bash
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
  ```

Versions are unpinned — any recent release of each package is fine. If you
only want to run the benchmarks and skip plotting, you can skip the Python
deps entirely and read the per-run `out.txt` files directly (they are CSV).

# Run the fiodriver.sh script
First, edit `fiodriver.sh` and set `TESTFILES` to one or more paths on the
filesystem you want to benchmark (the file will be created by fio if it does
not exist and removed after the run). The default is `./fio_testfile.dat`.
Each test file needs at least `SIZE` of free space available (default 1 GiB,
override with the `SIZE` env var).

Then run the script like this:
```
Usage:
	fiodriver.sh -o <output-dir> [-h]

Options:
	-o   Output directory
	-h   Show usage
```
An example run is the following:
```bash
fiodriver.sh -o SAMSUNG_850_PRO
```
By default, the script will run with:
- random/sequential reads and writes
- for a variety of different I/O queue depths
- for different block sizes

All output is saved in the 'output-dir' folder (e.g. SAMSUNG_850_PRO). The
script will also generate various plots based on your configuration. For a
finer-grained control of the runs, you can execute the runfio.sh and plotfio.sh
scripts manually.

# Run scripts manually
To run FIO against a test file manually use the runfio.sh script:
```
Usage:
       runfio.sh -t <testfile> -n <njobs> -i <iodepth> -f <script> -o <output-dir> [-h]

Options:
       -t   Path to the test file (will be created if missing)
       -n   Number of FIO processes/threads (numjobs)
       -i   Number of outstanding I/Os (iodepth)
       -f   Script containing the rest of FIO options
       -o   Output directory
       -h   Show usage

Environment:
       SIZE   Per-job file size for fio (default: 1G)
```
An example run is the following:
```bash
runfio.sh -t /path/to/fio_testfile.dat -n 1 -i 32 -f scripts/rand-write.fio -o random_writes
```
This configuration will run with a variety of different block sizes by default.
Apart from the output produced for each block size, in the end we will have a
csv type file with name "out.txt" holding the throughput achieved for each
block size.

Paths under `/dev/` are explicitly rejected by `-t` so you cannot accidentally
point the suite at a raw block device.

In order to create a plot from the output, you can use the plotfio.py script:
```
Usage:
       plotfio.py [ -h ]
                    -f FILES      [FILES ... ]
                    -l LABELS    [LABELS ... ]
                  [ -m MARKERS  [MARKERS ...]]
                  [ -s SCALE ]
                    -x XLABEL
                    -y YLABEL
                    -o OUTPUTFOLDER
                    -n NAME
                    -t TITLE

Options:
       -h, --help                Show this help message and exit
       -f FILES     [FILES ...]  The out.txt files
       -l LABELS   [LABELS ...]  Label for each curve
       -m MARKERS [MARKERS ...]  Marker for each curve
       -s SCALE                  Scale of y-axis
       -x XLABEL                 Label of x-axis
       -y YLABEL                 Label of y-axis
       -o OUTPUTFOLDER           Ouput folder
       -n NAME                   Name of output plot
       -t TITLE                  Title of output plot

```
An example run is the following:
```bash
plotfio.py -f rand_w_fio_testfile_1iodepth_1threads/out.txt rand_w_fio_testfile_32iodepth_1threads/out.txt \
           -l "iodepth-1" "iodepth-32"                                                                     \
           -x "Request Size (KB)"                                                                          \
           -y "Throughput (MB/s)"                                                                          \
           -o "SAMSUNG_850_PRO"                                                                            \
           -n "rand_w_fio_testfile"                                                                        \
           -t "Random Writes on Samsung 850 Pro"
```

The per-run directory names are derived from the test file's basename (with
the extension stripped). For example, `TESTFILE=./fio_testfile.dat` produces
directories like `rand_w_fio_testfile_1iodepth_1threads/`.
