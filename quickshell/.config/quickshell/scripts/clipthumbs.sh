#!/bin/sh

dir=$1
[ -n "$dir" ] || exit 1
shift
mkdir -p "$dir" || exit 1

for id; do
    if [ ! -s "$dir/$id" ]; then
        cliphist decode "$id" > "$dir/$id" 2>/dev/null || rm -f "$dir/$id"
    fi
done

ids=" $* "
for f in "$dir"/*; do
    [ -e "$f" ] || continue
    case "$ids" in
        *" ${f##*/} "*) ;;
        *) rm -f "$f" ;;
    esac
done

exit 0
