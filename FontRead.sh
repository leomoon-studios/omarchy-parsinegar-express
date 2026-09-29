#!/usr/bin/env bash
set -euo pipefail

font_path=$1
font_size=$(stat -Lc '%s' -- "$font_path")
if ! [[ $font_size =~ ^[0-9]+$ ]] || (( font_size < 4 )); then
    exit 3
fi
if (( font_size > 5242880 )); then
    exit 2
fi
font_header=$(od -An -tx1 -N4 -- "$font_path")
font_header=${font_header//[[:space:]]/}
if [[ $font_header != 00010000 && $font_header != 4f54544f ]]; then
    exit 3
fi

# Even if the file grows after stat, this process reads at most 5 MiB plus one byte.
head -c 5242881 -- "$font_path" | base64 -w0
