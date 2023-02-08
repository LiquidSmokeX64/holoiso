#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="HoloISO_5.0_OfflineInstaller"
iso_label="HOLO_$(date +%Y%m)"
iso_publisher="Fahr <https://github.com/Project-X-Mods>"
iso_application="HoloISO Installer Image"
iso_version="$(date +%Y%m%d_%H%M)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/skel/Desktop/ime-kb.desktop"]="0:0:755"
  ["/etc/skel/Desktop/chroot.desktop"]="0:0:755"
  ["/etc/skel/Desktop/install.desktop"]="0:0:755"
)
