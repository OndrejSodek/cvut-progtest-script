#!/bin/bash

version="1.5.1"
printf "%s\n" "<======= ProgTest simulator, version: ${version} =======>"

## Options ##

# Change if you need to:
#	-std=c++11 is used almost exclusively on progtest
#	-g is for debugging (e.g. valgrind)
#	-Wall will give all possible warnings
#	-Werror will turn warnings to errors
#	-pedantic is useful on progtest
compileOptionsDef="-std=c++11 -g -Wall -Werror -pedantic"
compileOptionsEasierDef="-std=c++11 -g -Wall"

# Uncomment to warn about long long
#compileOptionsLongDef="-Wlong-long"

# Enable testing with CRLF (Windows-like) line endings
diffOptionsDef="--strip-trailing-cr"

# Extension to use while looking for source file
extensionsSource="c c++ cpp cxx cc cp c+"

# What possible extension can the archive with test data have
## ! Keep in mind, that only the last part (after the last dot) is used
extensionsTestData="tgz gz tar"

# Paths to use while looking for the test data
## List archives first
### will use the archive only when it is newer than the folder
pathsTestData="sample.tgz sample.tar.gz sample"

# Whether to try sorting the output if unsorted comparison fails
sortOutputIfNeeded=1

# NOTE
## Test file format has to be *_in.txt & *_out.txt (without spaces)
### The '_' is because of _win.txt files, which break the pattern
### You can change this if you know what you are doing
testFileFormat="*_in.txt"
# the minimal right part that differs between In & Out file
diffInOutFile="in.txt"
# the minimal right part that differs between Out & In file
diffOutInFile="out.txt"

## Functions ##
# Common #

exitUsageInfo() {
	printf "%s\n" "Usage: $(basename $0) path/to/source-file.c [path/to/test/data/]"
	exit 1
}

printPath() {

	if [ "${1}" == "${PWD}" ]; then
		printf "%s\n" "./"
		return
	fi

	printf "%s\n" "${1#${PWD}/}"
}

promptUser() {

	printf "%s\n" "${1}"

	while true; do
		printf "%s: " "[y/n]"
		read option
		case "${option}" in
			[Yy]*) return 0; break;;
			[Nn]*) return 1; break;;
			*) printf "%s\n" "Not recognized, only yes or no, please.";;
		esac
	done
}

printDebug() {
	printf "%s\n" "= = = = = = DEBUG = = = = = ="
	printf "= From: %s\n" "${1}"
	printf "Source Path: %s\n" "${sourcePath}"
	printf "Data Path: %s\n" "${dataPath}"
	printf "Source File: %s\n" "${sourceFile}"
	printf "Compiled File: %s\n" "${compiledFile}"
	printf "Data Folder: %s\n" "${dataFolder}"
	printf "%s\n" "= = = = = = DEBUG END = = = = = ="
}

canUseProgram() {

	if ! type "${1}" > /dev/null; then
		return 1
	else
		return 0
	fi
}

isTypeFile() {

	if ! canUseProgram "file"; then
		return 2
	fi

	if ! canUseProgram "awk"; then

		if ! file "${2}" | grep "${1}" > /dev/null; then
			return 1
		else
			return 0
		fi
	fi

	if ! file "${2}" | awk -F: '{print $NF}' | grep "${1}" > /dev/null; then
		return 1
	else
		return 0
	fi
}

# Paths #

getSourcePath() {

	if [ -z "${sourcePath}" ]; then
		sourcePath="${PWD}/"
		return
	fi

	if [ "${sourcePath%%/*}" != "" ]; then
		# Relative path
		sourcePath="${PWD}/${sourcePath}"
		return
	fi
}

getDataPath() {

	if [ -z "${dataPath}" ]; then
		dataPath="${PWD}/"
		return
	fi

	if [ "${dataPath%%/*}" != "" ]; then
		# Relative path
		dataPath="${PWD}/${dataPath}"
		return
	fi
}

