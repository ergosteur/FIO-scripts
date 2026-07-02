#!/usr/bin/env bash
# derive_drive_name <path>
#
# Print a filesystem-safe name for the disk backing <path>, e.g.
#   WD_PC_SN7100S_SDFPMSL-1T00-1101_953.9G
# Used so the drivers can default their output to results/<drive>/ without
# the caller naming the drive. Falls back to "unknown_drive" when the disk
# can't be identified (no lsblk/findmnt, non-Linux, etc.).
#
# The auto name is verbose by design (it is deterministic, not pretty).
# Pass an explicit -o label to the drivers for a tidy name like WD_SN7100S_1T.
derive_drive_name() {
	local target="$1" dir src pk model size name
	dir=$(dirname "$target")
	src=$(findmnt -no SOURCE --target "$dir" 2>/dev/null | head -1)
	if [ -z "$src" ]; then
		echo "unknown_drive"
		return
	fi
	# Partition -> parent disk; whole-disk source has no PKNAME.
	pk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -1)
	[ -z "$pk" ] && pk=$(basename "$src")
	model=$(lsblk -dno MODEL "/dev/$pk" 2>/dev/null | head -1)
	size=$(lsblk -dno SIZE "/dev/$pk" 2>/dev/null | head -1)
	name=$(printf '%s %s' "$model" "$size" \
		| sed -e 's/[^A-Za-z0-9._-]\+/_/g' -e 's/^_\+//' -e 's/_\+$//')
	[ -z "$name" ] && name="unknown_drive"
	printf '%s\n' "$name"
}
