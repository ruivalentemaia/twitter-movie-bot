#!/bin/bash

#urls
website=https://mvsubtitles.com/
movie_listing=https://mvsubtitles.com/country/english-subtitles?p=

#folders
working_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
meta_folder="$working_dir/meta/"

#output/helping files 
output_file=pagehtml.txt
movie_url_file=movie_urls.txt
dl_meta_filename="$meta_folder/downloads.txt"
status_downloads=status_downloads_mvsubtitles.txt

# numerical variables
last=-1
index_start=1
SECONDS=0

#boolean variables
found=false #states if the download url has been found for each movie page.

# the $status_downloads only exists if the crawling has started already.
# in case it exists, it reads it and restarts the crawling.
if [ -e "$status_downloads" ]; then
	for line in $(cat "$status_downloads"); do
		last=$(echo "$line" | cut -d \, -f 1)
		index_start=$(echo "$line" | cut -d \, -f 2)
		SECONDS=$(echo "$line" | cut -d \, -f 3)
	done
	echo "Last detected: $last."
	echo "Index detected: $index_start."
	echo "Number of seconds elapsed: $SECONDS."

# in case it does not, it has to crawl the first page for the max number
# of pages to crawl in order to retrieve all movies.
else
	wget -q -O $output_file $movie_listing$index_start
	if [ -e "$output_file" ]; then
		for line in $(cat "$output_file"); do
			if [[ $line == *">Last"* ]]; then
				last=$(echo "$line" | 
					cut -d \? -f 2 | cut -d \= -f 2 | cut -d \" -f 1)
				echo "Last page detected: $last"
			fi
		done
	else 
		echo "Sorry, output file does not exist."
		exit
	fi
fi

# now we got the last page, let's start parsing each one of the pages.
# in case the variable $index_start is still at 0, it means that
# the crawling is starting from the beginning, meaning that we'll
# need to crawl the movies list page and register all of them in the
# $movie_url_file.
if [[ $index_start == 0 ]]; then
	for ((i=$index_start; i <= $last; i++)); do
		echo $'\n'" --- Parsing page: $i. --- "
		echo $'\t'"Running for $SECONDS s."$'\n'
		wget -q -O $output_file $movie_listing$i
		if [ -e "$output_file" ]; then
			for line in $(cat "$output_file"); do
				if [[ "$found" == true ]]; then
					url=$(echo "$line" | cut -d  \/ -f 2 | cut -d \" -f 1)
					if [ -e "$movie_url_file" ]; then
						echo $'\t'"Wrote movie URL: $website$url".
						echo "$website$url,0" >> "$movie_url_file"
					else
						echo "Creating movie URL list..."
						echo "$website$url,0" > "$movie_url_file"
					fi
				fi
				if [[ $line == *"<h3>"* ]]; then
					found=true
					continue
				else
					found=false
				fi
			done
		
		#in case output_file does not exist.
		else
			echo "Sorry, output file does not exist."
		fi
	done
else
	echo "Movie list exists already. Starting to download files."
fi

# starts downloads of subtitles, by reading each one of the links from
# the $movie_url_file, crawling it, finding the download url, downloading it,
# unzipping it, registering it in the $dl_meta_filename variable and cleaning 
# all temp files up in the end.
echo $'\n'"--- Starting downloads of subtitles ---"$'\n'
file_line=$index_start
index_breaker=0
for line in $(cat "$movie_url_file"); do
	if [[ "$index_start" != 0 ]]; then
		for((i=$index_breaker;i<$index_start;i++)); do
			if [[ "$index_breaker " != "$index_start" ]]; then
				((index_breaker++))
				break
			fi
		done
	fi
	if [[ "$index_breaker" != "$index_start" ]]; then
		continue
	fi
	url=$(echo "$line" | cut -d \, -f 1)
	status=$(echo "$line" | cut -d\, -f 2)
	echo $'\t'"Parsing $url listed in $movie_url_file line $file_line."
	wget -q -O $output_file $url
	if [ -e "$output_file" ]; then
		if [ ! -d "$meta_folder" ]; then
			mkdir "$meta_folder"
		fi
		for html_line in $(cat "$output_file"); do
			if [[ ($html_line == *"/download/"*) && ($html_line == *"/english/"*) ]]; then
				sub_url=$(echo $html_line | cut -d \" -f 2)
				language=$(echo $sub_url | cut -d \/ -f 4)
				id=$(echo $sub_url | cut -d \/ -f 5)
				echo $'\t\t'"Running for $SECONDS s."
				echo $'\t\t'"Downloading $sub_url of language $language."
				wget -q $website$sub_url
				echo $'\t\t'"Extracting $website$sub_url."
				for zip in "$id"; do
					zip_filename="${zip%%.*}"
					unzip -qq "${zip}" '*.srt' -d "${zip_filename}-dir"
					for file in "${zip_filename}-dir"/*.*; do
	        			extension="${file##*.}"         
	        			new_name="${zip_filename}.${extension}"
	        			mv "${file}" "raw/${new_name}"
						if [ -e "$dl_meta_filename" ]; then
							echo "$file_line,$website$sub_url,$language,raw/${new_name}" >> "$dl_meta_filename"
						else
							echo "$file_line,$website$sub_url,$language,raw/${new_name}" > "$dl_meta_filename"
						fi
	    			done
	    			rmdir "${zip_filename}-dir"
				done
				rm $id
				break
			fi
		done
	else
		echo "Could not find $output_file for $url."
	fi
	((file_line++))
	echo "$last,$file_line,$SECONDS" > "$status_downloads"
done
rm $output_file
