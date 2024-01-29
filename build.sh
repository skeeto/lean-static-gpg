#!/bin/sh

set -e

MUSL_VERSION=1.2.4
GNUPG_VERSION=2.4.3
LIBASSUAN_VERSION=2.5.6
LIBGCRYPT_VERSION=1.10.3
LIBGPGERROR_VERSION=1.47
LIBKSBA_VERSION=1.6.5
NPTH_VERSION=1.6
PINENTRY_VERSION=1.2.1

DESTDIR=
PREFIX="$PWD/gnupg"
WORK="$PWD/work"
PATH="$PWD/work/deps/bin:$PATH"
NJOBS=$(nproc)
GCC=

usage() {
    cat <<EOF
usage: $0 [-Cch] [-d destdir] [-j njobs] [-p prefix] [-g /path/to/gcc/binary]
  -C         clean all build files including downloads
  -c         clean build files, preserving downloads
  -g         skip the building of the musl-gcc binary and use the specified custom gcc binary instead
  -h         print this help message
EOF
}

clean() {
    rm -rf "$WORK"
}

distclean() {
    clean
    rm -rf download
}

download() {
    gnupgweb=https://gnupg.org/ftp/gcrypt
    mkdir -p download
    (
        cd download/
        xargs -n1 curl -O <<EOF
https://www.musl-libc.org/releases/musl-$MUSL_VERSION.tar.gz
$gnupgweb/gnupg/gnupg-$GNUPG_VERSION.tar.bz2
$gnupgweb/libassuan/libassuan-$LIBASSUAN_VERSION.tar.bz2
$gnupgweb/libgcrypt/libgcrypt-$LIBGCRYPT_VERSION.tar.bz2
$gnupgweb/libgpg-error/libgpg-error-$LIBGPGERROR_VERSION.tar.bz2
$gnupgweb/libksba/libksba-$LIBKSBA_VERSION.tar.bz2
$gnupgweb/npth/npth-$NPTH_VERSION.tar.bz2
$gnupgweb/pinentry/pinentry-$PINENTRY_VERSION.tar.bz2
EOF
    )
}
checkGCC() {
	if ! echo 'int main(){}' > "$WORK/dummy.c" || ! $GCC -o "$WORK/dummy" "$WORK/dummy.c" &> /dev/null || ! [[ -x "$WORK/dummy" ]]; then
		echo "GCC unusable!"
		rm "$WORK/dummy" "$WORK/dummy.c" &> /dev/null
		exit;
	else
		echo "GCC usable!"
		rm "$WORK/dummy" "$WORK/dummy.c" &> /dev/null
	fi
}

while getopts cCDd:j:hp:g: name
do
    case $name in
    c) clean; exit 0;;
    C) distclean; exit 0;;
    D) download; exit 0;;
    h) usage; exit 0;;
    g) GCC="$OPTARG";;
    j) NJOBS="$OPTARG";;
    p) PREFIX="$OPTARG";;
    d) DESTDIR="$OPTARG";;
    ?) usage >&2; exit 1;;
    esac
done

clean

if [ ! -d download/ ]; then
    download
fi

mkdir -p "$DESTDIR$PREFIX" "$WORK/deps"
if [ -z "$GCC" ];then
	tar -C "$WORK" -xzf download/musl-$MUSL_VERSION.tar.gz
	(
    		mkdir -p "$WORK/musl"
    		cd "$WORK/musl"
    		../musl-$MUSL_VERSION/configure \
        		--prefix="$WORK/deps" \
        		--enable-wrapper=gcc \
        		--syslibdir="$WORK/deps/lib"
    		make -kj$NJOBS
    		make install
	)
	GCC="$WORK/deps/bin/musl-gcc"
fi
checkGCC;