resolvePaths() {

	getSourcePath
	getDataPath

	# printDebug "resolvePaths"
}

# Files #

findSourceFile() {

	infoSource=""
	extensions="${extensionsSource}"

	if [ ! -f "${sourcePath}" ]; then

		for ext in $extensions; do

			if [ -f "${sourcePath}.${ext}" ]; then
				sourceFile="${sourcePath}.${ext}"
				infoSource="found"
				return 0
			fi
		done

		return 3

	else
		sourceFile="${sourcePath}"
		extension="${sourcePath##*.}"

		if [ -z "${extension}" ]; then
			infoSource="noExt"

		else

			for ext in $extensions; do

				if [ "${extension}" == "${ext}" ]; then
					infoSource="good"
					return 0
				fi
			done
			infoSource="badExt"
		fi

		for ext in $extensions; do

			if [ -f "${sourcePath}.${ext}" ]; then
				sourceFile="${sourcePath}.${ext}"
				infoSource="foundBetter"
				return 0
			fi
		done

		infoCompiled="likelySource"
	fi
}

findCompiledFile() {

	if [ -f "${sourceFile}" ]; then

		if [ "${infoCompiled}" == "likelySource" ]; then
			compiledFile="${sourceFile}"
			infoCompiled="source"
			return 0

		else
			tmpName="${sourceFile%.*}"

			if [ -f "${tmpName}" ]; then
				isTypeFile "executable" "${tmpName}"
				tmp=$?

				if [ $tmp -eq 0 ]; then
					infoCompiled="good"
					compiledFile="${tmpName}"
					return 0
				fi

			else
				infoCompiled="new"
				compiledFile="${tmpName}"
			fi
		fi
	fi

	if [ -d "${sourcePath}" ]; then

		if [ -f "${sourcePath}/a.out" ]; then
			compiledFile="${sourcePath}/a.out"
			infoCompiled="oldFound"
			return 0
		fi

	else
		tmpName="${sourcePath%/*}/a.out"

		if [ -f "${tmpName}" ]; then
			compiledFile="${tmpName}"
			infoCompiled="oldFound"
			return 0
		fi

		if [ "${infoCompiled}" == "new" ]; then
			return 1
		fi
		compiledFile="${tmpName}"
		infoCompiled="oldRevert"
		return 1
	fi
}

resolveFiles() {

	if [ ! -d "${sourcePath%/*}" ]; then
		printf "%s\n" "[ERROR] Source directory doesn't exist."
		printf "%s\n" "Hint: Use TAB for auto-complete"
		exit 5
		return 3
	fi

	findSourceFile
	findCompiledFile
	tmp=$?

	if [ $tmp -eq 0 ]; then
		overwrite="1"
	else
		overwrite="0"
	fi

	# printDebug "resolveFiles"

	if [ ! -f "${sourceFile}" ] && [ ! -f "${compiledFile}" ]; then
		printf "%s\n" "[ERROR] Can't find source nor compiled file!"
		printf "%s\n" "Hint: Use TAB for auto-complete"
		exit 6
		return 2
	fi

	# Info messages

	isTypeFile "text" "${sourceFile}"
	tmp=$?

	if [ $tmp -eq 0 ]; then
		typeSource="good"

	elif [ $tmp -eq 1 ]; then
		typeSource="bad"

	elif [ $tmp -eq 2 ]; then
		typeSource="unrecognized"
	fi

	isTypeFile "executable" "${compiledFile}"
	tmp=$?

	if [ $tmp -eq 0 ]; then
		typeCompiled="good"

	elif [ $tmp -eq 1 ]; then
		typeCompiled="bad"

	else
		typeCompiled="unrecognized"
	fi

	if [ "${infoSource}" == "foundBetter" ]; then
		printf "%s: " "[Info] Found source file with better extension"
		printPath "${sourceFile}"

	elif [ "${infoSource}" == "found" ]; then
		printf "%s: " "[Info] Found source file"
		printPath "${sourceFile}"
	fi

	if [ "${typeSource}" == "good" ]; then

		if [ "${compiledFile}" != "${sourceFile}" ]; then

			case "${infoSource}" in
				"noExt") printf "%s\n" "[Warning] Source file has no extension! Compiler will likely throw an error.";;
				"badExt") printf "%s\n" "[Warning] Unrecognized extension! Compiler will likely throw an error.";;
			esac
		fi

	elif [ "${typeSource}" == "bad" ]; then

		if [ "${infoSource}" == "foundBetter" ]; then
			printf "%s: " "Looks like the file I found isn't text file, maybe bad name?"
			printPath "${sourceFile}"
		fi

		if [ "${typeCompiled}" == "bad" ]; then
			printf "%s\n" "Seems both source and compiled files are of incorrect type. Will try it anyway."
		fi

	else
		printf "%s\n" "[Warning] Can't determine if source file is text file. Most likely can't use program \"file\""
	fi
}

