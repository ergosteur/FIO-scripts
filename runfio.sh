#!/usr/bin/env bash

block_sizes=( 4 8 16 32 64 128 256 512 1024 2048 4096 8192 )
SIZE="${SIZE:-1G}"

function usage() {
	echo
	echo "Usage:"
	echo "      runfio.sh -t <testfile> -n <njobs> -i <iodepth> -f <script> -o <output-dir> [-h]"
	echo
	echo "Options:"
	echo "      -t   Path to the test file (will be created if missing)"
	echo "      -n   Number of FIO processes/threads (numjobs)"
	echo "      -i   Number of outstanding I/Os (iodepth)"
	echo "      -f   Script containing the rest of FIO options"
	echo "      -o   Output directory"
	echo "      -h   Show usage"
	echo
	echo "Environment:"
	echo "      SIZE   Per-job file size for fio (default: 1G)"
	echo

	exit 1
}

while getopts ":t:n:i:f:o:h" opt
do
        case $opt in
                t)
                        case "$OPTARG" in
                                /dev/*)
                                        echo "ERROR: -t must be a regular file path, not a block device ($OPTARG)." >&2
                                        exit 1;;
                        esac
                        testfile="$OPTARG";;
                n)
                        njobs="$OPTARG";;
                i)
                        iodepth="$OPTARG";;
                f)
                        if [ ! -f "$OPTARG" ]; then
                                echo "ERROR: File $OPTARG does not exist." >&2; usage
                        fi
                        file="$OPTARG";;
		o)
			if [ ! -d "$OPTARG" ]; then
				mkdir "$OPTARG"
			fi
			directory="$OPTARG";;
                \?)
                        echo "ERROR: Invalid option: -$OPTARG" >&2; usage;;
                :)
                        echo "ERROR: Option -$OPTARG requires an argument." >&2; usage;;
                h | *)
                        usage;;
        esac
done

if [ -z "$testfile" ]; then
        echo "ERROR: Test file not specified" >&2
        usage
fi
if [ -z "$iodepth" ]; then
        echo "ERROR: I/O depth not specified" >&2
        usage
fi
if [ -z "$njobs" ]; then
        echo "ERROR: Number of jobs not specified" >&2
        usage
fi
if [ -z "$file" ]; then
        echo "ERROR: Script file not specified" >&2
        usage
fi
if [ -z "$directory" ]; then
        echo "ERROR: Output directory not specified" >&2
        usage
fi

testdir=$(dirname "$testfile")
if [ ! -d "$testdir" ]; then
        echo "ERROR: Parent directory of test file ($testdir) does not exist." >&2
        exit 1
fi

echo
echo "========================================================================"
echo
echo "Starting run with: $file"
echo
echo "    Test file: $testfile"
echo "    Size:      $SIZE"
echo "    IODEPTH:   $iodepth"
echo "    NUMJOBS:   $njobs"
echo
echo -n "    Block Size: "
STARTTIME=$(date +%s)
for bs in ${block_sizes[@]}; do
	echo -n "${bs}KB "
	{ SIZE="$SIZE" BLOCK_SIZE="${bs}k" TESTFILE="$testfile" IODEPTH="$iodepth" NJOBS="$njobs" fio "$file" ; } 2>&1 >> "${directory}/${bs}.txt"
done
echo
ENDTIME=$(date +%s)
ELAPSEDTIME=$(($ENDTIME - $STARTTIME))
FORMATED="$(($ELAPSEDTIME / 3600))h:$(($ELAPSEDTIME % 3600 / 60))m:$(($ELAPSEDTIME % 60))s"
echo
echo "    Benchmark time elapsed: $FORMATED"
echo
echo "========================================================================"
echo

./parser.sh "$directory" "${block_sizes[@]}"
