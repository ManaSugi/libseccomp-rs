#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0 or MIT
#
# Copyright 2021 Sony Group Corporation
#

set -o errexit

# installed libseccomp version by default
DEFAULT_LIBSECCOMP_VER="2.5.3"
WORK_DIR="$(mktemp -d --tmpdir build-libseccomp.XXXXX)"

function finish() {
    rm -rf "${WORK_DIR}"
}

trap finish EXIT

function build_and_install_gperf() {
    gperf_version="3.1"
    gperf_url="https://mirrors.kernel.org/gnu/gperf"
    gperf_tarball="gperf-${gperf_version}.tar.gz"
    gperf_tarball_url="${gperf_url}/${gperf_tarball}"

    echo "Build and install gperf version ${gperf_version}"
    gperf_install_dir="$(mktemp -d --tmpdir build-gperf.XXXXX)"
    curl -sLO "${gperf_tarball_url}"
    tar -xf "${gperf_tarball}"
    pushd "gperf-${gperf_version}"
    ./configure --prefix="${gperf_install_dir}"
    make
    make install
    export PATH=$PATH:"${gperf_install_dir}"/bin
    popd
    echo "Gperf installed successfully"
}

function build_and_install_libseccomp() {
    libseccomp_version=${opt_ver}
    libseccomp_url="https://github.com/seccomp/libseccomp"
    libseccomp_tarball="libseccomp-${libseccomp_version}.tar.gz"
    libseccomp_tarball_url="${libseccomp_url}/releases/download/v${libseccomp_version}/${libseccomp_tarball}"

    echo "Build and install libseccomp version ${libseccomp_version}"
    libseccomp_install_dir=$opt_dir
    mkdir -p "${libseccomp_install_dir}"
    curl -sLO "${libseccomp_tarball_url}"
    tar -xf "${libseccomp_tarball}"
    pushd "libseccomp-${libseccomp_version}"
    if [ $opt_musl -eq 1 ]; then
        # Set FORTIFY_SOURCE=1 because the musl-libc does not have some functions about FORTIFY_SOURCE=2
        cflags="-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1 -O2"
        ./configure --prefix="${libseccomp_install_dir}" CFLAGS="${cflags}" --enable-static
    else
        ./configure --prefix="${libseccomp_install_dir}" --enable-static
    fi
    make
    make install
    popd
    echo "Libseccomp installed successfully"
}

#
# Print out script usage details
#
function usage() {
cat <<EOF
Build and install libseccomp library from sources

USAGE:
  install_libseccomp [-m] [-v VERSION] [-i DIR]

OPTIONS:
  -h            : show this help message
  -m            : install libseccomp library for musl-libc [default: GNU-libc]
  -v [VERSION]  : specify the version of installed libseccomp library [default: ${DEFAULT_LIBSECCOMP_VER}]
  -i [DIR]      : specify the directory for installing libseccomp library [default: /usr/local]
EOF
}

function main() {
    local opt_ver=${DEFAULT_LIBSECCOMP_VER}
    local opt_musl=0
    local opt_dir="/usr/local"

    while getopts "hmi:v:" opt; do
        case $opt in
            m)
                opt_musl=1
                ;;
            i)
                opt_dir="${OPTARG}"
                ;;
            v)
                opt_ver="${OPTARG}"
                ;;
            h|*)
                usage
                exit 1
                ;;
        esac
    done

    pushd "${WORK_DIR}"
    # gperf is required for building the libseccomp.
    build_and_install_gperf
    build_and_install_libseccomp
    popd
}

main "$@"
