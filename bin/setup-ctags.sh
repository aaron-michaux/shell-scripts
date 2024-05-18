#!/bin/bash

set -e

TAGS_DIR="$HOME/.local/${USER}-projects/TAGS"


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

echo
echo "CTAGS:    $(which ctags)"
echo "TAGS_DIR: $TAGS_DIR"
echo
while read DIR ; do
    echo "   $DIR"
    find "$DIR" | ctags -e -L -
done < <(print_dirs)
echo
echo "Done"
echo
