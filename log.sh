# logging utilities

readonly TCOL_RED="$(tput setaf 1)"
readonly TCOL_GREEN="$(tput setaf 2)"
readonly TCOL_YELLOW="$(tput setaf 3)"
readonly TCOL_DEF="$(tput op)"

iecho () { echo "${TCOL_GREEN}I${TCOL_DEF}: $@"; }
decho () { echo "D: $@"; }
wecho () { echo "${TCOL_YELLOW}W${TCOL_DEF}: $@"; }
fecho () { echo >&2 "${TCOL_RED}E${TCOL_DEF}: $@"; }
