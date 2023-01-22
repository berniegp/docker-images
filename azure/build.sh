#!/bin/bash
#
# Build and optionally push all Docker images from subdirectories.

PROG="$(basename "$0")"

usage() {
  echo "Usage: ${PROG} [options]... <tag-prefix> [dir]"
  echo ''
  echo 'Build the Docker images in all subdirectories. Each image will be tagged "tag-prefix:dir-name".'
  echo ''
  echo 'Options:'
  echo ''
  echo '  -h  Display this help and exit'
  echo '  -p  Also push the built images'
}

info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

error() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

main() {
  # Options
  local push=''
  readonly local optstring=":hp"
  while getopts ${optstring} option; do
    case "${option}" in
      h) usage; exit ;;
      p) push='true' ;;
      *)
        error "Unexpected option ${option}"
        usage
        exit 1
        ;;
    esac
  done

  shift $(($OPTIND - 1))

  # Arguments
  if [[ $# -lt 1 ]]; then
    error "Missing arguments"
    usage
    exit 1
  fi
  readonly local TAG_PREFIX="$1"
  readonly local BASE_DIR="${2:-.}"

  local nb_errors=0
  for dir in "${BASE_DIR}"/*/; do
    if [[ -f "${dir}/Dockerfile" ]]; then
      local tag="${TAG_PREFIX}:$(basename "${dir}")"
      info "Building image at ${dir}"

      docker build -t "${tag}" "${dir}"

      if (( $? == 0 )); then
        if [[ $push ]]; then
          docker push "${tag}"
          if (( $? )); then
            nb_errors=$((nb_errors + 1))
          fi
        fi
      else
        nb_errors=$((nb_errors + 1))
      fi
    fi
  done

  if (( $nb_errors )); then
    error "Got ${nb_errors} errors"
    return 1
  fi
}

main "$@"