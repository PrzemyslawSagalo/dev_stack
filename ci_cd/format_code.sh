#!/usr/bin/env bash

# The 'set -e' command causes the script to exit immediately if any command returns a non-zero exit status.
set -e

line_length=130
paths_to_format=('./path1' './path2' './path3') # Add your paths here

if [ "$1" == "--check" ]; then
  for path_to_form in "${paths_to_format[@]}"; do
    isort --profile black --line-length="$line_length" "${path_to_form}"  --check-only
    black --line-length="$line_length" "${path_to_form}" --check
  done
else
  for path_to_form in "${paths_to_format[@]}"; do
    isort --profile black --line-length="$line_length" "${path_to_form}"
    black --line-length="$line_length" "${path_to_form}"
    find "${path_to_form}" -type f -print0 | xargs -0 dos2unix --
  done
fi
