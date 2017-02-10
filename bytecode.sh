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

# bytecode utilities

bytecode_is_optimized () {
    local readonly bytecode="$1"

    # optimized bytecode modules do not have classes.dex
    return $(unzip -l "$bytecode" | grep -e "classes[[:digit:]]*.dex" | wc -l)
}

bytecode_deodex () {
    local readonly bytecode="$1"
    local readonly deodexed_bytecode="$2"
    local readonly boot_oat="$3"
    local readonly output_dir="${4:-smali}"

    local readonly bytecode_dirname="$(dirname "$bytecode")"
    local readonly bytecode_basename="$(basename "$bytecode")"
    local readonly bytecode_name="${bytecode_basename%.*}"
    local readonly bytecode_odex="$(find "$bytecode_dirname" -name "${bytecode_name}.odex")"
    local readonly bytecode_smali_dir="${output_dir}/${bytecode_name}"

    # de-optimize .odex -> .dex, and disassemble
    baksmali deodex "$bytecode_odex" -b "$boot_oat" -o "$bytecode_smali_dir"

    # v2.1.0
    #"$BAKSMALI" -x -c boot.oat -d "$(dirname "$boot_oat")" "$bytecode_odex" -o "$bytecode_smali_dir"

    # assemble back into classes.dex
    smali assemble "$bytecode_smali_dir" -o "${bytecode_smali_dir}/classes.dex"

    # v2.1.0
    #"$SMALI" "$bytecode_smali_dir" -o "${bytecode_smali_dir}/classes.dex"

    # re-pack bytecode with classes.dex
    mkdir -p "$(dirname "$deodexed_bytecode")"
    cp "$bytecode" "$deodexed_bytecode"
    zip -gj "$deodexed_bytecode" "${bytecode_smali_dir}/classes.dex" >/dev/null
}