# TestData #

unarchive() {

	if ! canUseProgram "tar"; then
		printf "%s\n" "[ERROR] Can't use tar. Extract manually and try again."
		exit 11
		return 1

	elif ! mkdir -p "${searchPath}"; then
		printf "%s: " "[ERROR] Can't create folder"
		printPath "${searchPath}"
		printf "%s\n" "Create manually and try again."
		exit 10
		return 1

	else

		printf "%s\n" "[Info] Extracting files ..."
		printf "%s\n" "=> => => => tar output start => => => =>"
		tar -xf "${tmpName}" -C "${searchPath}"
		tmp=$?
		printf "%s\n" "<= <= <= <= tar output end <= <= <= <= <="

		if [ $tmp -ne 0 ]; then
			printf "%s: " "[ERROR] Can't extract file"
			printPath "${searchPath}"
			printf "%s\n" "Maybe the file isn't tar.gz (tgz)? Extract manually and try again."
			exit 12
			return 2

		else
			printf "%s\n" "[Info] Files extracted."
			return 0
		fi
	fi
}

findTestData() {
	tmpName="${1}"

	extensions="${extensionsTestData}"

	if [ -f "${tmpName}" ]; then
		searchPath="${tmpName}"
		extension="${searchPath##*.}"

		for i in ${extensions}; do

			if [ "${i}" == "${extension}" ]; then
				searchPath="${searchPath%.*}"
				extension="${searchPath##*.}"
			fi
		done

		if [ -d "${searchPath}" ]; then

			if [ ! "${tmpName}" -nt "${searchPath}" ]; then
				findTestData "${searchPath}"
				tmp=$?

				if [ $tmp -ne 0 ]; then
					unarchive "${tmpName}"
				fi
			else
				printf "%s: ""[Info] Skipping extraction, found folder"
				printPath "${searchPath}"
			fi
		else
			unarchive "${tmpName}"
		fi

	elif [ -d "${tmpName}" ]; then
		searchPath="${tmpName%/}"

	else
		return 2
	fi

	# If format is different, you have to change it here and in input output testing

	count=$(ls -1 "${searchPath}"/$testFileFormat 2>/dev/null | wc -l)

	if [ $((count)) -gt 0 ]; then
		dataFolder="${searchPath}"
		return 0
	fi

	count=$(ls -1 "${searchPath}"/CZE/$testFileFormat 2>/dev/null | wc -l)

	if [ $((count)) -gt 0 ]; then
		dataFolder="${searchPath}/CZE"
		return 0
	fi

	count=$(ls -1 "${searchPath}"/ENG/$testFileFormat 2>/dev/null | wc -l)

	if [ $((count)) -gt 0 ]; then
		dataFolder="${searchPath}/ENG"
		return 0
	fi

	return 1
}

