#!/bin/bash
#
# Copyright 2017 Preetam J. D'Souza
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e
set -u

source bytecode.sh
source mk.sh
source log.sh

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(readlink -f $(dirname "$0"))"

# included dependencies
readonly SIMG2IMG="${SCRIPT_DIR}/deps/bin/simg2img"

# some useful paths -- all relative to $WORKDIR
readonly TMP_DIR="tmp"
readonly IMAGE_DIR="${TMP_DIR}/factory"
readonly SMALI_TMP_DIR="${TMP_DIR}/smali"
readonly VENDOR_MK="device-vendor.mk"
readonly BLOBS_MK="device-partial.mk"
readonly MODULES_MK="Android.mk"

# globals
VENDOR=""
BLOBS=""
VENDOR_DIR=""
WORKDIR=""

# user options
OPT_DEVICE=""
OPT_IMAGE=""
OPT_OUT="."
OPT_INSPECT=false

help () {
    cat <<EOF
Extract vendor files from a factory image and generate vendor makefiles for AOSP.

usage: $SCRIPT_NAME [OPTIONS] -d [DEVICE] -i [IMAGE ZIP]

    -d, --device    device codename
    -i, --image     factory image zip to extract blobs from
    -o, --out       output base dir, defaults to '.'
        --inspect   leave intermediate files in $TMP_DIR for inspection
EOF
}

cleanup () {
    iecho "cleaning up..."
    sudo umount "${IMAGE_DIR}/system" 2>/dev/null
    [ "$OPT_INSPECT" = true ] || rm -rf "$TMP_DIR"
}

extract_file () {
    local readonly file="$1"
    local readonly dest="$2"

    mkdir -p "$(dirname "$dest")"
    cp "$file" "$dest"

}

extract_bytecode () {
    local readonly bytecode="$1"
    local readonly dest="$2"

    if bytecode_is_optimized "$bytecode" ; then
        iecho "  de-optimizing $dest..."
        PATH="${SCRIPT_DIR}/deps/jar:${PATH}" bytecode_deodex \
            "$bytecode" "$dest" "${IMAGE_DIR}/system/framework/arm/boot.oat" "${TMP_DIR}/smali"
    else
        # just mirror the un-optimized apk over exactly
        extract_file "$bytecode" "$dest"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--device) OPT_DEVICE="$2"; shift 2 ;;
        -i|--image) OPT_IMAGE="$2"; shift 2 ;;
        -o|--out) OPT_OUT="$2"; shift 2 ;;
        --inspect) OPT_INSPECT=true; shift ;;
        -h|--help) help; exit 2 ;;
        --) shift; break ;;
        -*) fecho "unrecognized option $1"; exit 2 ;;
        *) break;
    esac
done

VENDOR="$(find "$SCRIPT_DIR" -type d -name "$OPT_DEVICE" | xargs -r dirname | xargs -r basename)"
if [ -z "$VENDOR" ] ; then
    fecho "invalid device: '$OPT_DEVICE'"
    exit 2
fi

if [ ! -f "$OPT_IMAGE" ] ; then
    fecho "invalid image file: '$OPT_IMAGE'"
    exit 2
fi

VENDOR_DIR="vendor/${VENDOR}/${OPT_DEVICE}"
BLOBS="${SCRIPT_DIR}/${VENDOR}/${OPT_DEVICE}/proprietary-blobs.txt"
WORKDIR="${OPT_OUT}/${VENDOR_DIR}"


iecho "setting up output dir '$WORKDIR'..."
mkdir -p "$WORKDIR"
pushd "$WORKDIR" &>/dev/null

trap cleanup EXIT

iecho "preparing factory image..."
mkdir -p "$IMAGE_DIR"
unzip -j "$OPT_IMAGE" -d "$IMAGE_DIR" >/dev/null
pushd "$IMAGE_DIR" &>/dev/null
unzip image-*.zip system.img >/dev/null
"$SIMG2IMG" system.img system-raw.img
mkdir system
wecho "  requesting sudo for loop mount..."
sudo mount -o loop system-raw.img system
popd &>/dev/null

iecho "generating vendor makefiles..."
mk_init "$VENDOR_DIR"

iecho "extracting vendor files from image..."
for blob in $(grep -v "#" < "$BLOBS") ; do # skips empty lines
    image_blob="${IMAGE_DIR}/${blob}"
    [ -f "$image_blob" ] ||  {
        wecho "  missing file from image: $blob"
        continue
    }

    blob_extension="${blob##*.}"
    case "$blob_extension" in
        apk)
            extract_bytecode "$image_blob" "$blob"
            mk_add_apk "$blob" "$VENDOR" "$OPT_DEVICE"
            ;;
        jar)
            extract_bytecode "$image_blob" "$blob"
            mk_add_jar "$blob" "$VENDOR" "$OPT_DEVICE"
            ;;
        *)
            extract_file "$image_blob" "$blob"
            mk_mirror_file "$blob" "$VENDOR"
            ;;
    esac
done

iecho "all tasks completed successfully"
