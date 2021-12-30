
osascript <<EOF
tell application "System Events" to tell process "iTerm2"
    set frontmost to true
    windows where title contains "tmux"
    if result is not {} then perform action "AXRaise" of item 1 of result
end tell
EOF

osascript -e 'tell application "System Events" to tell process "iTerm2"' \
           -e 'set frontmost to true' \
           -e 'if windows is not {} then perform action "AXRaise" of item 1 of windows' \
           -e 'end tell'

           tell application "Terminal"
               activate
               windows where name contains "bash"
               if result is not {} then set index of item 1 of result to 1
           end tell
