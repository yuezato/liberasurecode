#! /usr/bin/env bash

set -eux

BUILD_DIR=$PWD
MAKE_FLAGS=""
export CPATH="${BUILD_DIR}/include:${BUILD_DIR}/include/jerasure:${CPATH:-}"
export LIBRARY_PATH="${BUILD_DIR}/lib:${LIBRARY_PATH:-}"

# Please try and add other distributions.
case "$(uname)" in
    "Linux") MAKE_FLAGS="-j$(nproc)";;
    "Darwin") MAKE_FLAGS="-j$(sysctl -n hw.ncpu)"
esac

#
# gf-complete
#
git clone https://github.com/ceph/gf-complete.git
cd gf-complete/
git checkout a6862d1
./autogen.sh
if [[ $DEBUG = true ]]; then
    ./configure --disable-shared --with-pic --prefix $BUILD_DIR CFLAGS="${CFLAGS:-} -O0 -g"
else
    ./configure --disable-shared --with-pic --prefix $BUILD_DIR
fi
make $MAKE_FLAGS install
cd ../

#
# jerasure
#
git clone https://github.com/ceph/jerasure.git
cd jerasure/
git checkout de1739c
autoreconf --force --install
if [[ $DEBUG = true ]]; then
    ./configure --disable-shared --enable-static --with-pic --prefix $BUILD_DIR CFLAGS="${CFLAGS:-} -O0 -g"
else
    ./configure --disable-shared --enable-static --with-pic --prefix $BUILD_DIR
fi
make $MAKE_FLAGS install
cd ../

#
# liberasurecode
#
git clone https://github.com/openstack/liberasurecode.git
cd liberasurecode/
git checkout 1.5.0
if [ "$(uname)" == "Darwin" ]; then
    # if the compiler has the feature to check `address-of-packed-member`, we suppress it.
    # it is only annoying for liberasurecode v1.5.0.
    patch -p1 < ../for_darwin_to_detect_compiler_flag.patch
fi
./autogen.sh
if [[ $DEBUG = true ]]; then
    LIBS="-lJerasure -lerasurecode_rs_vand" ./configure --disable-shared --with-pic --prefix $BUILD_DIR CFLAGS="${CFLAGS:-} -O0 -g"
else
    LIBS="-lJerasure -lerasurecode_rs_vand" ./configure --disable-shared --with-pic --prefix $BUILD_DIR
fi
patch -p1 < ../liberasurecode.patch # Applies a patch for building static library
patch -p1 < ../make_liberasurecode_rs_vand_static.patch # Applies a patch for building static library
make $MAKE_FLAGS install
# FIX:
# liberasurecode.a と liberasurecode_rs_vand.a に rs_galois.c のコンパイル結果が入ってしまい
# symbol duplicate になるので取り除いている
# Makefile.amに工夫した方が良いと思うし他に良い手があると思うが力技で解決している
echo $(pwd)
cd ..
echo $(pwd)
ar -dv lib/liberasurecode.a liberasurecode_la-rs_galois.o
