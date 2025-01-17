load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"
load "test_helper/common"

setup() {
	common_setup
}

teardown() {
	common_teardown
}

@test "should exit error when root_path is empty" {
	run src/release.sh

	assert_failure 10
	assert_output "[ERROR] Invalid input: root_path is not set"
}

@test "should exit error when root_path is not a directory" {
	run src/release.sh -p /tmp/not/existing

	assert_failure 11
	assert_output "[ERROR] Invalid input: root_path is not a directory"
}

@test "should exit error when source_dirs is empty" {
	run src/release.sh -p "$workdir"

	assert_failure 12
	assert_output "[ERROR] Invalid input: source_dirs is not set"
}

@test "should exit error when next_version is empty" {
	run src/release.sh -p "$workdir" -s src

	assert_failure 13
	assert_output "[ERROR] Invalid input: next_version is not set"
}

@test "should exit error when next_major_version is empty" {
	run src/release.sh -p "$workdir" -s src -v "v1.2.3"

	assert_failure 14
	assert_output "[ERROR] Invalid input: next_major_version is not set"
}

@test "should create folder structure properly (should not be symbolic links)" {
	run src/release.sh -p "$workdir" -s src -v "v1.2.3" -m "v1"

	assert_success
	assert [ -d "$remotedir/src" ]
	assert [ -d "$remotedir/src/foo" ]
	assert [ -d "$remotedir/src/foo/bar" ]
	assert [ -d "$remotedir/src/helpers" ]
	assert [ ! -h "$remotedir/src/helpers" ]
	assert [ ! -d "$remotedir/src/helpers/.git" ]
}

@test "should copy all files to temporary destination" {
	run src/release.sh -p "$workdir" -s src -v "v1.2.3" -m "v1"

	assert_success
	assert [ -f "$remotedir/src/foo/bar/baz.txt" ]
	assert [ -f "$remotedir/src/helpers/job_helpers.sh" ]
	assert [ -f "$remotedir/src/helpers/json_helpers.sh" ]
	assert [ -f "$remotedir/src/helpers/log_helpers.sh" ]
	assert [ -f "$remotedir/src/other-important" ]
	assert [ -f "$remotedir/src/something" ]
}

@test "should copy all files + additional files" {
	run src/release.sh -p "$workdir" -s src -v "v1.2.3" -m "v1" -a "action.ya?ml LICENSE"

	assert_success
	assert [ -f "$remotedir/src/foo/bar/baz.txt" ]
	assert [ -f "$remotedir/src/helpers/job_helpers.sh" ]
	assert [ -f "$remotedir/src/helpers/json_helpers.sh" ]
	assert [ -f "$remotedir/src/helpers/log_helpers.sh" ]
	assert [ -f "$remotedir/src/other-important" ]
	assert [ -f "$remotedir/src/something" ]
	assert [ -f "$remotedir/action.yaml" ]
	assert [ -f "$remotedir/LICENSE" ]
	assert [ ! -f "$remotedir/not-important" ]
	assert [ ! -f "$remotedir/README.md" ]
}
