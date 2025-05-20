#!/usr/bin/env bash

# Copyright (c) CDQ AG

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "$SCRIPT_DIR/helpers/log_helpers.sh"

while getopts "p:b:d:f:x:h" opt; do
	case "${opt}" in
	p)
		log_debug "-p argument is $OPTARG"
		ROOT_PATH="$OPTARG"
		;;
	b)
		log_debug "-b argument is $OPTARG"
		BRANCH="$OPTARG"
		;;
	d)
		log_debug "-d argument is $OPTARG"
		DIRS="$OPTARG"
		;;
	f)
		log_debug "-f argument is $OPTARG"
		FILES="$OPTARG"
		;;
	x)
		log_debug "-x argument is $OPTARG"
		EXCLUDE="$OPTARG"
		;;
	h)
		echo_err "Usage: $0 -p <root_path> -b <branch> [-d <dirs>] [-f <files>] [-x <exclude>] [-h]"
		echo_err "  -p <root_path>           The root directory of the project."
		echo_err "  -b <branch>              The branch to deploy to."
		echo_err "  -d <dirs>                The directories to deploy."
		echo_err "  -f <files>               Additional files to deploy."
		echo_err "  -x <exclude>             Names of items to exclude from deployment. Note: .git is always excluded."
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

if [[ -z "$BRANCH" ]]; then
	log_error "Invalid input" "branch is not set"
	exit 12
fi

if [[ -z "$DIRS" && -z "$FILES" ]]; then
	log_error "Invalid input" "Either 'dirs', 'files' or both must be set"
	exit 13
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
	exit 14
fi

log_debug "Exporting $ROOT_PATH ..."
cd "$ROOT_PATH"

log_debug "Ensuring submodules are initialized ..."
git submodule update --init --recursive --quiet || true

if [[ -n "$DIRS" ]]; then
	log_debug "Copying dirs to $DEST_PATH ..."
	for dir in $DIRS; do
		log_debug "Processing $dir ..."

		_cmd="rsync -rLptgoD --exclude=.git"

		for _x in $EXCLUDE; do
			_cmd="$_cmd --exclude=$_x"
		done

		_cmd="$_cmd '$dir' '$DEST_PATH'"

		log_debug "Running command: $_cmd"
		bash -c "$_cmd"
	done
else
	log_debug "No dirs to copy - skipping."
fi

if [[ -n "$FILES" ]]; then
	log_debug "Copying files to $DEST_PATH ..."
	for file_pattern in $FILES; do
		for file in $(find . -type f -regex ".*$file_pattern\$"); do
			_file=$(basename "$file")
			for _x in $EXCLUDE; do
				if [[ "$_file" == *$_x ]]; then
					log_debug "Excluding $_file ..."
					continue 2
				fi
			done

			cp "$file" "$DEST_PATH/$_file"
		done
	done
else
	log_debug "No files to copy - skipping."
fi

log_debug "git fetch origin ..."
git fetch origin

log_debug "Checking out if major version branch already exists ..."
if git ls-remote --heads origin $BRANCH | grep -q "refs/heads/$BRANCH"; then
	log_debug "Branch $BRANCH already exists on origin - checking it out locally ..."
	if git branch --list | grep -q "$BRANCH"; then
		log_debug "Branch $BRANCH already exists locally - deleting it before checking it out..."
		git branch -D $BRANCH
	fi
	git checkout -b $BRANCH origin/$BRANCH --force
else
	log_debug "Branch $BRANCH does not exist - creating it ..."
	git checkout -b $BRANCH --force
fi

log_debug "Deinitializing submodules ..."
git submodule deinit --all --force --quiet || true

log_debug "Cleaning up branch ..."
find . -maxdepth 1 -not -name '.' -not -name '.git' -exec rm -rf {} \;
git add --all

if [[ -z $(git status --porcelain) ]]; then
	log_debug "No changes to commit - skipping."
else
	git commit --quiet -m "other: Removing non-release files" || true
fi

log_debug "Copying files from $DEST_PATH to current directory ..."
mv "$DEST_PATH"/* ./

log_debug "Committing changes ..."
git add --all
timestamp=$(date '+%Y%m%d/%H%m%S')
git commit --quiet -m "other: Deploy changes $timestamp" --no-edit || true

log_debug "Pushing changes to origin ..."
git push --force origin $BRANCH --quiet

log_info "Done"
