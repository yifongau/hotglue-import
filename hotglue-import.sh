#!/bin/bash

xBaseName() {

	baseName="$1"
	prefix="$2"
	suffix="$3"

	htmlBaseName="${baseName#$prefix}${suffix}"
		
	echo $htmlBaseName

}

hrefToFileName() {
	url=$1

	# referenced icon files
	if grepString=$(echo "$url" | grep -Po "img\/.*?\.ico"); then
		fileName=$grepString
		echo $fileName

	# referenced css files
	elif grepString=$(echo "$url" | grep -Po "css\/.*?\.css"); then
		fileName=$grepString
		echo $fileName
	
	# html files in query string format
	elif grepString=$(echo "$url" | grep -Po "\?.*?$"); then
		fileName=$(xBaseName $( echo $grepString | tr -d '/') "?" ".html" )
		echo $fileName
	fi

}

imgSrcToFileName() {
	url=$1

	# image files in query string format, assuming .png format
	if grepString=$(echo "$url" | grep -Po "\?.*?$"); then
		fileName=$(xBaseName $( echo $grepString | tr -d '/') "?" ".png")
		echo "img/$fileName"
	fi

}

# This is the big recursive function
getLinkedFiles() {
	parentFileName=$1

	# parse the resulting file and grep url string of linked files
	imgSrcList=$(cat ./$parentFileName | hxclean | hxselect img | grep -Po "\"https:\/\/.*?\"")
	hrefList=$(cat ./$parentFileName | hxclean | hxselect [href] | grep -Po "\"https:\/\/.*?\"")
	htmlFiles=()

	# iterate over image sources and retrieve them
	while IFS= read -r href ; do 

		# sanitize URL of linked file
		childUrl=$( echo $href | tr -d '"')
		childFileName=$(imgSrcToFileName $childUrl)

		# curl the childUrl and save to filename
		if test -f ./$childFileName; then
			echo "$childFileName already exists, doing nothing"
		else
#			sleep 1
			curl "$childUrl" --create-dirs --output ./$childFileName
		fi

	done <<< "$imgSrcList"

	# iterate over hrefs and retrieve them
	while IFS= read -r href ; do 

		# sanitize URL of linked file
		childUrl=$( echo $href | tr -d '"')
		childFileName=$(hrefToFileName $childUrl)

		# curl the childUrl and save to filename
		if test -f ./$childFileName; then
			echo "$childFileName already exists, doing nothing"
		else
			sleep 1
			curl "$childUrl" --create-dirs --output ./$childFileName
		fi


		# Remember any files ending in .html
		if echo $childFileName | grep ".html" > /dev/null; then
			htmlFiles+=($childFileName)

		fi

	done <<< "$hrefList"
	
	# linked files have now been retrieved, add parent to alreadyRecursed
	alreadyRecursed+=($parentFileName)

	# iterate over any .html files, and recurse into them if not already recursed
	while IFS= read -r htmlFile ; do 

		if [[ ! ${alreadyRecursed[@]} =~ $childFileName ]]; then
			getLinkedFiles "$childFileName"

		fi
	done <<< "$htmlFiles"

}

# ENTRYPOINT

alreadyRecursed=()

# curl the entryUrl and save to filename
entryUrl=$1
entryFileName=$(xBaseName $(basename "$entryUrl") "?" ".html")
curl "$entryUrl" --output ./$entryFileName

# enter recursive function
getLinkedFiles "$entryFileName"
