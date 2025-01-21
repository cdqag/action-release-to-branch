#!/usr/bin/env bash

# Copyright (c) CDQ AG

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "$SCRIPT_DIR/helpers/log_helpers.sh"

while getopts "p:s:v:m:a:e:h" opt; do
	case "${opt}" in
	p)
		log_debug "-p argument is $OPTARG"
		ROOT_PATH="$OPTARG"
		;;
	s)
		log_debug "-s argument is $OPTARG"
		SOURCE_DIRS="$OPTARG"
		;;
	v)
		log_debug "-v argument is $OPTARG"
		NEXT_VERSION="$OPTARG"
		;;
	m)
		log_debug "-m argument is $OPTARG"
		NEXT_MAJOR_VERSION="$OPTARG"
		;;
	a)
		log_debug "-a argument is $OPTARG"
		ADDITIONAL_FILES="$OPTARG"
		;;
	h)
		echo_err "Usage: $0 -p <root_path> -s <source_dirs> -v <next_version> -m <next_major_version> [-a <additional_files>] [-e <excluded_names>] [-h]"
		echo_err "  -p <root_path>           The root directory of the project."
		echo_err "  -s <source_dirs>         Space-separated list of source directories that should be copied."
		echo_err "  -v <next_version>        The next version of the project."
		echo_err "  -m <next_major_version>  The next major version of the project."
		echo_err "  -a <additional_files>    Additional files (regexp patterns) to copy to the destination directory."
		echo_err "  -h                       Display this help message, then exit."
		exit 0
		;;
	esac
done

if [[ -z "$ROOT_PATH" ]]; then
	log_error "Invalid input" "root_path is not set"
	exit 10
fi

if [[ ! -d "$ROOT_PATH" ]]; then
	log_error "Invalid input" "root_path is not a directory"
	exit 11
fi

if [[ -z "$SOURCE_DIRS" ]]; then
	log_error "Invalid input" "source_dirs is not set"
	exit 12
fi

if [[ -z "$NEXT_VERSION" ]]; then
	log_error "Invalid input" "next_version is not set"
	exit 13
fi

if [[ -z "$NEXT_MAJOR_VERSION" ]]; then
	log_error "Invalid input" "next_major_version is not set"
	exit 14
fi

log_debug "Creating temporary destination directory ..."
export DEST_PATH=$(mktemp -d)

log_debug "Setting up cleanup trap ..."
function cleanup() {
	rm -rf "$DEST_PATH"
}
trap "cleanup" EXIT

if [[ -z "$DEST_PATH" ]]; then
	log_error "Failed to create temporary destination directory"
	exit 15
fi

log_debug "Exporting $ROOT_PATH ..."
cd "$ROOT_PATH"

for source_dir in $SOURCE_DIRS; do
	log_debug "Processing $source_dir ..."

	rsync -rLptgoD --exclude=".git" "$source_dir" "$DEST_PATH"
done


if [[ -n "$ADDITIONAL_FILES" ]]; then
	log_debug "Copying additional files to $DEST_PATH ..."
	for file_pattern in $ADDITIONAL_FILES; do
		for file in $(find . -maxdepth 1 -type f -regex ".*$file_pattern"); do
			cp "$file" "$DEST_PATH/$file"
		done
	done
else
	log_debug "No additional files to copy - skipping."
fi

log_debug "Deinitializing submodules ..."
git submodule deinit --all --force

log_debug "git fetch origin ..."
git fetch origin

log_debug "Checking out if major version branch already exists ..."
if git show-ref --verify --quiet refs/heads/$NEXT_MAJOR_VERSION; then
	log_debug "Branch $NEXT_MAJOR_VERSION already exists - checking it out ..."
	git checkout $NEXT_MAJOR_VERSION --force
else
	log_debug "Branch $NEXT_MAJOR_VERSION does not exist - creating it ..."
	git checkout -b $NEXT_MAJOR_VERSION --force
fi

log_debug "Cleaning up branch ..."
find . -maxdepth 1 -not -name '.' -not -name '.git' -exec rm -rf {} \;

log_debug "Copying files from $DEST_PATH to current directory ..."
mv "$DEST_PATH"/* ./

log_debug "Adding all files to git ..."
git add --all

log_debug "Committing changes ..."
git commit --quiet -m "chore: Build version $NEXT_VERSION" || true

log_debug "Pushing changes to origin ..."
git push --force origin $NEXT_MAJOR_VERSION

log_info "Done"
