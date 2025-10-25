#!/bin/bash

xBaseName() {

	baseName="$1"
	prefix="$2"
	suffix="$3"

	htmlBaseName="${baseName#$prefix}${suffix}"
		
	echo $htmlBaseName

}

sedEscape() {
	rawString=$1
	escapedString=$(echo "$rawString" | sed -r 's/([\$\.\*\/\[\\^])/\\\1/g'| sed 's/[]]/\[]]/g')
	echo $escapedString
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

processLinkedFile() {
	childUrl=$1
	childFileName=$2
	parentFileName=$3

	# curl the childUrl and save to filename
	if test -f ./$childFileName; then
		echo "$childFileName already exists, not curling"
	else
		#sleep 1 (in case of rate limiting)
		echo "Curling $childUrl to $childFileName"
		curl "$childUrl" --create-dirs --output ./$childFileName

	fi

	# replace url reference in source to local copy
	echo "$parentFileName: $childUrl -> $childFileName"
	sedString=$(sedEscape "$childUrl")
	sed -i "s|${sedString}|\.\/${childFileName}|g" $parentFileName

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

		processLinkedFile "$childUrl" "$childFileName" "$parentFileName"

	done <<< "$imgSrcList"

	# iterate over hrefs and retrieve them
	while IFS= read -r href ; do 

		# sanitize URL of linked file
		childUrl=$( echo $href | tr -d '"')
		childFileName=$(hrefToFileName $childUrl)

		processLinkedFile "$childUrl" "$childFileName" "$parentFileName"

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
			echo "Recursing into $childFileName"
			getLinkedFiles "$childFileName"
		else
			echo "Not recursing into $childFileName (already recursed)"

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
