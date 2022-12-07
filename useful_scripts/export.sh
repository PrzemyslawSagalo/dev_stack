#!/bin/bash

export_version () {
  current_date=$(date '+%Y.%m.%d.%H%M%S')
  git_hash=$(git describe --always)
  export VERSION="${current_date}.${git_hash}"
}

export_version