resolveData() {

	findTestData "${dataPath}"
	tmp=$?

	if [ $tmp -ne 0 ]; then
		paths="${pathsTestData}"

		for path in ${paths}; do
			tmpName="${dataPath%/}/${path}"

			findTestData "${tmpName}"
			tmp=$?

			if [ $tmp -eq 0 ]; then
				break
			fi
		done
	fi

	if [ $tmp -ne 0 ]; then
		printf "%s\n" "[ERROR] Can't find test data or they can't be read!"
		printf "%s\n" "Hint: Use TAB for auto-complete"
		printf "%s\n" "[Info] Files should look like *in.txt (*out.txt), else update this script :)"
		exit 7
		return 2
	else
		printf "%s: " "[Info] Found test data in folder"
		printPath "${dataFolder}"
	fi

	# printDebug "resolveData"
}

# compilation #

shouldCompile() {

	#check whether is compilation necessary (if compiled file is older than source file)
	if [ -f "${sourceFile}" ] && [ "${sourceFile}" != "${compiledFile}" ]; then

		if [ -f "${compiledFile}" ] && [ ! "${sourceFile}" -nt "${compiledFile}" ]; then
			return 1
		else
			return 0
		fi
	else
		return 2
	fi
}

compileSource() {

	compileOptions="${compileOptionsDef}"
	longOptions="${compileOptionsLongDef}"

	if [ "${2}" = "1" ]; then
		compileOptions="${compileOptionsEasierDef}"
		longOptions="-Wno-long-long"
	fi

	if ! ${1} ${compileOptions} ${longOptions} -o "${compiledFile}" "${sourceFile}"; then
		return 1
	else
		return 0
	fi
}

resolveCompilation() {

	shouldCompile
	tmp=$?

	if [ $tmp -eq 1 ]; then
		printf "%s: " "[Info] Skipping compilation, compiled file is newer than source file"
		printPath "${compiledFile}"
		printf "\n"
		return 1

	elif [ $tmp -eq 0 ]; then
		printf "%s" "[Info] Trying to compile ${sourceFile#${PWD}} -> ${compiledFile#${PWD}}"

		if [ "${overwrite}" == "1" ]; then
			printf " %s" "(will overwrite)"
		fi
		printf "\n"

	else
		printf "%s: " "[Info] Source file not found, will only use compiled file"
		printPath "${compiledFile}"
		printf "\n"
		return 0
	fi

	compiler="g++"

	if ! canUseProgram "g++"; then

		if ! canUseProgram "gcc"; then
			printf "%s\n" "[ERROR] Can't use g++ nor gcc. Aborting."
			exit 8
			return 3

		else
			compiler="gcc"
			printf "%s\n" "[Info] Using gcc, g++ isn't availiable."
		fi
	fi

	easier=0
	counter=0

	while true; do
		((counter++))

		printf "%s" "[Info] Compiling code"
		if [ ${easier} -eq 1 ]; then
			printf " %s" "- w/o pedantic, w/ long long"
		fi
		printf " %s\n" "(attempt ${counter})"
		printf "%s\n" "=> => => => ${compiler} output start => => => =>"
		compileSource "${compiler}" ${easier}
		tmp=$?
		printf "%s\n" "<= <= <= <= ${compiler} output end <= <= <= <= <="

		if [ $tmp -eq 0 ]; then
			printf "%s\n" "[Info] Success!"
			printf "\n"
			break

		else
			printf "%s\n" "[ERROR] ${compiler} can't compile the source code."
			printf "\n"
			printf "%s: " "Again = y, Again (go easier) = o, Exit = n; [y/o/n]"

			while true; do
				read option
				case "${option}" in
					[Yy]*) easier=0; break;;
					[Oo]*) easier=1; break;;
					[Nn]*) printf "%s\n" "Aborting."; exit 3; return 3;;
					*) printf "%s: " "Not recognized, try again; [y/o/n]";;
				esac
			done
		fi
	done

}

# Testing #

