#!/bin/bash
# 10-install-qt-quickshell.sh
#
# The hard blocker of this whole port: quickshell (the shell runtime the
# Omarchy bar runs on) needs Qt 6.8+. Ubuntu 24.04 "noble" ships Qt 6.4/6.6,
# which is missing QML APIs the shell uses (e.g. `isTransient` on
# Notification, and the QtQuick/Wayland bits). The shell fails to parse or
# crashes on startup against Ubuntu's Qt.
#
# The working recipe (verified on the VM 2026-09-30) is:
#   1. Install the lengau/qt6-backports PPA for *build* dependencies only
#      (it provides qt6-base-private-dev etc. built for noble).
#   2. Fetch the OFFICIAL Qt 6.8.3 (linux_gcc_64) with aqtinstall into /opt/Qt.
#   3. Build quickshell v0.3.1 against /opt/Qt/6.8.3.
#   4. Install the binary to /usr/local/bin and wire the Qt lib/QML paths.
#
# Requires sudo (writes /opt/Qt, /usr/local/bin, /etc/ld.so.conf.d).
# Run as your normal user; the script sudos internally.
#
#   ./10-install-qt-quickshell.sh
#
# Idempotent-ish: skips Qt download if /opt/Qt/6.8.3/gcc_64 exists, skips the
# build if /usr/local/bin/quickshell already reports a version.

set -euo pipefail

QT_VERSION="6.8.3"
QT_DIR="/opt/Qt/${QT_VERSION}/gcc_64"
QS_VERSION="v0.3.1"
QS_SRC="/tmp/quickshell-src"
DEPLOY_DIR="$HOME/.local/share/omarchy-niri-ubuntu"
export DEBIAN_FRONTEND=noninteractive

log() { printf '\n==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

if [[ $EUID -eq 0 ]]; then
  echo "Run as your normal user; the script uses sudo where needed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Build dependencies (noble + lengau qt6-backports for the private Qt headers)
# ---------------------------------------------------------------------------
log "Installing build dependencies (apt)"
sudo apt-get update -qq
sudo apt-get install -y -qq software-properties-common curl git python3-pip \
  build-essential cmake ninja-build pkg-config \
  libdrm-dev libjemalloc-dev libpipewire-0.3-dev libxcb1-dev \
  libgl1-mesa-dev libegl1-mesa-dev libwayland-dev wayland-protocols \
  libcli11-dev libpolkit-agent-1-dev libpam0g-dev libglib2.0-dev \
  libpixman-1-dev libgbm-dev libxkbcommon-dev extra-cmake-modules

# lengau/qt6-backports provides qt6-base-private-dev built for noble (needed by
# quickshell's build; the stock noble Qt dev packages are too old).
if ! grep -rq "lengau/qt6-backports" /etc/apt/sources.list.d/ 2>/dev/null; then
  log "Adding the lengau/qt6-backports PPA (private Qt dev headers)"
  sudo add-apt-repository -y ppa:lengau/qt6-backports
  sudo apt-get update -qq
fi
sudo apt-get install -y -qq qt6-base-dev qt6-base-private-dev qt6-base-dev-tools \
  qt6-declarative-dev qt6-wayland-dev qt6-svg-dev qt6-shadertools-dev \
  qt6-declarative-dev-tools || true

# ---------------------------------------------------------------------------
# 2. Official Qt 6.8.3 via aqtinstall
# ---------------------------------------------------------------------------
if [[ -x "$QT_DIR/bin/qmake" ]]; then
  log "Qt $QT_VERSION already present at $QT_DIR - skipping download"
else
  log "Installing aqtinstall"
  pip3 install --break-system-packages -q aqtinstall

  log "Fetching official Qt $QT_VERSION (linux_gcc_64) into /opt/Qt"
  sudo mkdir -p /opt/Qt
  sudo chown "$USER" /opt/Qt
  # Core + the modules quickshell links against. (Note: qtdeclarative/qtsvg/
  # qtwayland are NOT valid aqt module names for 6.8.x - the correct module
  # set is below. Using the wrong names aborts the install.)
  python3 -m aqt install-qt linux desktop "$QT_VERSION" linux_gcc_64 \
    --outputdir /opt/Qt \
    -m qtdeclarative qtwayland qtsvg qtshadertools qt5compat qtimageformats \
    qtwaylandcompositor qtquick3d
fi

# ---------------------------------------------------------------------------
# 3. Build quickshell
# ---------------------------------------------------------------------------
if [[ -x /usr/local/bin/quickshell ]]; then
  log "quickshell already installed: $(/usr/local/bin/quickshell --version 2>&1 | head -1) - skipping build"
else
  log "Cloning quickshell $QS_VERSION"
  rm -rf "$QS_SRC"
  git clone --depth 1 --branch "$QS_VERSION" \
    https://github.com/quickshell-mirror/quickshell "$QS_SRC"

  log "Configuring quickshell against Qt $QT_VERSION"
  cd "$QS_SRC"
  cmake -GNinja -B build \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_PREFIX_PATH="$QT_DIR" \
    -DVENDOR_CPPTRACE=ON \
    -DDO_NOT_CHECK_CPPTRACE_USABILITY=ON \
    -DI3=OFF -DI3_IPC=OFF \
    -DINSTALL_QML_PREFIX=/usr/lib/x86_64-linux-gnu/qt6/qml \
    -DINSTALL_QMLDIR=/usr/lib/x86_64-linux-gnu/qt6/qml/org/quickshell \
    -DDISTRIBUTOR="Omarchy niri Ubuntu port"

  log "Building quickshell (this takes several minutes)"
  cmake --build build -j"$(nproc)"

  # Install the build-tree binary, NOT `cmake --install`: the build-tree copy
  # carries the correct RUNPATH to /opt/Qt/6.8.3/gcc_64/lib. `cmake --install`
  # strips it and the binary then fails to find Qt at runtime.
  log "Installing quickshell to /usr/local/bin"
  sudo install -m 0755 "$QS_SRC/build/src/quickshell" /usr/local/bin/quickshell
  sudo ln -sf /usr/local/bin/quickshell /usr/local/bin/qs
fi

# ---------------------------------------------------------------------------
# 4. Runtime wiring: Qt lib path + QML import paths for the session
# ---------------------------------------------------------------------------
log "Wiring Qt $QT_VERSION runtime paths"
echo "$QT_DIR/lib" | sudo tee /etc/ld.so.conf.d/qt6-8-3.conf >/dev/null
sudo ldconfig

sudo tee /etc/profile.d/qt6-8-3.sh >/dev/null <<EOF
# Added by omarchy-niri-ubuntu (port 10-install-qt-quickshell.sh)
export QT_PLUGIN_PATH=$QT_DIR/plugins
export QML2_IMPORT_PATH=$QT_DIR/qml:/usr/lib/x86_64-linux-gnu/qt6/qml
export QML_IMPORT_PATH=$QT_DIR/qml:/usr/lib/x86_64-linux-gnu/qt6/qml
EOF
sudo chmod 644 /etc/profile.d/qt6-8-3.sh

log "Versions"
/usr/local/bin/quickshell --version 2>&1 | head -1 || true
"$QT_DIR/bin/qmake" --version 2>&1 | head -1 || true

log "Done. Next: ./20-install-niri-session.sh"
