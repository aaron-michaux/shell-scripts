#!/bin/bash

set -e

PPWD="$(cd "$(dirname "$0")" ; pwd)"

if [ -L "$HOME/.emacs.d" ] ; then
    rm -f $HOME/.emacs.d    
fi
mkdir -p $HOME/.emacs.d
rm -rf "$HOME/.emacs.d/plugins"
rm -rf "$HOME/.emacs.d/themes"

ln -s "$PPWD/plugins" "$HOME/.emacs.d/plugins"
ln -s "$PPWD/themes" "$HOME/.emacs.d/themes"

if [ -f "$HOME/.emacs" ] ; then
    mv "$HOME/.emacs" "$HOME/.emacs.bak"
elif [ -L "$HOME/.emacs" ] ; then
    rm -f "$HOME/.emacs"
fi

ln -s "$PPWD/dot-emacs.el" "$HOME/.emacs"

# .emacs   -> /home/amichaux/Documents/Dropbox/Home/emacs/dot-emacs.el
# .emacs.d -> /home/amichaux/Documents/Dropbox/Home/emacs