printDiff() {

	inputFile="${1}"
	compiledFile="${2}"

	diffOptions="${diffOptionsDef}"

	if ! canUseProgram "file"; then
		printf "%s\n" "[=] Can't use program \"file\". Won't show input."
	else
		isTypeFile "text" "${inputFile}"
		tmp=$?

		if [ $tmp -eq 0 ]; then

			if ! canUseProgram "sed"; then
				printf "%s\n" "[=] Can't use sed. Won't show input."
			else
				if ! canUseProgram "awk"; then
					printf "%s\n" "[=] Input (max 5 lines)"
				else
					LINES=$(awk 'END { print NR }' "${inputFile}")
					if [ ${LINES} -gt 5 ]; then
						printf "%s\n" "[=] Input (only 5 lines)"
					else
						printf "%s\n" "[=] Input"
					fi
				fi
				sed 5q "${inputFile}"
			fi
		else
			printf "%s\n" "[=] File could be binary, won't show input."
		fi
	fi
	printf "%s\n" "[=] Output diff (< is your program, > is reference)"
	printf "%s\n" "=> => => => diff output start => => => =>"
	diff ${diffOptions} <("${compiledFile}" < "${inputFile}") "${inputFile%$diffInOutFile}$diffOutInFile"
	printf "%s\n" "<= <= <= <= diff output end <= <= <= <= <="
	printf "\n"
}

testIO() {

	testsCounter=0
	testsFailed=0
	testsSortedGood=0

	diffOptions="${diffOptionsDef}"

	# Testing inputs outputs
	for inputFile in "${dataFolder}/"${testFileFormat}; do
		((testsCounter++))
		printf "%s" "[Testing] ${inputFile#${dataFolder}/} ... "

		diff ${diffOptions} <("${compiledFile}" < "${inputFile}") "${inputFile%$diffInOutFile}$diffOutInFile" > /dev/null
		tmp=$?

		if [ $tmp -ne 0 ]; then

			if [ $((sortOutputIfNeeded)) -gt 0 ]; then

				if ! canUseProgram "sort"; then
					tmp=2

				else
					diff ${diffOptions} <("${compiledFile}" < "${inputFile}" | sort) <(sort "${inputFile%$diffInOutFile}$diffOutInFile") > /dev/null
					tmp=$?
				fi
			fi

			if [ $tmp -ne 0 ]; then
				((testsFailed++))
				printf "%s\n" "FAILED!"
				printDiff "${inputFile}" "${compiledFile}"

			else
				((testsSortedGood++))
				printf "%s\n" "OK (when sorted)"

			fi
		else
			printf "%s\n" "OK"
		fi
	done

	# Final message
	if [ ${testsFailed} -gt 0 ]; then
		printf "%s\n" "[Warning] Failed ${testsFailed} test(s) out of ${testsCounter}."

		if [ ${testsSortedGood} -gt 0 ]; then
			printf "%s\n" "${testsSortedGood} test(s) passed, only after outputs were sorted."
		fi
		printf "\n"
		exit 2
		return 1
	else
		printf "%s\n" "Congratulations! All ${testsCounter} tests have been successful."

		if [ ${testsSortedGood} -gt 0 ]; then
			printf "%s\n" "${testsSortedGood} test(s) passed, only after outputs were sorted."
		fi
		printf "\n"
	fi
}

resolveTesting() {

	if ! canUseProgram "diff"; then
		printf "%s\n" "[ERROR] Can't use diff. Aborting."
		exit 9
		return 3
	fi

	if [ $((sortOutputIfNeeded)) -gt 0 ]; then

		if ! canUseProgram "sort"; then
			printf "%s\n" "[Warning] Can't use sort. Won't be able to test everything."
		fi
	fi

	testIO
}

## Variables ##

sourcePath="${1}"
dataPath="${2}"

sourceFile=""
compiledFile=""
dataFolder=""

## Main program ##

# Print usage info if arguments are invalid
if [ $# -eq 0 ] || [ $# -gt 2 ]; then
	exitUsageInfo
fi

resolvePaths

resolveFiles

resolveData

resolveCompilation

resolveTesting
