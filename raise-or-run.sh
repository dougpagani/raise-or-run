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
    if [[ $# -eq 0 ]]
    then
        raise-application-by-string-guess
    fi

    if [[ $# -eq 2 ]]
    then
        raise_target=$1
        run_target=$2

        # target by class (-xa), then by title (-a)
        wmctrl -xa $raise_target || \
        wmctrl -a $raise_target || \
        $run_target &
    fi

    # Sometimes you want to specify opening a specific window instance
    # of an application if it is open.
    # Eg. open the add window in anki if it exists, if not then open the
    # default window if it exists, and if not then launch anki.
    if [[ $# -eq 3 ]]
    then
        raise_target_1=$1
        raise_target_2=$2
        run_target=$3

        # target by class (-xa), then by title (-a)
        wmctrl -xa $raise_target_1 || \
        wmctrl -a $raise_target_1 || \
        wmctrl -xa $raise_target_2 || \
        wmctrl -a $raise_target_2 || \
        $run_target &
    fi
}
raise-application-by-string-guess() {
    raise_target=$(zenity --entry --text "Raise Application:")
    wmctrl -xa $raise_target \
        || wmctrl -a $raise_target \
        &
}
main "$@"

