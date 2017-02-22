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

# Android.mk utilities

readonly _VENDOR_MK="device-vendor.mk"
readonly _BLOBS_MK="device-partial.mk"
readonly _MODULES_MK="Android.mk"

_VENDOR_DIR=""

_mk_echo_autogen_header () {
    # TODO define $SCRIPT_NAME
    echo "# $(date --rfc-3339=date): autogenerated by $SCRIPT_NAME - DO NOT EDIT"
}

_mk_init_vendor_mk () {
    local readonly vendor_dir="$1"

    cat > "$_VENDOR_MK" <<EOF
$(_mk_echo_autogen_header)

\$(call inherit-product, $vendor_dir/$_BLOBS_MK)

PRODUCT_PACKAGES += \\
EOF
}

_mk_init_module_mk () {
    cat > "$_MODULES_MK" <<EOF
$(_mk_echo_autogen_header)

LOCAL_PATH := \$(call my-dir)
EOF
}

_mk_init_blobs_mk () {
    cat > "$_BLOBS_MK" <<EOF
$(_mk_echo_autogen_header)

PRODUCT_COPY_FILES := \\
EOF
}

_mk_add_module_depends () {
    local readonly module="$1"

    echo "    $module \\" >> "$_VENDOR_MK"
}

mk_init () {
    local readonly vendor_dir="$1"

    _VENDOR_DIR="$vendor_dir"
    _mk_init_vendor_mk "$vendor_dir"
    _mk_init_blobs_mk
}

mk_add_apk () {
    local readonly apk="$1"
    local readonly owner="$2"
    local readonly device="$3"

    local readonly apk_basename="$(basename "$apk")"
    local readonly apk_module="${apk_basename%.*}"

    [ -f "$_MODULES_MK" ] || _mk_init_module_mk

    {
        echo
        echo "ifeq (\$(TARGET_DEVICE),$device)"
        echo "include \$(CLEAR_VARS)"
        echo "LOCAL_MODULE := $apk_module"
        echo "LOCAL_MODULE_TAGS := optional"
        echo "LOCAL_BUILT_MODULE_STEM := package.apk"
        echo "LOCAL_MODULE_OWNER := $owner"
        echo "LOCAL_MODULE_CLASS := APPS"
        echo "LOCAL_SRC_FILES := $apk"
        echo "LOCAL_CERTIFICATE := platform"
        echo "LOCAL_MODULE_SUFFIX := \$(COMMON_ANDROID_PACKAGE_SUFFIX)"
        echo "include \$(BUILD_PREBUILT)"
        echo "endif"
    } >> "$_MODULES_MK"

    _mk_add_module_depends "$apk_module"
}

mk_add_jar () {
    local readonly jar="$1"
    local readonly owner="$2"
    local readonly device="$3"

    local readonly jar_basename="$(basename "$jar")"
    local readonly jar_module="${jar_basename%.*}"

    [ -f "$_MODULES_MK" ] || _mk_init_module_mk

    {
        echo
        echo "ifeq (\$(TARGET_DEVICE),$device)"
        echo "include \$(CLEAR_VARS)"
        echo "LOCAL_MODULE := $jar_module"
        echo "LOCAL_MODULE_TAGS := optional"
        echo "LOCAL_MODULE_OWNER := $owner"
        echo "LOCAL_MODULE_CLASS := JAVA_LIBRARIES"
        echo "LOCAL_SRC_FILES := $jar"
        echo "LOCAL_MODULE_SUFFIX := \$(COMMON_JAVA_PACKAGE_SUFFIX)"
        echo "include \$(BUILD_PREBUILT)"
        echo "endif"
    } >> "$_MODULES_MK"

    _mk_add_module_depends "$jar_module"
}

mk_add_custom_module () {
    local readonly mk="$1"

    local readonly mk_basename="$(basename "$mk")"
    local readonly module="${mk_basename%.*}"

    [ -f "$_MODULES_MK" ] || _mk_init_module_mk

    # strip comments and append to modules makefile
    grep -v "#" < "$mk" >> "$_MODULES_MK"

    _mk_add_module_depends "$module"
}

mk_mirror_file () {
    local readonly file="$1"
    local readonly owner="$2"

    [ -f "$_BLOBS_MK" ] || _mk_init_blobs_mk

    echo "    ${_VENDOR_DIR}/${file}:${file}:${owner} \\" >> "$_BLOBS_MK"
}
