#!/bin/bash

set -e

BOOST_VERSION=1_69_0
PREFIX=/usr/local
NO_CLEANUP=0

if [ "$NO_CLEANUP" = "1" ] ; then
    TMPD=$HOME/TMP/libpurple
    mkdir -p $TMPD
else
    TMPD=$(mktemp -d /tmp/$(basename $0).XXXXXX)
fi

trap cleanup EXIT
cleanup()
{
    if ! [ "$NO_CLEANUP" = "1" ] ; then
        rm -rf $TMPD
    fi
}

cd $TMPD

sudo apt-get -y install intltool libgtk2.0-dev libgtkspell-dev libxml2-dev libgstreamer1.0-dev libidn11-dev libmeanwhile-dev libavahi-client-dev libavahi-glib-dev libdbus-glib-1-dev libnm-glib-dev tcl-dev tk-dev

wget https://iweb.dl.sourceforge.net/project/pidgin/Pidgin/2.13.0/pidgin-2.13.0.tar.bz2
cat pidgin-2.13.0.tar.bz2 | bunzip2 -dc | tar -xvf -
cd pidgin-2.13.0
./configure --prefix=/usr/local --disable-screensaver --disable-vv --disable-perl --enable-nss=yes 
make -j`nproc`
sudo make install

wget https://github.com/dequis/purple-facebook/releases/download/v0.9.6/purple-facebook-0.9.6.tar.gz
cat purple-facebook-0.9.6.tar.gz | gunzip -dc | tar -xvf -
cd purple-facebook-0.9.6
./configure --prefix=/usr/local
make -j`nproc`
sudo make install

sudo ldconfig
