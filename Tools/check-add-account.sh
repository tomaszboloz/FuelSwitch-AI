#!/bin/bash
# Checks that "Add account -> Claude" produces a window the user can actually
# see and type into.
#
# This app has no Dock icon (LSUIElement), so it never becomes the active
# application on its own. Twice now that has made the account window open
# correctly and stay invisible underneath whatever was in front. Unit tests
# cannot see window layering, so this drives the real app instead.
#
# Requires: a built app (make app), a GUI session, and Accessibility
# permission for the terminal running it.
#
# Set COVER to any app with windows over the middle of the screen.
set -u
cd "$(dirname "$0")/.."
APP=".build/FuelSwitch AI.app"
COVER="${COVER:-Google Chrome}"

[ -d "$APP" ] || { echo "Build it first: make app"; exit 2; }

pkill -f "FuelSwitch AI.app/Contents/MacOS/FuelSwitch" 2>/dev/null
sleep 1
open "$APP"
sleep 3

osascript >/dev/null 2>&1 <<APPLESCRIPT
tell application "$COVER" to activate
delay 1
tell application "System Events"
  tell process "FuelSwitch"
    click menu bar item 1 of menu bar 2
    delay 1
    click menu button "Add account" of group 1 of window 1
    delay 1
    click menu item "Claude" of menu 1 of menu button "Add account" of group 1 of window 1
  end tell
end tell
delay 2
APPLESCRIPT

RANK=$(swift Tools/window-order.swift | grep '^layer=0' | grep -n 'Add account' | cut -d: -f1)

TYPED=$(osascript 2>/dev/null <<'APPLESCRIPT'
tell application "System Events"
  tell process "FuelSwitch"
    set w to (first window whose title is "Add account")
    keystroke "proba"
    delay 1
    return (value of text field 1 of group 1 of w)
  end tell
end tell
APPLESCRIPT
)

echo "rank among normal windows : ${RANK:-<window absent>}"
echo "text typed into the field : [${TYPED}]"

# We deliberately do not assert that FuelSwitch AI is the "frontmost
# application". An LSUIElement app installs no menu bar, so macOS leaves the
# previous regular app in that role even while our window holds the keyboard.
FAIL=0
[ "${RANK:-99}" = "1" ] || { echo "FAIL: the window is not in front of other windows"; FAIL=1; }
[ "$TYPED" = "proba" ]  || { echo "FAIL: the window did not receive keystrokes"; FAIL=1; }
[ $FAIL -eq 0 ] && echo "PASS"
exit $FAIL
