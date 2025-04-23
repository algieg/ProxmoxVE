#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tremor021 (modified by Mat)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/Suwayomi/Suwayomi-Server

APP="SuwayomiServer"
var_tags="${var_tags:-media;manga}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

# Ensure Java 21 is available (install from backports if needed)
install_java21() {
    msg_info "Checking for Java 21 (openjdk-21-jre-headless)"
    if ! dpkg -l | grep -q openjdk-21-jre-headless; then
        msg_info "Installing OpenJDK 21 from backports"
        # Enable backports if not already
        if ! grep -Rq "^deb .\+ bookworm-backports" /etc/apt/sources.list*; then
            echo "deb http://deb.debian.org/debian bookworm-backports main" >> /etc/apt/sources.list
        fi
        apt-get update
        apt-get install -y -t bookworm-backports openjdk-21-jre-headless || msg_error "Failed to install OpenJDK 21"
        msg_ok "Java 21 installed"
    else
        msg_ok "Java 21 already present"
    fi
}

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -f /usr/bin/suwayomi-server ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    RELEASE=$(curl -fsSL https://api.github.com/repos/Suwayomi/Suwayomi-Server/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
    if [[ "${RELEASE}" != "$(cat /opt/suwayomi-server_version.txt)" ]] || [[ ! -f /opt/suwayomi-server_version.txt ]]; then
        msg_info "Updating $APP"
        msg_info "Stopping $APP"
        systemctl stop suwayomi-server
        msg_ok "Stopped $APP"
        msg_info "Updating $APP to v${RELEASE}"
        cd /tmp
        URL=$(curl -fsSL https://api.github.com/repos/Suwayomi/Suwayomi-Server/releases/latest | grep "browser_download_url" | awk '{print substr($2, 2, length($2)-2) }' | tail -n+2 | head -n 1)
        curl -fsSL "$URL" -o $(basename "$URL")
        # Ensure Java dependency
        install_java21
        # Install the new package
        dpkg -i /tmp/*.deb || apt-get -f install -y && dpkg -i /tmp/*.deb
        msg_ok "Updated $APP to v${RELEASE}"
        msg_info "Starting $APP"
        systemctl start suwayomi-server
        msg_ok "Started $APP"
        msg_info "Cleaning Up"
        rm -f *.deb
        msg_ok "Cleanup Completed"
        echo "${RELEASE}" >/opt/suwayomi-server_version.txt
        msg_ok "Update Successful"
    else
        msg_ok "No update required. ${APP} is already at v${RELEASE}"
    fi
    exit
}

start
# Before building container, ensure Java available inside
install_java21
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:4567${CL}"
