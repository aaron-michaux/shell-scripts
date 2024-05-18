#!/bin/bash

set -e

TAGS_DIR="/home/BRCMLTD/am894222/.cache/bazel/TAGS"


show_help()
{
    cat <<EOF

   Usage: $(basename $0)

      WORK IN PROGRESS

      Put '.dir-locals.el' in the root directory of the project:

((nil . ((counsel-etags-project-root . "$PWD")
         (counsel-etags-extra-tags-files . ("/home/BRCMLTD/am894222/.cache/bazel/TAGS")))))

EOF
}

print_dirs()
{
    echo "" | clang++ -E -v -xc++ - 2>&1 | grep -E '^ */' | sed 's,^ ,,'
}

mkdir -p "/home/BRCMLTD/am894222/.cache/bazel/TAGS"
cd "/home/BRCMLTD/am894222/.cache/bazel/TAGS"

while read DIR ; do
    find "$DIR" | ctags -e -L -
done < <(print_dirs)

