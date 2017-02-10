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

# logging utilities

readonly TCOL_RED="$(tput setaf 1)"
readonly TCOL_GREEN="$(tput setaf 2)"
readonly TCOL_YELLOW="$(tput setaf 3)"
readonly TCOL_DEF="$(tput op)"

iecho () { echo "${TCOL_GREEN}I${TCOL_DEF}: $@"; }
decho () { echo "D: $@"; }
wecho () { echo "${TCOL_YELLOW}W${TCOL_DEF}: $@"; }
fecho () { echo >&2 "${TCOL_RED}E${TCOL_DEF}: $@"; }
