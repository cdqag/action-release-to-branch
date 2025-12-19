load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"
load "test_helper/common"

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "should exit error when root_path is not set" {
	run src/release.sh

	assert_failure 10
	assert_output "[ERROR] Invalid input: root_path is not set"
}

@test "should exit error when root_path is not a directory" {
	run src/release.sh -p /tmp/not/existing

	assert_failure 11
	assert_output "[ERROR] Invalid input: root_path is not a directory"
}

@test "should exit error when branch is not set" {
	run src/release.sh -p "$workdir"

	assert_failure 12
	assert_output "[ERROR] Invalid input: branch is not set"
}

@test "should exit error when either dirs or files are not set" {
	run src/release.sh -p "$workdir" -b v1

	assert_failure 13
	assert_output "[ERROR] Invalid input: Either 'dirs', 'files' or both must be set"
}

@test "should create folder structure properly (should not be symbolic links)" {
	run src/release.sh -p "$workdir" -b v1 -d src

	assert_success
	assert [ -d "$workdir/src" ]
	assert [ -d "$workdir/src/foo" ]
	assert [ -d "$workdir/src/foo/bar" ]
	assert [ -d "$workdir/src/dummy" ]
	assert [ ! -h "$workdir/src/dummy" ]
	assert [ ! -d "$workdir/src/dummy/.git" ]
}

@test "should copy all files to temporary destination" {
	run src/release.sh -p "$workdir" -b v1 -d src

	assert_success
	assert [ -f "$workdir/src/foo/bar/baz.txt" ]
	assert [ -f "$workdir/src/dummy/hello" ]
	assert [ -f "$workdir/src/other-important" ]
	assert [ -f "$workdir/src/something" ]
}

@test "should copy all files (from dirs and files) to temporary destination" {
	run src/release.sh -p "$workdir" -b v1 -d src -f "action.ya?ml LICENSE"

	assert_success
	assert [ -f "$workdir/src/foo/bar/baz.txt" ]
	assert [ -f "$workdir/src/dummy/hello" ]
	assert [ -f "$workdir/src/other-important" ]
	assert [ -f "$workdir/src/something" ]
	assert [ -f "$workdir/action.yaml" ]
	assert [ -f "$workdir/LICENSE" ]
	assert [ ! -f "$workdir/not-important" ]
	assert [ ! -f "$workdir/README.md" ]
}

@test "should exclude all hello files" {
	run src/release.sh -p "$workdir" -b v1 -d src -f "action.ya?ml LICENSE" -x hello

	assert_success
	assert [ -f "$workdir/src/foo/bar/baz.txt" ]
	assert [ ! -f "$workdir/src/dummy/hello" ]
	assert [ -f "$workdir/src/other-important" ]
	assert [ -f "$workdir/src/something" ]
	assert [ -f "$workdir/action.yaml" ]
	assert [ -f "$workdir/LICENSE" ]
	assert [ ! -f "$workdir/not-important" ]
	assert [ ! -f "$workdir/README.md" ]
}

@test "should be on proper branch" {
	run src/release.sh -p "$workdir" -b v1 -d src
	assert_success

	cd "$workdir"

	run git branch --show-current
	assert_success
	assert_output "v1"
}

@test "should create proper commit" {
	run src/release.sh -p "$workdir" -b v1 -d src
	assert_success

	cd "$workdir"

	run git log --oneline
	assert_success
	assert_output --partial "other: Deploy changes"
}

@test "there should be no uncommited files" {
	run src/release.sh -p "$workdir" -b v1 -d src
	assert_success

	cd "$workdir"

	run git status --porcelain
	assert_success
	assert_output ""
}

@test "changes should be pushed to the remote" {
	run src/release.sh -p "$workdir" -b v1 -d src
	assert_success

	cd "$remotedir"

	run git show-ref --verify --quiet "refs/heads/v1"
	assert_success

	run git checkout v1
	assert_success

	run git status --porcelain
	assert_success
	assert_output ""

	run git log --oneline
	assert_success
	assert_output --partial "other: Deploy changes"

	assert [ -f "./src/dummy/hello" ]
}