tar -C "$WORK" -xjf download/npth-$NPTH_VERSION.tar.bz2
(
    mkdir -p "$WORK/npth"
    cd "$WORK/npth"
    ../npth-$NPTH_VERSION/configure \
        CC="$GCC" \
        --prefix="$WORK/deps" \
        --enable-shared=no \
        --enable-static=yes
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/libgpg-error-$LIBGPGERROR_VERSION.tar.bz2
(
    mkdir -p "$WORK/libgpg-error"
    cd "$WORK/libgpg-error"
    ../libgpg-error-$LIBGPGERROR_VERSION/configure \
        CC="$GCC" \
        --prefix="$WORK/deps" \
        --enable-shared=no \
        --enable-static=yes \
        --disable-nls \
        --disable-doc \
        --disable-languages
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/libassuan-$LIBASSUAN_VERSION.tar.bz2
(
    mkdir -p "$WORK/libassuan"
    cd "$WORK/libassuan"
    ../libassuan-$LIBASSUAN_VERSION/configure \
        CC="$GCC" \
        --prefix="$WORK/deps" \
        --enable-shared=no \
        --enable-static=yes \
        --with-libgpg-error-prefix="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/libgcrypt-$LIBGCRYPT_VERSION.tar.bz2
(
    mkdir -p "$WORK/libgcrypt"
    cd "$WORK/libgcrypt"
    ../libgcrypt-$LIBGCRYPT_VERSION/configure \
        CC="$GCC" \
        --prefix="$WORK/deps" \
        --enable-shared=no \
        --enable-static=yes \
        --disable-doc \
        --with-libgpg-error-prefix="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/libksba-$LIBKSBA_VERSION.tar.bz2
(
    mkdir -p "$WORK/libksba"
    cd "$WORK/libksba"
    ../libksba-$LIBKSBA_VERSION/configure \
        CC="$GCC" \
        --prefix="$WORK/deps" \
        --enable-shared=no \
        --enable-static=yes \
        --with-libgpg-error-prefix="$WORK/deps"
    make -kj$NJOBS
    make install
)

tar -C "$WORK" -xjf download/gnupg-$GNUPG_VERSION.tar.bz2
(
    mkdir -p "$WORK/gnupg"
    cd "$WORK/gnupg"
    ../gnupg-$GNUPG_VERSION/configure \
        CC="$GCC" \
        LDFLAGS="-static -s" \
        --prefix="$PREFIX" \
        --with-libgpg-error-prefix="$WORK/deps" \
        --with-libgcrypt-prefix="$WORK/deps" \
        --with-libassuan-prefix="$WORK/deps" \
        --with-ksba-prefix="$WORK/deps" \
        --with-npth-prefix="$WORK/deps" \
        --with-agent-pgm="$PREFIX/bin/gpg-agent" \
        --with-pinentry-pgm="$PREFIX/bin/pinentry" \
        --disable-bzip2 \
        --disable-card-support \
        --disable-ccid-driver \
        --disable-dirmngr \
        --disable-gnutls \
        --disable-gpg-blowfish \
        --disable-gpg-cast5 \
        --disable-gpg-idea \
        --disable-gpg-md5 \
        --disable-gpg-rmd160 \
        --disable-gpgtar \
        --disable-ldap \
        --disable-libdns \
        --disable-nls \
        --disable-ntbtls \
        --disable-photo-viewers \
        --disable-regex \
        --disable-scdaemon \
        --disable-sqlite \
        --disable-wks-tools \
        --disable-zip
    make -kj$NJOBS
    make install DESTDIR="$DESTDIR"
    rm "$DESTDIR$PREFIX/bin/gpgscm"
)

tar -C "$WORK" -xjf download/pinentry-$PINENTRY_VERSION.tar.bz2
(
    mkdir -p "$WORK/pinentry"
    cd "$WORK/pinentry"
    ../pinentry-$PINENTRY_VERSION/configure \
        CC="$GCC" \
        LDFLAGS="-static -s" \
        --prefix="$PREFIX" \
        --with-libgpg-error-prefix="$WORK/deps" \
        --with-libassuan-prefix="$WORK/deps" \
        --disable-ncurses \
        --disable-libsecret \
        --enable-pinentry-tty \
        --disable-pinentry-curses \
        --disable-pinentry-emacs \
        --disable-inside-emacs \
        --disable-pinentry-gtk2 \
        --disable-pinentry-gnome3 \
        --disable-pinentry-qt \
        --disable-pinentry-tqt \
        --disable-pinentry-fltk
    make -kj$NJOBS
    make install DESTDIR="$DESTDIR"
)

rm -rf "$DESTDIR$PREFIX/sbin"
rm -rf "$DESTDIR$PREFIX/share/doc"
rm -rf "$DESTDIR$PREFIX/share/info"
