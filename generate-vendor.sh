#!/bin/bash

set -e
set -u

source bytecode.sh
source android-mk.sh
source log.sh

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(readlink -f $(dirname "$0"))"

# included dependencies
readonly SIMG2IMG="${SCRIPT_DIR}/deps/bin/simg2img"
readonly BAKSMALI="${SCRIPT_DIR}/deps/jar/baksmali"
readonly SMALI="${SCRIPT_DIR}/deps/jar/smali"

# some useful paths -- all relative to WORKDIR
readonly TMP_DIR="tmp"
readonly IMAGE_DIR="${TMP_DIR}/factory"
readonly SMALI_TMP_DIR="${TMP_DIR}/smali"
readonly VENDOR_MK="device-vendor.mk"
readonly BLOBS_MK="device-partial.mk"
readonly MODULES_MK="Android.mk"

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
generate vendor makefiles and extract blobs from a factory image

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

extract_bytecode () {
    local readonly bytecode="$1"
    local readonly dest="$2"

    if bytecode_is_optimized "$bytecode" ; then
        iecho "  de-optimizing $dest..."
        PATH="${SCRIPT_DIR}/deps/jar:${PATH}" bytecode_deodex \
            "$bytecode" "$dest" \
            "${IMAGE_DIR}/system/framework/arm/boot.oat"
    else
        # just mirror the un-optimized apk over exactly
        mkdir -p "$(dirname "$dest")"
        cp "$bytecode" "$dest"
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

    blob_dirname="$(dirname $blob)"
    blob_basename="$(basename $blob)"
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
            mkdir -p "$blob_dirname"
            cp "$image_blob" "$blob"

            mk_mirror_file "$blob" "$VENDOR"
            ;;
    esac
done


iecho "all tasks completed successfully"
