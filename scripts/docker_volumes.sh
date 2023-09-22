#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# Script name:  docker_volumes.sh
# Description:  Backup and restore Docker volumes
# Author:       Vadim Klimov
# License:      MIT License
# Usage:        docker_volumes.sh {backup|restore} -d <directory>
# ---------------------------------------------------------------------------

set -euo pipefail

# Main
main() {
    [[ "$#" -lt 1 ]] && err "Command is not specified"

    command=$1
    shift

    case $command in
    backup | restore) {
        while getopts ":d:" option; do
            case "$option" in
            d) dir="$OPTARG" ;;
            \?) err "Invalid option: -$OPTARG" ;;
            :) err "Argument missing for option -$OPTARG" ;;
            esac
        done

        [[ -z "${dir:-}" ]] && err "Directory is not specified"
        [[ ! -d "$dir" ]] && err "Directory does not exist: $dir"

        backup_dir="$(readlink -f "$dir")"
        echo "Backup directory: $backup_dir"
        cd "$backup_dir" || exit

        docker pull -q alpine >/dev/null
        $command
    } ;;
    help) usage ;;
    *) err "Unknown command: $command" ;;
    esac
}

# Backup volumes
backup() {
    for volume_name in $(docker volume ls -q); do
        local file_name="$volume_name.tar.gz"
        touch "$file_name"
        docker run --rm -it \
            -v "$volume_name":/source:ro \
            -v "$(PWD)/$file_name":/backup.tar.gz \
            alpine \
            ash -c "cd /source && tar -czf /backup.tar.gz ."
        echo "Volume $volume_name backed up to file $file_name"
    done
}

# Restore volumes
restore() {
    for file_name in *.tar.gz; do
        local volume_name="${file_name%.tar.gz}"
        echo "Restoring volume $volume_name from file $file_name"
        docker run --rm -it \
            -v "$(PWD)/$file_name":/backup.tar.gz:ro \
            -v "$volume_name":/destination \
            alpine \
            ash -c "cd /destination && tar -xzf /backup.tar.gz"
    done
}

# Error logging
err() {
    echo "$*" >&2
    return 1
}

# Usage message
usage() {
    echo "Description:"
    echo "  Backup and restore Docker volumes"
    echo
    echo "Usage:"
    echo "  $0 {backup|restore} -d <directory>"
    echo
    echo "Commands:"
    echo "  backup     Backup Docker volumes"
    echo "  restore    Restore Docker volumes"
    echo "  help       Display usage message"
    echo
    echo "Options:"
    echo "  -d <directory>    Backup directory"
}

main "$@"
