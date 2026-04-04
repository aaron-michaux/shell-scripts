#!/bin/bash

TMPD="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
trap "rm -rf $TMPD" EXIT

is_movie_file() {
  local FILENAME="$1"
  transcode.sh -i "$FILENAME" --info >/dev/null 2>&1 </dev/null && return 0 || return 1
}

set_is_movie_xattr() {
  local FILENAME="$1"
  setfattr -n user.is_movie -v "$(is_movie_file "$FILENAME" && echo "True" || echo "False")" "$FILENAME"
}

lazy_is_movie_file() {
  local FILENAME="$1"
  VALUE="$(getfattr -n user.is_movie "$FILENAME" 2>/dev/null | grep user.is_movie || true)"
  if [ "$VALUE" = "" ]; then
    set_is_movie_xattr "$FILENAME"
    lazy_is_movie_file "$FILENAME" && return 0 || return 1
  fi
  [ "$VALUE" = "user.is_movie=\"True\"" ] && return 0 || return 1
}

find_movies() {
  local DIR="$1"
  find "$DIR" -type f | grep -Ev '.jpg' | grep -Ev '.jpeg' | grep -Ev '.nfo' | sort | while read F; do
    lazy_is_movie_file "$F" && echo "$F"
  done
}

lazy_movies() {
  if [ ! -f "$TMPD/movies" ]; then
    find_movies "$1" >"$TMPD/movies"
  fi
  cat "$TMPD/movies"
}

# O(n^2)
file_pairs() {
  local DIR="$1"
  lazy_movies "$DIR" >/dev/null 2>&1
  mapfile -t lines <"$TMPD/movies"
  for ((i = 0; i < ${#lines[@]}; i++)); do
    for ((j = i + 1; j < ${#lines[@]}; j++)); do
      printf '%q   %q\n' "${lines[i]}" "${lines[j]}"
    done
  done
}

(($# == 0)) && DIR="." || DIR="$1"
file_pairs "$DIR" | while read A B; do
  set +e
  movie-hamming-distance.py --with-exit-code "$A" "$B" 1>/dev/null 2>/dev/null </dev/null
  DIST=$?
  set -e
  printf "%d   %-50q  %-50q\n" $DIST "$A" "$B"
done
