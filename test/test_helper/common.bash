DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." >/dev/null 2>&1 && pwd)"
PATH="$DIR/../src:$PATH"

TEST_DIR="$DIR/test"
FIXTURES_DIR="$TEST_DIR/fixtures"

remotedir=/tmp/not-yet-set
workdir=/tmp/not-yet-set

BOT_NAME="github-actions[bot]"
BOT_EMAIL="github-actions[bot]@users.noreply.github.com"

function common_setup() {
	# Simulate remote git repository
	remotedir=$(mktemp -d)

	# Init remote dir
	git init "$remotedir" --quiet
	git -C "$remotedir" config init.defaultBranch master
	git -C "$remotedir" config user.name "$BOT_NAME"
	git -C "$remotedir" config user.email "$BOT_EMAIL"

	# Copy and commit fixtures
	cp -r test/fixtures/. "$remotedir"
	git -C "$remotedir" add . >/dev/null
	git -C "$remotedir" commit -m "Initial commit" --quiet --no-edit
	# Fix error: ! [remote rejected] master -> master (branch is currently checked out
	# https://stackoverflow.com/questions/2816369/git-push-error-remote-rejected-master-master-branch-is-currently-checked/
	git -C "$remotedir" checkout -b master-copy --quiet

	# Prepare a work directory
	workdir=$(mktemp -d)

	# Clone remote repository to work directory
	git clone "$remotedir" "$workdir" --quiet
	git -C "$workdir" config user.name "$BOT_NAME"
	git -C "$workdir" config user.email "$BOT_EMAIL"
	git -C "$workdir" fetch origin --quiet
	git -C "$workdir" checkout master --quiet
}

function common_teardown() {
	rm -rf "$remotedir" "$workdir"
}
