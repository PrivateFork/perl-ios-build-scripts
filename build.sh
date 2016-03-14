#!/bin/sh

set -e

SCRIPT_DIR=$(cd $(dirname $0) ; pwd -P)
export PATH=${SCRIPT_DIR}/bin:${PATH}

mkdir -p dist
cd dist

PERL_DIST_URL="http://www.cpan.org/src/5.0/perl-5.22.1.tar.gz"
PERL_DIST_MD5="19295bbb775a3c36123161b9bf4892f1"
PERL_DIST="`basename ${PERL_DIST_URL}`"
if [ "`md5 -q ${PERL_DIST} 2>/dev/null`" != "${PERL_DIST_MD5}" ] ; then
    echo "Downloading Perl distribution..."
    rm -f ${PERL_DIST}
    curl -o ${PERL_DIST} -SL ${PERL_DIST_URL} 
    if [ "`md5 -q ${PERL_DIST} 2>/dev/null`" != "${PERL_DIST_MD5}" ] ; then
	exit 1
    fi
fi

CROSS_DIST_URL="https://github.com/arsv/perl-cross/releases/download/1.0.2/perl-5.22.1-cross-1.0.2.tar.gz"
CROSS_DIST_MD5="5885feb7ee796cd41d986f2cf7d09cfb"
CROSS_DIST="`basename ${CROSS_DIST_URL}`"
if [ "`md5 -q ${CROSS_DIST} 2>/dev/null`" != "${CROSS_DIST_MD5}" ] ; then
    echo "Downloading cross-compilation distribution..."
    rm -f ${CROSS_DIST}
    curl -o ${CROSS_DIST} -SL ${CROSS_DIST_URL}
    if [ "`md5 -q ${CROSS_DIST} 2>/dev/null`" != "${CROSS_DIST_MD5}" ] ; then
	exit 1
    fi
fi

echo "Expanding distributions..."

cd ..
rm -rf build
mkdir -p build

tar -C build -x -z -f dist/${PERL_DIST}
tar -C build -x -z -f dist/${CROSS_DIST}
cd "build/${PERL_DIST%.tar.gz}"

echo "Patching Makefile..."
patch -p0 <<'EOF'
--- Makefile.original	2016-03-10 17:35:20.000000000 -0800
+++ Makefile	2016-03-10 17:35:39.000000000 -0800
@@ -130,7 +130,6 @@
 perl$x: LDFLAGS += -Wl,-rpath,$(archlib)/CORE
 endif
 endif # or should it be "else"?
-perl$x: LDFLAGS += -Wl,-E
 
 perl$x: perlmain$o $(LIBPERL) $(static_tgt) static.list ext.libs
 	$(eval extlibs=$(shell cat ext.libs))
EOF

export DEVELOPER=${DEVELOPER=`xcode-select --print-path`}
export IPHONE_SDK=${IPHONE_SDK=`xcodebuild -showsdks 2>/dev/null | fgrep -- '-sdk iphoneos' | tail -1 | sed 's/^.*-sdk iphoneos//'`}
export IPHONE_MIN_VERSION=${IPHONE_MIN_VERSION=${IPHONE_SDK%.*}.0}

for arch in armv7 armv7s arm64 i386 x86_64 ; do
    echo "Building Perl for ${arch}..."
    ./configure --mode=cross --host-has union_semun --target=arm-apple-darwin --target-tools-prefix=${arch}-apple-darwin- --has=union_semun --no-dynaloader --all-static -Dccdlflags=' ' -Doptimize=-g --prefix=/tmp
    make
    make install
    make clean
done

exit

#cp .libs/lib{jpeg,turbojpeg}.a ${LIB}/${PLATFORM}/${ARCH}
#lipo -create -output ${LIB}/libjpeg.a ${LIB}/*/*/libjpeg.a
