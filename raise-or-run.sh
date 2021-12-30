#!/usr/bin/env bash
################################################################################
# Sources & improvements:
# - https://gist.github.com/timpulver/4753750 -- to improve debug-list-all
# - use a browser controller cli to find a tab w/ heavy page loads e.g. monday.com
# - automated provisioning of keyboard shortcuts and new raise-or-runs from $#
# == 0 invocations.
################################################################################

# Raise or run an application for efficient navigation.

# This prevents needing to ALT+TAB your way through many windows.
# Rather with this you just say "Give me the web" or "Give me anki".

# This will prevent accidental window duplication as well with apps
# like the terminal or the web where having multiple instances running
# can quickly lead to needing to spend clock cycles looking for a specific
# instance of the application.

main() {

    configure-per-os

    case $# in
    0)
        raise-application-by-string-guess "$@"
    ;;
    1)
        die "ERROR: invalid number of args: $#"
    ;;
    2)
        raise-or-run "$@"
    ;;
    3)
        raise-window-or-raise-app-or-launch-app "$@"
    ;;

    *)
        die "ERROR: invalid number of args: $#"
    ;;
    esac
}
macos-list-all-currently-active() {

    # TODO: merge these to be on the same line somehow
    # Pieces:
    # https://gist.github.com/timpulver/4753750
    # https://stackoverflow.com/a/5293758
    echo ACTIVE APPS:
    osascript <<EOF | tr , '\n' | trim-empty-lines
tell application "System Events"
    get name of every process
end tell
EOF

    echo
    echo

    echo WINDOW TITLES:
    osascript <<EOF | tr , '\n' | trim-empty-lines
tell application "System Events"
    get name of every window of every process
end tell
EOF

}
function trim-empty-lines() { sed "/^\$/d"; }
try-to-raise-by-window-class() {
    # this is usually something like RDN, e.g. com.company.brave
    $wmctrl -xa "${1?need a string to try and match on}"
}
try-to-raise-by-window-title() {
    $wmctrl -a "${1?need a string to try and match on}"
}
raise-application-by-string-guess() {
    raise_target=$(zenity --entry --text "Raise Application:")
     try-to-raise-by-window-class $raise_target \
        || try-to-raise-by-window-title $raise_target \
        &
}
raise-or-run() {
    raise_target="$1"
    run_target="$2"

    # target by class (-xa), then by title (-a)
    try-to-raise-by-window-class "$raise_target" \
        || try-to-raise-by-window-title "$raise_target" \
        \
        || $run_target \
        &
}
raise-window-or-raise-app-or-launch-app() {
    raise_target_1="$1"
    raise_target_2="$2"
    run_target="$3"

    # Sometimes you want to specify opening a specific window instance
    # of an application if it is open.
    # Eg. open the add window in anki if it exists, if not then open the
    # default window if it exists, and if not then launch anki.

    # target by class (-xa), then by title (-a)
    try-to-raise-by-window-class "$raise_target_1" \
        || try-to-raise-by-window-title "$raise_target_1" \
        \
        || try-to-raise-by-window-class "$raise_target_2" \
        || try-to-raise-by-window-title "$raise_target_2" \
        \
        || $run_target \
        &
}
configure-per-os() {
    case "$OSTYPE" in
        linux-gnu)
            wmctrl=wmctrl
            : # do nothing; it was built for linux
            ;;
        darwin*)
            # Mac OSX
            wmctrl=wmctrl-fake
            ;;
        *)
            die "unknown os"
            ;;
    esac
}
wmctrl-fake() {
    echo "DRY: wmctrl $@"
    # pass if false is not found
    ! ( echo "$@" | grep 'non-matching string' )
}
die() {
    printred "$1" >&2
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        exit ${2-9}
    else
        return ${2-9}
    fi
}
printred() {
    c_grey="\x1b[38;5;1m"
    nc="\033[0m"
    printf "${c_grey}%s${nc}\n" "$*"
}
test-raise-interactive() {
    main
}
test-raise-run() {
    main "Emacs-todo" "emacs --title Emacs-todo ~/todo.el"
}
test-raise-raise-run() {
    main anki "Anki -- add" /Applications/Anki.app
}
test-logic() {
    main 'non-matching string' 'echo xasdf'
}
test-all() {
    test-raise-interactive
    test-raise-run
    test-raise-raise-run
    test-logic
}

# If executed as a script, instead of sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    main "$@"
else
    echo "${BASH_SOURCE[0]}" sourced >&2
    shopt -s expand_aliases # reset from source-harnessing
fi

