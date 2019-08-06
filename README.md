# Lean, static GnuPG build for Linux

This script builds GnuPG from source. Extra features, unsafe
cryptographic primitives, and compression is all disabled. Only
`pinentry-tty` is built. All binaries are static, which is done by first
building musl and then linking against it. The final installation is
~18MB.

Unfortunately the installation prefix is hardcoded in the binaries, so
the final installation isn't relocatable. Though the binaries will work
on any Linux system with the same architecture so long as they're
installed to the same prefix. The script's `-p` option controls the
install prefix, which defaults to `gnupg/` in the working directory. The
`-d` option sets `DESTDIR` to stage for packaging.

I only test on Debian, and the script likely requires tweaking for
non-Debian systems. The main value is capturing a bunch of subtle
configuration details I figured out. I'm unlikely to keep all the
individual package versions up to date.

Note: Since binaries are statically linked, some memory safety security
features are disabled, such as ASLR.

## Usage

    $ ./build.sh

It will download all the source tarballs on the first run and re-use
them for repeated builds.
