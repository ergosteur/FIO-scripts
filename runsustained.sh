#!/usr/bin/env bash
# Single-pass sustained sequential-write test.
#
# Writes a large file once through (no time_based) so the write exceeds the
# drive's pseudo-SLC cache and settles to the true NAND write speed. Per-
# second bandwidth is logged and reduced to throughput_over_time.csv, which
# captures the "cliff" a short (20 s) burst test can never show.
#
# File-based and non-destructive — same invariants as runfio.sh: -t must be
# a regular file, never a block device; no blkdiscard; no sudo.

SIZE="${SIZE:-100G}"
IODEPTH=32
BLOCK_SIZE=1M
RESULTS_ROOT="${RESULTS_ROOT:-results}"
FIO_JOB="$(dirname "$0")/scripts/sustained-write.fio"
source "$(dirname "$0")/helpers/drivename.sh"

function usage() {
	echo
	echo "Usage:"
	echo "      runsustained.sh -t <testfile> [-o <drive>] [-i <iodepth>] [-b <blocksize>] [-h]"
	echo
	echo "Options:"
	echo "      -t   Path to the test file (created if missing; never a /dev/ node)"
	echo "      -o   Drive name / label (results go to results/<name>/<timestamp>)"
	echo "      -i   Queue depth (default: 32)"
	echo "      -b   Block size (default: 1M)"
	echo "      -h   Show usage"
	echo
	echo "Environment:"
	echo "      SIZE          Bytes written in one pass (default: 100G). Set ABOVE the"
	echo "                    drive's SLC cache and BELOW its free space to see the cliff."
	echo "      RESULTS_ROOT  Output root (default: results)"
	echo

	exit 1
}

while getopts ":t:o:i:b:h" opt
do
	case $opt in
		t)
			case "$OPTARG" in
				/dev/*)
					echo "ERROR: -t must be a regular file path, not a block device ($OPTARG)." >&2
					exit 1;;
			esac
			testfile="$OPTARG";;
		o)
			DRIVE="$OPTARG";;
		i)
			IODEPTH="$OPTARG";;
		b)
			BLOCK_SIZE="$OPTARG";;
		\?)
			echo "ERROR: Invalid option: -$OPTARG" >&2; usage;;
		:)
			echo "ERROR: Option -$OPTARG requires an argument." >&2; usage;;
		h | *)
			usage;;
	esac
done

if [ -z "${testfile:-}" ]; then
	echo "ERROR: Test file not specified" >&2
	usage
fi

testdir=$(dirname "$testfile")
if [ ! -d "$testdir" ]; then
	echo "ERROR: Parent directory of test file ($testdir) does not exist." >&2
	exit 1
fi

if [ -z "${DRIVE:-}" ]; then
	DRIVE=$(derive_drive_name "$testfile")
fi

DATE=$(date "+%F_%R")
OUT="${RESULTS_ROOT}/${DRIVE}/${DATE}/sustained_write"
mkdir -p "$OUT"
BW_LOG="${OUT}/bw"

echo
echo "========================================================================"
echo
echo "Sustained write: ${SIZE} single-pass, bs=${BLOCK_SIZE}, iodepth=${IODEPTH}"
echo
echo "    Test file: $testfile"
echo "    Output:    $OUT"
echo

STARTTIME=$(date +%s)
SIZE="$SIZE" BLOCK_SIZE="$BLOCK_SIZE" IODEPTH="$IODEPTH" TESTFILE="$testfile" BW_LOG="$BW_LOG" \
	fio "$FIO_JOB" 2>&1 | tee "${OUT}/fio.out"
ENDTIME=$(date +%s)

# fio writes ${BW_LOG}_bw.1.log with "time_ms, bw_KBps, ..." rows.
# Reduce to per-second MB/s for plotting.
LOG="${BW_LOG}_bw.1.log"
if [ -f "$LOG" ]; then
	echo "Seconds,Throughput (MB/s)" > "${OUT}/throughput_over_time.csv"
	awk -F', *' '{printf "%d,%.0f\n", $1/1000, $2/1024}' "$LOG" >> "${OUT}/throughput_over_time.csv"
	echo
	echo "    Wrote ${OUT}/throughput_over_time.csv"
fi

ELAPSEDTIME=$(($ENDTIME - $STARTTIME))
FORMATED="$(($ELAPSEDTIME / 3600))h:$(($ELAPSEDTIME % 3600 / 60))m:$(($ELAPSEDTIME % 60))s"
echo
echo "    Time elapsed: $FORMATED"
echo
echo "========================================================================"
echo

# Clean up the (large) test file fio created.
if [ -f "$testfile" ]; then
	rm -f "$testfile"
fi
