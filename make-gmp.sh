
lunzip gmp-6.1.2.tar.tz
tar -xvf gmp-6.1.2.tar
cd gmp-6.1.2

export CC=emcc
export CFLAGS="-m32"
export LDFLAGS="-m32"

./configure --prefix=/opt/WASM --build=i686-pc-linux-gnu --enable-static --enable-assembly=no

