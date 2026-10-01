#!/bin/bash
# 50-verify.sh
#
# Read-only sanity checks that the port is actually live. Prints PASS/FAIL per
# check and a final summary. Run inside the niri session as your normal user.
#
#   ./50-verify.sh

set -uo pipefail

PORT_DIR="$HOME/omarchy-port"
PASS=0; FAIL=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

echo "== Host / session =="
check "Ubuntu 24.04"                 'grep -qi "24.04" /etc/os-release'
check "niri installed"               'command -v niri'
check "running inside a niri session" 'command -v niri && niri msg outputs'
check "WAYLAND_DISPLAY set"          '[[ -n ${WAYLAND_DISPLAY:-} ]]'

echo "== Shell runtime =="
check "quickshell installed"         'test -x /usr/local/bin/quickshell'
check "quickshell reports a version" 'quickshell --version'
check "Qt 6.8.3 present"             'test -x /opt/Qt/6.8.3/gcc_64/bin/qmake'
check "Qt lib path wired"            'grep -q "/opt/Qt/6.8.3/gcc_64/lib" /etc/ld.so.conf.d/qt6-8-3.conf'

echo "== Ported files =="
check "OMARCHY_PATH shell tree"      "test -f $PORT_DIR/shell/shell.qml"
check "shell.json"                   'test -f "$HOME/.config/omarchy/shell.json"'
check "niri config.kdl"              'test -f "$HOME/.config/niri/config.kdl"'
check "niri config validates"        'niri validate -c "$HOME/.config/niri/config.kdl"'

echo "== Helpers + drivers =="
for b in omarchy-shell omarchy-theme-set omarchy-hook omarchy-monitor-state \
         omarchy-network-status omarchy-osd omarchy-reminder; do
  check "helper $b" "test -x $HOME/.local/bin/$b"
done
check "xkbcli present"               'command -v xkbcli'
check "inotifywait present"          'command -v inotifywait'

echo "== Session units =="
check "omarchy-shell-niri.service active" 'systemctl --user is-active omarchy-shell-niri.service'
check "elephant.service active"           'systemctl --user is-active elephant.service'
EPID="$(systemctl --user show -p MainPID --value elephant.service 2>/dev/null)"
if [[ -n ${EPID:-} && $EPID != 0 ]]; then
  if tr '\0' '\n' < "/proc/$EPID/environ" 2>/dev/null | grep -q '^WAYLAND_DISPLAY='; then
    ok "elephant has live WAYLAND_DISPLAY"
  else
    bad "elephant missing WAYLAND_DISPLAY (Walker apps won't launch)"
  fi
else
  bad "elephant MainPID unknown"
fi

echo "== Bar surface =="
if command -v niri >/dev/null 2>&1 && niri msg layers 2>/dev/null | grep -qi 'omarchy'; then
  ok "niri reports omarchy layer surfaces"
else
  bad "no omarchy layer surfaces reported by niri"
fi

echo
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mALL %d CHECKS PASSED\033[0m\n' "$PASS"
else
  printf '\033[31m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
  exit 1
fi
