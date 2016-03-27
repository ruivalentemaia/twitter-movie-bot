#!/bin/bash

working_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
output_file="$working_dir/status.txt"
opensubtitles_download_url=http://dl.opensubtitles.org/en/download/sub/

#	Arguments:
#		$1 - current subtitle id
#		$2 - max subtitle id

# in case there are no arguments passed, reads status files.
if [ $# -le 1 ]; then
	echo "No arguments supplied."
	echo "Reading from status file $output_file."
	if [ -e "$output_file" ]; then
		while IFS=, read -r -a params; do
			current="${params[0]}"
			max="${params[1]}"
		done < "$output_file"
	else
		echo "Status file does not exist."
		echo "Try: bash opensubtitles.sh <index_start> <index_end>."
		echo "Try: Create file status.txt in project's root dir with content <index_start>,<index_end>."
		exit
	fi
#in case there are arguments, assigns them to the following variables.
else
	current=$1
	max=$2
fi

echo "Now: $current, Max: $max"

if [ "$current" -le "$max" ] 
then
	for ((i = $current; i <= $max; i++)); do
		echo "$current,$max" > "$output_file"
		echo "Getting subtitle from $opensubtitles_download_url$i."
		wget --server-response -o wgetOut $opensubtitles_download_url$i

		#in case there's a 301 response, it'll be necessary to fill a captcha.
		if grep -R "301 Moved Permanently" wgetOut > /dev/null
		 then
			rm wgetOut
			rm $i
			echo "Captcha is working. Waiting 10s and retrying."
			google-chrome $opensubtitles_download_url$i
			sleep 10s
			((i--))
			continue
		else
			unzip "$i" '*.srt' '*.sub' -d raw
			rm $i
			#sleep $[ ( $RANDOM % 5 )  + 1 ]s
		fi
	done

#in case $current is not lower or equal to $max
else
	echo "Arguments don't make sense."
	echo "Usage: bash opensubtitles.sh <index_start> <index_end>."
	echo "<index_start> should be lower than <index_end>."
	exit
fi
