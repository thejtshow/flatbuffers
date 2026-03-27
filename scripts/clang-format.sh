#!/usr/bin/env bash

set -euo pipefail

# clang-format runner mirroring the CMake targets:
# - diff: show formatting diff against empty tree
# - ci: fail if any formatting changes would be applied
# - fix: apply formatting changes against empty tree

# Constants
GIT_EMPTY_TREE_HASH=4b825dc642cb6eb9a060e54bf8d69288fbee4904

# Resolve paths
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$SCRIPT_DIR/..")
GIT_CLANG_FORMAT="$SCRIPT_DIR/git-clang-format.py"

# Detect Python
PYTHON_BIN=${PYTHON:-}
if [[ -z "${PYTHON_BIN}" ]]; then
	if command -v python3 >/dev/null 2>&1; then
		PYTHON_BIN=python3
	elif command -v python >/dev/null 2>&1; then
		PYTHON_BIN=python
	else
		echo "Error: Python not found (set PYTHON env var or install python3)." >&2
		exit 1
	fi
fi

# Detect clang-format (can be overridden via --binary or CLANG_FORMAT_PROGRAM)
CLANG_FORMAT_BIN=${CLANG_FORMAT_PROGRAM:-}
if [[ -z "${CLANG_FORMAT_BIN}" ]]; then
	if command -v clang-format >/dev/null 2>&1; then
		CLANG_FORMAT_BIN=$(command -v clang-format)
	else
		CLANG_FORMAT_BIN=""
	fi
fi

print_usage() {
	cat <<EOF
Usage: $(basename "$0") [--binary /path/to/clang-format] <diff|ci|fix>

Subcommands:
	diff   Show formatting diff vs empty tree (read-only)
	ci     CI mode: exit non-zero if changes would be made
	fix    Apply formatting changes vs empty tree

Options:
	--binary PATH   Path to clang-format binary (default: detect from PATH or CLANG_FORMAT_PROGRAM)

Environment:
	PYTHON                Python interpreter to use (default: detect python3/python)
	CLANG_FORMAT_PROGRAM  clang-format binary path (alternative to --binary)
EOF
}

# Parse args
ARGS=()
SUBCMD=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--binary)
			shift
			CLANG_FORMAT_BIN=${1:-}
			if [[ -z "${CLANG_FORMAT_BIN}" ]]; then
				echo "Error: --binary requires a path." >&2
				exit 2
			fi
			;;
		diff|ci|fix)
			SUBCMD="$1"
			;;
		-h|--help)
			print_usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			print_usage
			exit 2
			;;
	esac
	shift
done

if [[ ! -f "$GIT_CLANG_FORMAT" ]]; then
	echo "Error: git-clang-format.py not found at $GIT_CLANG_FORMAT" >&2
	exit 1
fi

if [[ -z "$SUBCMD" ]]; then
	echo "Error: missing subcommand (diff|ci|fix)." >&2
	print_usage
	exit 2
fi

# Build common command
CMD=("$PYTHON_BIN" "$GIT_CLANG_FORMAT")
if [[ -n "$CLANG_FORMAT_BIN" ]]; then
	CMD+=("--binary=$CLANG_FORMAT_BIN")
fi

pushd "$REPO_ROOT" >/dev/null

case "$SUBCMD" in
	diff)
		# Equivalent to: ${CLANG_FORMAT_COMMAND} --diff ${GIT_EMPTY_TREE_HASH}
		"${CMD[@]}" --diff "$GIT_EMPTY_TREE_HASH"
		;;
	ci)
		# Equivalent to: ${CLANG_FORMAT_COMMAND} --ci ${GIT_EMPTY_TREE_HASH}
		"${CMD[@]}" --ci "$GIT_EMPTY_TREE_HASH"
		;;
	fix)
		# Equivalent to: ${CLANG_FORMAT_COMMAND} ${GIT_EMPTY_TREE_HASH} -f
		"${CMD[@]}" "$GIT_EMPTY_TREE_HASH" -f
		;;
esac

popd >/dev/null

