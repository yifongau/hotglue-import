#!/bin/bash


xBaseName() {

	baseName="$1"
	prefix="$2"
	suffix="$3"

	htmlBaseName="${baseName#$prefix}${suffix}"
		
	echo $htmlBaseName

}

# different handlers for different filetypes
hrefToFileName() {
	url=$1
	
	if grepString=$(echo "$url" | grep -Po "img\/.*?\.ico"); then
		fileName=$grepString
		echo $fileName

	elif grepString=$(echo "$url" | grep -Po "css\/.*?\.css"); then
		fileName=$grepString
		echo $fileName

	elif grepString=$(echo "$url" | grep -Po "\?.*?$"); then
		fileName=$(xBaseName $( echo $grepString | tr -d '/') "?" ".html" )
		echo $fileName
	fi

}

# different handlers for different filetypes
imgSrcHandler() {
	url=$1

	# different handlers for different filetypes
	if filename=$(echo "$url" | grep -Po "css\/.*?\.css") ; then
		curl $url --create-dirs --output ./"$filename"	

	fi

}

updateHrefs() {
	file=$1


}

getLinkedFiles() {
	parentFileName=$1

	# parse the resulting file and grep url string of linked files
#	imgSrcList=$(cat ./$parentFileName | hxclean | hxselect img | grep -Po "\"https:\/\/.*?\"")
	hrefList=$(cat ./$parentFileName | hxclean | hxselect [href] | grep -Po "\"https:\/\/.*?\"")

	# iterate over hrefs and retrieve them
	while IFS= read -r href ; do 

		# sanitize URL of linked file
		childUrl=$( echo $href | tr -d '"')
		childFileName=$(hrefToFileName $childUrl)

		# curl the childUrl and save to filename
		if test -f ./$childFileName; then
			echo "$childFileName already exists, doing nothing"
		else
			sleep 100
			curl "$childUrl" --create-dirs --output ./$childFileName
		fi


		# Recurse into .html files, but not if they have already been recursed
		alreadyRecursed+=($parentFileName)
		echo $alreadyRecursed

		if echo $childFileName | grep ".html"; then
			if [[ ! ${alreadyRecursed[@]} =~ $childFileName ]]; then
				getLinkedFiles "$childFileName"
			fi
		fi

	done <<< "$hrefList"

}

# ENTRYPOINT

alreadyRecursed=()

# curl the entryUrl and save to filename
entryUrl=$1
entryFileName=$(xBaseName $(basename "$entryUrl") "?" ".html")
curl "$entryUrl" --output ./$entryFileName

# enter recursive function
getLinkedFiles "$entryFileName"
