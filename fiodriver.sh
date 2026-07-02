#!/usr/bin/env bash

# File-based, non-destructive benchmark driver.
# Each entry is a regular file path that fio will read/write.
# The file is created on first use by fio inside the mounted filesystem
# that holds it — no raw block-device I/O, no blkdiscard.
TESTFILES=( "./fio_testfile.dat" )
THREADS=1
IODEPTH=( 1 8 32 )
FIO_SCRIPTS='scripts'
# Per-job file size passed through to the .fio jobs.
SIZE="${SIZE:-1G}"
# Results land under results/<drive>/<timestamp>/ (gitignored). The drive
# name comes from -o, or is auto-derived from the disk backing the first
# TESTFILE. Override the root with RESULTS_ROOT.
RESULTS_ROOT="${RESULTS_ROOT:-results}"
source "$(dirname "$0")/helpers/drivename.sh"

function usage() {
        echo
        echo "Usage:"
        echo "      fiodriver.sh -o <output-dir> [-h]"
        echo
        echo "Options:"
        echo "      -o   Drive name / label. Results go to results/<name>/<timestamp>."
        echo "           Omit to auto-derive the name from the disk backing the test file."
        echo "      -h   Show usage"
        echo
        echo "Edit TESTFILES at the top of this script to point at the path(s)"
        echo "you want fio to read/write. Default: ./fio_testfile.dat"
        echo
        echo "Override the results root with the RESULTS_ROOT env var (default: results)."
        echo

        exit 1
}

while getopts ":o:h" opt
do
        case $opt in
		o)
			DRIVE="$OPTARG";;
                \?)
                        echo "ERROR: Invalid option: -$OPTARG" >&2; usage;;
                :)
                        echo "ERROR: Option -$OPTARG requires an argument." >&2; usage;;
                h | *)
                        usage;;
        esac
done

if [ -z "${DRIVE:-}" ]; then
        DRIVE=$(derive_drive_name "${TESTFILES[0]}")
fi

DATE=$(date "+%F_%R")
OUTPUT="${RESULTS_ROOT}/${DRIVE}/${DATE}"

mkdir -p "$OUTPUT"

STARTTIME=$(date +%s)

for TESTFILE in "${TESTFILES[@]}"; do
	# Label used in output dir names and plot titles. Derived from the
	# test-file basename so plotall.sh can still find the per-run dirs.
	LABEL=$(basename "$TESTFILE")
	LABEL="${LABEL%.*}"

	for IOD in ${IODEPTH[@]}; do
		# RANDOM WRITES
		SIZE="$SIZE" ./runfio.sh -t "$TESTFILE" -n "$THREADS" -i "$IOD" -f "${FIO_SCRIPTS}/rand-write.fio" -o "${OUTPUT}/rand_w_${LABEL}_${IOD}iodepth_${THREADS}threads"
		# RANDOM READS
		SIZE="$SIZE" ./runfio.sh -t "$TESTFILE" -n "$THREADS" -i "$IOD" -f "${FIO_SCRIPTS}/rand-read.fio"  -o "${OUTPUT}/rand_r_${LABEL}_${IOD}iodepth_${THREADS}threads"

		# SEQUENTIAL WRITES
		SIZE="$SIZE" ./runfio.sh -t "$TESTFILE" -n 1 -i "$IOD" -f "${FIO_SCRIPTS}/write.fio" -o "${OUTPUT}/seq_w_${LABEL}_${IOD}iodepth"
		# SEQUENTIAL READS
		SIZE="$SIZE" ./runfio.sh -t "$TESTFILE" -n 1 -i "$IOD" -f "${FIO_SCRIPTS}/read.fio"  -o "${OUTPUT}/seq_r_${LABEL}_${IOD}iodepth"
	done
	# Generate plots
	./plotall.sh "$OUTPUT" "$LABEL" "$THREADS" "${IODEPTH[@]}"

	# Clean up the test file fio created.
	if [ -f "$TESTFILE" ]; then
		rm -f "$TESTFILE"
	fi
done

ENDTIME=$(date +%s)
ELAPSEDTIME=$(($ENDTIME - $STARTTIME))
FORMATED="$(($ELAPSEDTIME / 3600))h:$(($ELAPSEDTIME % 3600 / 60))m:$(($ELAPSEDTIME % 60))s"

echo
echo
echo "  Overall time elapsed: $FORMATED"
echo
