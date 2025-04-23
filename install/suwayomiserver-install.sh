#!/usr/bin/env bash
# Suwayomi Server LXC build script (fixed by Mat)

# Fetch and source helper functions robustly
BUILD_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"
API_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func"

tmpdir=$(mktemp -d)
curl -fsSL "$API_FUNC_URL" -o "$tmpdir/api.func"
curl -fsSL "$BUILD_FUNC_URL" -o "$tmpdir/build.func"
source "$tmpdir/api.func"
source "$tmpdir/build.func"

APP="SuwayomiServer"
var_tags="${var_tags:-media;manga}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# Bail if helper functions didn't load
if ! declare -f color >/dev/null; then
  echo "Error: could not load build helper functions." >&2
  exit 1
fi

header_info "$APP"
variables
color
catch_errors

# Install required build dependencies on host (libc++-dev)
install_build_deps() {
  msg_info "Installing host build dependencies"
  apt-get update
  apt-get install -y libc++-dev || msg_error "Failed to install libc++-dev"
  msg_ok "Host dependencies installed"
}

# Download & patch Suwayomi .deb to depend on Java 17 instead of Java 21
patch_and_install_suwayomi() {
  local url="$1"
  local deb=$(basename "$url")
  msg_info "Downloading $deb"
  curl -fsSL "$url" -o "$deb" || msg_error "Failed to download $deb"

  msg_info "Repacking .deb to adjust dependencies"
  mkdir -p repack/{DEBIAN,control}
  dpkg-deb -R "$deb" repack
  # Change dependency openjdk-21-jre to openjdk-17-jre-headless
  sed -i 's/openjdk-21-jre[^,]*/openjdk-17-jre-headless/' repack/DEBIAN/control
  dpkg-deb -b repack patched.deb
  msg_ok "Repacked patched.deb"

  # Install
  dpkg -i patched.deb || apt-get -f install -y && dpkg -i patched.deb
  msg_ok "suwayomi-server installed"
}

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /usr/bin/suwayomi-server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/Suwayomi/Suwayomi-Server/releases/latest \
    | grep "tag_name" \
    | awk '{print substr($2, 2, length($2)-3)}')
  if [[ "${RELEASE}" != "$(cat /opt/suwayomi-server_version.txt 2>/dev/null)" ]]; then
    msg_info "Updating $APP to v${RELEASE}"
    systemctl stop suwayomi-server
    msg_ok "Stopped $APP"
    cd /tmp
    URL=$(curl -fsSL https://api.github.com/repos/Suwayomi/Suwayomi-Server/releases/latest \
      | grep "browser_download_url" \
      | awk '{print substr($2, 2, length($2)-2)}' \
      | tail -n1)

    install_build_deps
    patch_and_install_suwayomi "$URL"

    systemctl start suwayomi-server
    msg_ok "Started $APP"
    rm -rf repack patched.deb "$deb"
    echo "${RELEASE}" >/opt/suwayomi-server_version.txt
    msg_ok "Update successful"
  else
    msg_ok "No update required. Already at v${RELEASE}"
  fi
  exit
}

start
install_build_deps
update_script

# Build container only after script update path runs
build_container
description
msg_ok "Completed Suwayomi LXC build."
