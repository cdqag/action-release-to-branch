#!/usr/bin/env bash

# Copyright (c) CDQ AG

function echo_err() {
	echo "$1" >&2
}

function _log_x() {
	if [[ -n "$GITHUB_ACTIONS" ]]; then
		if [[ -n "$3" ]]; then
			echo "::${1} title=${2}::$3"
		else
			echo "::${1}::$2"
		fi
	else
		if [[ -n "$3" ]]; then
			echo_err "[${1^^}] ${2}: ${3}"
		else
			echo_err "[${1^^}] ${2}"
		fi
	fi
}

function log_error() {
	_log_x error "$1" "$2"
}

function log_warning() {
	_log_x warning "$1" "$2"
}

function log_notice() {
	_log_x notice "$1" "$2"
}

function log_info() {
	if [[ -n "$GITHUB_ACTIONS" ]]; then
		echo "$1"
	else
		echo_err "[INFO] $1"
	fi
}

function log_debug() {
	if [[ -n "$RUNNER_DEBUG" ]]; then
		_log_x debug "$1"
	fi
}

function group_start() {
	if [[ -z "$1" ]]; then
		echo "group_start: Group name cannot be empty" >&2
		exit 1
	fi

	if [[ -n "$GITHUB_ACTIONS" ]]; then
		echo "::group::$1"
	fi
}

function group_end() {
	if [[ -n "$GITHUB_ACTIONS" ]]; then
		echo "::endgroup::"
	fi
}

function mask() {
	if [[ -z "$1" ]]; then
		echo "mask: Value to mask cannot be empty" >&2
		exit 1
	fi

	if [[ -n "$GITHUB_ACTIONS" ]]; then
		echo "::add-mask::$1"
	fi
}
