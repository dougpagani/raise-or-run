#!/usr/bin/env bash
################################################################################
# Sources & improvements:
# - https://gist.github.com/timpulver/4753750 -- to improve debug-list-all
# - use a browser controller cli to find a tab w/ heavy page loads e.g. monday.com
# - automated provisioning of keyboard shortcuts and new raise-or-runs from $#
# == 0 invocations.
# - some osascript in a related task: https://apple.stackexchange.com/a/286942
################################################################################

# Raise or run an application for efficient navigation.

# This prevents needing to ALT+TAB your way through many windows.
# Rather with this you just say "Give me the web" or "Give me anki".

# This will prevent accidental window duplication as well with apps
# like the terminal or the web where having multiple instances running
# can quickly lead to needing to spend clock cycles looking for a specific
# instance of the application.
CONFIG_FILE=~/.raise-or-run-config

main() {

    configure-per-os

    case "$OSTYPE" in
        linux-gnu)
            main-linux "$@"
            ;;
        darwin*)
            main-macos "$@"
            ;;
        *)
            die "unknown os"
            ;;
    esac
}
main-macos() {
    if [[ "$1" = --web ]]; then
        raise-or-open-url "$2"
        return "$?"
    fi
    if [[ "$1" = --devtools ]]; then
        # This backdoor is here because the keyshortcut program is struggling
        # with string-within-string, proper-argv parsing.
        test-chromium-debugger
        return "$?"
    fi
    case $# in
    3)
        macos-try-to-raise-by-window-title "$@"
    ;;
    *)
        die "ERROR: invalid number of args: $#"
    ;;
    esac
}
raise-or-open-url() {
    set-browser-config
# set -x
    # Core possible dependencies:
    # https://github.com/arbal/brave-control
    # https://github.com/prasmussen/chrome-cli
    targetUrl="${1?need a url to look for / open}"

    linksoutput=$(chrome-cli list links)
    urlmatches=$(echo "$linksoutput" | grep "$targetUrl")
    if [[ $? -eq 0 ]]; then
        onelink=$(echo "$urlmatches" | sed -n 1p)
        # url was found
        tabid=$(get-tab-from-links-output "$onelink")
        echo >&2 "tabid: $tabid"
        chrome-cli activate -t ${tabid?no tab found}

        windowtitle=$(get-window-title-from-tabid $tabid)
        echo >&2 "windowtitle: $windowtitle"
        macos-try-to-raise-by-window-title "$BROWSER_APP" "$windowtitle" '' 
    else
        # url needs to be opened
        open -a "$BROWSER_APP" "$targetUrl"
        # open "$targetUrl"
    fi
}
get-window-title-from-tabid() {
    tabid=${1?need tabid}
    chrome-cli list tabs | egrep "(:$tabid\\]|\\[$tabid\\])" | sed "s/^\[[0-9]*:$tabid\] //" 
}
set-browser-config() {
    if notty; 
    then # do default
        export BROWSER_APP="Brave Browser" # todo -- config this with a dotfile
        export CHROME_BUNDLE_IDENTIFIER="com.brave.Browser" 
    else
        set-browser-config-interactively-if-needed
    fi
}
set-browser-config-interactively-if-needed() {
    # Add more as per this procedure:
    # https://github.com/prasmussen/chrome-cli
    browsertoken=$(cat "$CONFIG_FILE" 2> /dev/null)
    case "$browsertoken" in
        "")
            ask-and-set-browser
            die 'browser is set; please run again' $?
        ;;
        brave)
            export BROWSER_APP="Brave Browser"
            export CHROME_BUNDLE_IDENTIFIER="com.brave.Browser" 
        ;;
        chromium)
            export CHROME_BUNDLE_IDENTIFIER="org.chromium.Chromium"
            export BROWSER_APP="Chromium"
        ;;
        vivaldi)
            export CHROME_BUNDLE_IDENTIFIER="com.vivaldi.Vivaldi"
            export BROWSER_APP="Vivaldi"
        ;;
        chrome)
            export CHROME_BUNDLE_IDENTIFIER="com.google.Chrome"
            export BROWSER_APP="Google Chrome"
        ;;
        chrome-canary)
            export CHROME_BUNDLE_IDENTIFIER="com.google.Chrome.canary"
            export BROWSER_APP="TODO"
            die "please add the app name for this option to the script"
        ;;
        *)
            die "unknown browser: $browsertoken"
    esac
}
reset-config() {
    rm "$CONFIG_FILE"
}
ask-and-set-browser() {
    # obviously need to modify this, just an example
    chromiumEnum=(brave chrome chromium vivaldi chrome-canary);
    PS3='Select which chromium you use: ';
    select opt in "${chromiumEnum[@]}";
    do
        echo "$opt" > "$CONFIG_FILE"
        break
    done;
}
function notty() { ! [ -t 0 ]; }
get-tab-from-links-output() {
    # some escaping issues with sed's interp of "["
    # ... also, chrome-cli changes output format if more than one window
    echo "$1" | sed 's/^\[//' | sed 's/].*//' | cut -f2 -d:
}
get-tab-from-links-output-mothballed() {
    echo "$1" | substring-between-on-same-line : ] \
        ||
    echo "$1" | substring-between-on-same-line [ ]
}
substring-between-on-same-line ()
{
    if [ $# -ne 2 ]; then
        echo usage: 1>&2;
        echo "$ ${FUNCNAME[0]} <START> <END>" 1>&2;
        return 1;
    fi;
    local START="$1";
    local END="$2";
    sed -e 's/.*'"${START/[/\\[}"'\(.*\)'"${END}"'.*/\1/'
}

example-output-from-chrome-cli() {
    # That second part of the dash is the tab id
    cat <<'EOF'
[6:113] https://autotiv.monday.com/boards/904139066/views/18056854
EOF
}
main-linux() {

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

    # A little scriptlet utility written in swift!
    # https://stackoverflow.com/a/32842314

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
macos-try-to-raise-by-window-title() {
    appname="${1?need exact app name}"
    titlefragment="${2?need part of window title}"
    runspec="${3?need some shell code}"

    osascript <<EOF | grep "action AXRaise of window"
    tell application "System Events" to tell process "$appname"
        set frontmost to true
        windows where title contains "$titlefragment"
        if result is not {} then perform action "AXRaise" of item 1 of result
    end tell
EOF
    if [[ $? -ne 0 ]]; then
        echo EXEC: $runspec
        eval "$runspec"
    fi
}
function trim-empty-lines() { sed "/^\$/d"; }
try-to-raise-by-window-class() {
    # this is usually something like RDN, e.g. com.brave.Browser
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
test-chromium-debugger() {
    args=( 
        "Brave Browser"
        DevTools 
        'open -a "Brave Browser"; osascript -e "tell application \"System Events\" to keystroke \"i\" using {option down, command down}" ' 
    )
    # macos-try-to-raise-by-window-title "${args[@]}"
    main "${args[@]}"
}
test-iterm() {
    # Not sure what the behavior should be if no valid runspec is given... this
    # test should be mothballed until the right path is chosen.
    main iTerm2 tmux
}
test-raise-or-run-url() {
    # This will even work for if the window is minimized on macos, so you can
    # tuckaway those hard-to-load webapps.
    main --web https://autotiv.monday.com/boards/904139066

    # It should be considered if a second arg could be given to target the
    # "ideal" url instead of just an "acceptable" one.
    # e.g.
    # main --web \
    #   https://autotiv.monday.com/boards/904139066
    #   https://autotiv.monday.com/boards/904139066/views/18056854

    # ... they also may appear different because of redirects.
    # 1 == "appearsAs"
    # 2 == "visitedAs"
}
test-titled-iterm-instance() {
    # Setting title with an echo-escape-code API in iterm
    # https://apple.stackexchange.com/a/341128
    echo ERROR: NYI${FUNCNAME+ function}: ${FUNCNAME-$0}${FUNCNAME+()}
    exit 1
    # Use-cases:
    # - todo app
    # - vim-javascript-editor for chrome
    # - vim-browser-code instance
    main --term js-injector "echo stuff to type"
}
# If executed as a script, instead of sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # set -euo pipefail # disabled because $? is often used
    main "$@"
else
    echo "${BASH_SOURCE[0]}" sourced >&2
    shopt -s expand_aliases # reset from source-harnessing
fi

