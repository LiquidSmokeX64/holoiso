#!/bin/zsh
# HoloISO Installer v2
# This defines all of the current variables.
HOLO_INSTALL_DIR="${HOLO_INSTALL_DIR:-/mnt}"
IS_WIN600=$(cat /sys/devices/virtual/dmi/id/product_name | grep Win600)
IS_STEAMDECK=$(cat /sys/devices/virtual/dmi/id/product_name | grep Jupiter)

if [ -n "${IS_WIN600}" ]; then
	GAMEPAD_DRV="1"
fi

if [ -n "${IS_STEAMDECK}" ]; then
	FIRMWARE_INSTALL="1"
fi

check_mount(){
	if [ $1 != 0 ]; then
		echo "\nError: Something went wrong when mounting $2 partitions. Please try again!\n"
		echo 'Press any key to exit...'; read -k1 -s
		exit 1
	fi
}

check_download(){
	if [ $1 != 0 ]; then
		echo "\nError: Something went wrong when $2.\nPlease make sure you have a stable internet connection!\n"
		echo 'Press any key to exit...'; read -k1 -s
		exit 1
	fi
}

partitioning(){
	echo "Select your drive in popup:"

	DRIVEDEVICE=$(lsblk -d -o NAME | sed "1d" | awk '{ printf "FALSE""\0"$0"\0" }' | \
xargs -0 zenity --list --width=600 --height=512 --title="Select disk" --text="Select your disk to install HoloISO in below:\n\n $(lsblk -d -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,VENDOR,MODEL,SERIAL,MOUNTPOINT)" \
--radiolist --multiple --column ' ' --column 'Disks')
	
	DEVICE="/dev/${DRIVEDEVICE}"
	
	INSTALLDEVICE="${DEVICE}"

	if [ ! -b $DEVICE ]; then
		echo "$DEVICE not found! Installation Aborted!"
		exit 1
	fi
	lsblk $DEVICE | head -n2 | tail -n1 | grep disk > /dev/null 2>&1
	if [ $? != 0 ]; then
		echo "$DEVICE is not disk type! Installation Aborted!"
		echo "\nNote: If you wish to preform partition install.\nPlease specify the disk drive node first then select \"2\" for partition install."
		exit 1
	fi
	echo "\nChoose your partitioning type:"
	install=$(zenity --list --title="Choose your installation type:" --column="Type" --column="Name" 1 "Erase entire drive" \2 "Install alongside existing OS/Partition (Requires at least 50 GB of free space from the end)"  --width=700 --height=220)
	if [[ -n "$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" ]]; then
		HOME_REUSE_TYPE=$(zenity --list --title="Warning" --text="A HoloISO home partition was detected at $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1). Please select an appropriate action below:" --column="Type" --column="Name" 1 "Format it and start over" \2 "Reuse partition"  --width=500 --height=220)
		mkdir -p /tmp/home
		mount $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1) /tmp/home
			if [[ -d "/tmp/home/.steamos" ]]; then
				echo "Migration data found. Proceeding"
				umount -l $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)
			else
					(
					sleep 2
					echo "10"
					mkdir -p /tmp/rootpart
					mount $(sudo blkid | grep holo-root | cut -d ':' -f 1 | head -n 1) /tmp/rootpart
					mkdir -p /tmp/home/.steamos/ /tmp/home/.steamos/offload/opt /tmp/home/.steamos/offload/root /tmp/home/.steamos/offload/srv /tmp/home/.steamos/offload/usr/lib/debug /tmp/home/.steamos/offload/usr/local /tmp/home/.steamos/offload/var/lib/flatpak /tmp/home/.steamos/offload/var/cache/pacman /tmp/home/.steamos/offload/var/lib/docker /tmp/home/.steamos/offload/var/lib/systemd/coredump /tmp/home/.steamos/offload/var/log /tmp/home/.steamos/offload/var/tmp
					echo "15" ; sleep 1
					mv /tmp/rootpart/opt/* /tmp/home/.steamos/offload/opt
					mv /tmp/rootpart/root/* /tmp/home/.steamos/offload/root
					mv /tmp/rootpart/srv/* /tmp/home/.steamos/offload/srv
					mv /tmp/rootpart/usr/lib/debug/* /tmp/home/.steamos/offload/usr/lib/debug
					mv /tmp/rootpart/usr/local/* /tmp/home/.steamos/offload/usr/local
					mv /tmp/rootpart/var/cache/pacman/* /tmp/home/.steamos/offload/var/cache/pacman
					mv /tmp/rootpart/var/lib/docker/* /tmp/home/.steamos/offload/var/lib/docker
					mv /tmp/rootpart/var/lib/systemd/coredump/* /tmp/home/.steamos/offload/var/lib/systemd/coredump
					mv /tmp/rootpart/var/log/* /tmp/home/.steamos/offload/var/log
					mv /tmp/rootpart/var/tmp/* /tmp/home/.steamos/offload/var/tmp
					echo "System directory moving complete. Preparing to move flatpak content."
					echo "30" ; sleep 1
					echo "Starting flatpak data migration.\nThis may take 2 to 10 minutes to complete."
					rsync -axHAWXS --numeric-ids --info=progress2 --no-inc-recursive /tmp/rootpart/var/lib/flatpak /tmp/home/.steamos/offload/var/lib/ |    tr '\r' '\n' |    awk '/^ / { print int(+$2) ; next } $0 { print "# " $0 }'
					echo "Finished."
					) |
					zenity --progress --title="Preparing to reuse home at $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" --text="Starting to move following directories to target offload:\n\n- /opt\n- /root\n- /srv\n- /usr/lib/debug\n- /usr/local\n- /var/cache/pacman\n- /var/lib/docker\n- /var/lib/systemd/coredump\n- /var/log\n- /var/tmp\n" --width=500 --no-cancel --percentage=0 --auto-close
					umount -l $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)
					umount -l $(sudo blkid | grep holo-root | cut -d ':' -f 1 | head -n 1)
				fi
	fi
	# Setup password for root
	while true; do
		ROOTPASS=$(zenity --forms --title="Account configuration" --text="Set root/system administrator password" --add-password="Password for user root")
		if [ -z $ROOTPASS ]; then
			zenity --warning --text "No password was set for user \"root\"!" --width=300
			break
		fi
		echo
		ROOTPASS_CONF=$(zenity --forms --title="Account configuration" --text="Confirm your root password" --add-password="Password for user root")
		echo
		if [ $ROOTPASS = $ROOTPASS_CONF ]; then
			break
		fi
		zenity --warning --text "Passwords not match." --width=300
	done
	# Create user
	NAME_REGEX="^[a-z][-a-z0-9_]*\$"
	while true; do
		HOLOUSER=$(zenity --entry --title="Account creation" --text "Enter username for this installation:")
		if [ $HOLOUSER = "root" ]; then
			zenity --warning --text "User root already exists." --width=300
		elif [ -z $HOLOUSER ]; then
			zenity --warning --text "Please create a user!" --width=300
		elif [ ${#HOLOUSER} -gt 32 ]; then
			zenity --warning --text "Username length must not exceed 32 characters!" --width=400
		elif [[ ! $HOLOUSER =~ $NAME_REGEX ]]; then
			zenity --warning --text "Invalid username \"$HOLOUSER\"\nUsername needs to follow these rules:\n\n- Must start with a lowercase letter.\n- May only contain lowercase letters, digits, hyphens, and underscores." --width=500
		else
			break
		fi
	done
	# Setup password for user
	while true; do
		HOLOPASS=$(zenity --forms --title="Account configuration" --text="Set password for $HOLOUSER" --add-password="Password for user $HOLOUSER")
		echo
		HOLOPASS_CONF=$(zenity --forms --title="Account configuration" --text="Confirm password for $HOLOUSER" --add-password="Password for user $HOLOUSER")
		echo
		if [ -z $HOLOPASS ]; then
			zenity --warning --text "Please type password for user \"$HOLOUSER\"!" --width=300
			HOLOPASS_CONF=unmatched
		fi
		if [ $HOLOPASS = $HOLOPASS_CONF ]; then
			break
		fi
		zenity --warning --text "Passwords do not match." --width=300
	done
	case $install in
		1)
			destructive=true
			# Umount twice to fully umount the broken install of steam os 3 before installing.
			umount $INSTALLDEVICE* > /dev/null 2>&1
			umount $INSTALLDEVICE* > /dev/null 2>&1
			$INST_MSG1
			if zenity --question --text "WARNING: The following drive is going to be fully erased. ALL DATA ON DRIVE ${DEVICE} WILL BE LOST! \n\n$(lsblk -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,VENDOR,MODEL,SERIAL,MOUNTPOINT ${DEVICE} | sed "1d")\n\nErase ${DEVICE} and begin installation?" --width=700
			then
				echo "\nWiping partitions..."
				sfdisk --delete ${DEVICE}
				wipefs -a ${DEVICE}
				echo "\nCreating new gpt partitions..."
				parted ${DEVICE} mklabel gpt
			else
				echo "\nNothing has been written.\nYou canceled the destructive install, please try again"
				echo 'Press any key to exit...'; read -k1 -s
				exit 1
			fi
			;;
		2)
			echo "\nHoloISO will be installed alongside existing OS/Partition.\nPlease make sure there are more than 24 GB on the >>END<< of free(unallocate) space available\n"
			parted $DEVICE print free
			echo "HoloISO will be installed on the following free (unallocated) space.\n"
			parted $DEVICE print free | tail -n2 | grep "Free Space"
			if [ $? != 0 ]; then
				echo "Error! No Free Space found on the end of the disk.\nNothing has been written.\nYou canceled the non-destructive install, please try again"
				exit 1
				echo 'Press any key to exit...'; read -k1 -s
			fi
				$INST_MSG1
			if zenity --question --text "HoloISO will be installed on the following free (unallocated) space.\nDoes this look reasonable?\n$(sudo parted ${DEVICE} print free | tail -n2 | grep "Free Space")" --width=500
			then
        		echo "\nBeginning installation..."
			else
				echo "\nNothing has been written.\nYou canceled the non-destructive install, please try again"
				echo 'Press any key to exit...'; read -k1 -s
				exit 1
        		fi
			;;
		esac

	numPartitions=$(grep -c ${DRIVEDEVICE}'[0-9]' /proc/partitions)
	
	echo ${DEVICE} | grep -q -P "^/dev/(nvme|loop|mmcblk)"
	if [ $? -eq 0 ]; then
		INSTALLDEVICE="${DEVICE}p"
		numPartitions=$(grep -c ${DRIVEDEVICE}p /proc/partitions)
	fi

	efiPartNum=$(expr $numPartitions + 1)
	rootPartNum=$(expr $numPartitions + 2)
	homePartNum=$(expr $numPartitions + 3)

	echo "\nCalculating start and end of free space..."
	diskSpace=$(awk '/'${DRIVEDEVICE}'/ {print $3; exit}' /proc/partitions)
	# <= 60GB: typical flash drive
	if [ $diskSpace -lt 60000000 ]; then
		digitMB=8
		realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 16-20)
	# <= 500GB: typical 512GB hard drive
	elif [ $diskSpace -lt 500000000 ]; then
		digitMB=8
		realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 20-25)
	# anything else: typical 1024GB hard drive
	else
		digitMB=9
		realDiskSpace=$(parted ${DEVICE} unit MB print free|head -n2|tail -n1|cut -c 20-26)
	fi

	if [ $destructive ]; then
		efiStart=2
	else
		efiStart=$(parted ${DEVICE} unit MB print free|tail -n2|sed s/'        '//|cut -c1-$digitMB|sed s/MB//|sed s/' '//g)
	fi
	efiEnd=$(expr $efiStart + 256)
	rootStart=$efiEnd
	rootEnd=$(expr $rootStart + 24000)

	if [ $efiEnd -gt $realDiskSpace ]; then
		echo "Not enough space available, please choose another disk and try again"
		exit 1
		echo 'Press any key to exit...'; read -k1 -s
	fi

	echo "\nCreating partitions..."
	parted ${DEVICE} mkpart primary fat32 ${efiStart}M ${efiEnd}M
	parted ${DEVICE} set ${efiPartNum} boot on
	parted ${DEVICE} set ${efiPartNum} esp on
	# If the available storage is less than 64GB, don't create /home.
	# If the boot device is mmcblk0, don't create an ext4 partition or it will break steamOS versions
	# released after May 20.
	if [ $diskSpace -lt 64000000 ] || [[ "${DEVICE}" =~ mmcblk0 ]]; then
		parted ${DEVICE} mkpart primary btrfs ${rootStart}M 100%
	else
		parted ${DEVICE} mkpart primary btrfs ${rootStart}M ${rootEnd}M
		parted ${DEVICE} mkpart primary ext4 ${rootEnd}M 100%
		home=true
	fi
	root_partition="${INSTALLDEVICE}${rootPartNum}"
	mkfs -t vfat ${INSTALLDEVICE}${efiPartNum}
	efi_partition="${INSTALLDEVICE}${efiPartNum}"
	fatlabel ${INSTALLDEVICE}${efiPartNum} HOLOEFI
	mkfs -t btrfs -f ${root_partition}
	btrfs filesystem label ${root_partition} holo-root
	if [ $home ]; then
		if [[ -n "$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)" ]]; then
				if [[ "${HOME_REUSE_TYPE}" == "1" ]]; then
					mkfs -t ext4 -F -O casefold ${INSTALLDEVICE}${homePartNum}
					home_partition="${INSTALLDEVICE}${homePartNum}"
					e2label "${INSTALLDEVICE}${homePartNum}" holo-home
				elif [[ "${HOME_REUSE_TYPE}" == "2" ]]; then
					echo "Home partition will be reused at $(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)"
                    home_partition="$(sudo blkid | grep holo-home | cut -d ':' -f 1 | head -n 1)"
				fi
		else
			mkfs -t ext4 -F -O casefold ${INSTALLDEVICE}${homePartNum}
			home_partition="${INSTALLDEVICE}${homePartNum}"
			e2label "${INSTALLDEVICE}${homePartNum}" holo-home
		fi
	fi
	echo "\nPartitioning complete, mounting and installing."
}

base_os_install() {
	sleep 1
	clear
	partitioning
	echo "${UCODE_INSTALL_MSG}"
	sleep 1
	clear
	mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime ${root_partition} ${HOLO_INSTALL_DIR} 
	check_mount $? root
	${CMD_MOUNT_BOOT}
	check_mount $? boot
	if [ $home ]; then
        mkdir -p ${HOLO_INSTALL_DIR}/home
		mount -t ext4 ${home_partition} ${HOLO_INSTALL_DIR}/home
		check_mount $? home
	fi
    rsync -axHAWXS --numeric-ids --info=progress2 --no-inc-recursive / ${HOLO_INSTALL_DIR} |    tr '\r' '\n' |    awk '/^ / { print int(+$2) ; next } $0 { print "# " $0 }' | zenity --progress --title="Installing base OS..." --text="Bootstrapping root filesystem...\nThis may take more than 10 minutes.\n" --width=500 --no-cancel --auto-close
	arch-chroot ${HOLO_INSTALL_DIR} install -Dm644 "$(find /usr/lib | grep vmlinuz | grep neptune)" "/boot/vmlinuz-$(cat /usr/lib/modules/*neptune*/pkgbase)"
	cp -r /etc/holoinstall/post_install/pacman.conf ${HOLO_INSTALL_DIR}/etc/pacman.conf
	arch-chroot ${HOLO_INSTALL_DIR} pacman-key --init
    arch-chroot ${HOLO_INSTALL_DIR} pacman -Rdd --noconfirm mkinitcpio-archiso
	arch-chroot ${HOLO_INSTALL_DIR} mkinitcpio -P
    arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs | grep pkg.tar.zst)
    arch-chroot ${HOLO_INSTALL_DIR} pacman --overwrite="*" --noconfirm -S amd-ucode system-config-printer apparmor archinstall mlocate arch-install-scripts b43-fwcutter base base-devel bind brltty broadcom-wl btrfs-progs clonezilla cloud-init cryptsetup darkhttpd ddrescue dhclient dhcpcd diffutils dmidecode dmraid dnsmasq dosfstools e2fsprogs edk2-shell efibootmgr efitools exfatprogs f2fs-tools fatresize fsarchiver gpm gptfdisk grml-zsh-config grub hdparm hyperv intel-ucode iwd jfsutils kitty-terminfo libfido2 libusb-compat linux-atm linux-firmware linux-firmware-marvell man-db man-pages mkinitcpio mkinitcpio-archiso mkinitcpio-nfs-utils modemmanager mokutil mtools nano net-tools networkmanager nfs-utils nmap ntfs-3g nvme-cli openconnect open-iscsi openssh open-vm-tools openvpn partclone pcsclite ppp pptpclient qemu-guest-agent refind reflector reiserfsprogs rp-pppoe rsync rxvt-unicode-terminfo sbctl sbsigntools screen sdparm sg3_utils smartmontools sof-firmware squashfs-tools sudo systemd-resolvconf tcpdump terminus-font testdisk texinfo tmux tpm2-tss udftools usb_modeswitch usbmuxd usbutils vim vpnc wireless-regdb wireless_tools wpa_supplicant xfsprogs xl2tpd zsh
	arch-chroot ${HOLO_INSTALL_DIR} pacman --overwrite="*" --noconfirm -S sddm-kcm boost-libs gtk-update-icon-cache hwinfo kconfig kcoreaddons ki18n kiconthemes kio kpmcore libpwquality polkit-qt5 qt5-svg qt5-xmlpatterns solid squashfs-tools yaml-cpp boost git qt5-tools qt5-translations python-pyqt5 polkit libsecret gtk3 wireplumber pipewire-pulse pipewire pipewire-alsa pipewire-jack appstream-qt kde-applications-meta kdevelop-python kgamma5 knewstuff kscreen kuserfeedback kvantum plasma-framework plasma-meta plasma-wayland-protocols plasma-wayland-session ark colord-kde gnome-color-manager gnome-keyring gnome-menus gtk4 xdg-desktop-portal-kde arc-gtk-theme dmenu adapta-gtk-theme arc-icon-theme thunderbird egl-wayland pavucontrol-qt ruby perl lua firefox rhythmbox alsa-lib alsa-plugins amd-ucode archiso archivetools aria2 base-devel bash-completion bash-language-server blueman bluez-libs cabextract chrony clang cmake colord cronie cups dbus dbus-python dconf directx-headers dkms efibootmgr elfutils exfatprogs expat extra-cmake-modules firewalld flatpak gettext giflib gimp git glib2 glibc glslang gnu-free-fonts gnutls go gst-libav gst-plugin-pipewire gst-plugins-bad gst-plugins-base gst-plugins-base-libs gst-plugins-good gst-plugins-ugly gstreamer gtk-engine-murrine hicolor-icon-theme innoextract jdk-openjdk jre-openjdk jre-openjdk-headless kcmutils lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-gst-plugins-base-libs lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libva lib32-libva-mesa-driver lib32-libxcomposite lib32-libxinerama lib32-libxslt lib32-mesa-vdpau lib32-mpg123 lib32-ncurses lib32-openal lib32-opencl-icd-loader lib32-opencl-mesa lib32-pipewire lib32-pipewire-jack lib32-v4l-utils lib32-vkd3d lib32-vulkan-icd-loader lib32-vulkan-mesa-layers lib32-vulkan-radeon lib32-vulkan-radeon libclc libdrm libelf libglvnd libjpeg-turbo libldap libnotify libomxil-bellagio libpng libpulse libreoffice-fresh libunwind libva libva-mesa-driver libva-utils libva-vdpau-driver libvdpau libx11 libxcomposite libxdamage libxinerama libxml2 libxrandr libxshmfence libxslt libxxf86vm linux-headers llvm llvm-libs lm_sensors lutris make mesa mesa-utils mesa-vdpau meson mkinitcpio mpg123 mtools nano ncurses neofetch nftables nm-connection-editor noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra ntfsprogs ntp nullmailer openal opencl-icd-loader opencl-mesa opengl-man-pages openjdk-doc openjdk-src power-profiles-daemon python-gobject python-mako python-pyqt6 qt6 qt5 qt6-imageformats qt6-multimedia-ffmpeg qt6-wayland shellcheck shotwell sudo systemd terminus-font tesseract-data-eng ttf-liberation udev ufw unrar unzip v4l-utils valgrind virtualbox virtualbox-guest-utils virtualbox-host-modules-arch vkd3d vulkan-icd-loader vulkan-mesa-layers vulkan-radeon w3m wine wine-gecko wine-mono winetricks wireplumber xdg-utils xf86-video-amdgpu xorg xorg-apps xorgproto xorg-server xreader yay zenity zstd xfconf vlc

	cp /opt/config ${HOLO_INSTALL_DIR}/etc/sway/
	java1="$(arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" archlinux-java get 2>/dev/null)"
	if [[ -z "$java1" ]] ; then
		echo "I'm broken :("
	fi
	arch-chroot ${HOLO_INSTALL_DIR} archlinux-java set "$java1"
	printf "%b2\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y vmware-workstation
	printf "%b1\n[Unit]\nDescription=VMware daemon\nRequires=vmware-usbarbitrator.service\nBefore=vmware-usbarbitrator.service\nAfter=network.target\n[Service]\nExecStart=/etc/init.d/vmware start\nExecStop=/etc/init.d/vmware stop\nPIDFile=/var/lock/subsys/vmware\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n" "$*" >> ${HOLO_INSTALL_DIR}/etc/systemd/system/vmware.service

	printf "%b1\n[Unit]\nDescription=VMware USB Arbitrator\nRequires=vmware.service\n[Service]\nExecStart=/usr/bin/vmware-usbarbitrator\nExecStop=/usr/bin/vmware-usbarbitrator --kill\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n" "$*" >> ${HOLO_INSTALL_DIR}/etc/systemd/system/vmware-usbarbitrator.service

	printf "%b\n[Unit]\nDescription=VMware Networks\nWants=vmware-networks-configuration.service\nAfter=vmware-networks-configuration.service\n[Service]\nType=forking\nExecStartPre=-/sbin/modprobe vmnet\nExecStart=/usr/bin/vmware-networks --start\nExecStop=/usr/bin/vmware-networks --stop\n[Install]\nWantedBy=multi-user.target\n" "$*" >> ${HOLO_INSTALL_DIR}/etc/systemd/system/vmware-networks-server.service

	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable vmware-networks-server.service
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable vmware-usbarbitrator.service
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable vmware.service
	printf "%b3\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y snapd
	printf "%b2\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y snapd-glib
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable snapd.apparmor
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable snapd
	while [ "$gpucheck" != "1" ] && [ "$gpucheck" != "2" ] && [ "$gpucheck" != "3" ]; do
	printf "%b\nDo you have an amd or nvidia graphics card? -- Intel ARC not yet supported.\n" "$*"
	printf "%b\n1 - AMD\n" "$*"
	printf "%b\n2 - Nvidia\n" "$*"
	printf "%b\n3 - Virtual GPU (VMware etc.)\n" "$*"

	read -r gpucheck
	case $gpucheck in
	1) printf "%b\nPerfect\n" "$*" ;;
	2) printf "%b\nA good choice.\n" "$*" ;;
	3) printf "%b\nA good choice.\n" "$*" ;;
	*) printf "%b\nUnrecognized option, please try again: $HOLOUSER\n" "$*" ;;
	esac
	done
	if [ "$gpucheck" = "1" ]; then
	gpu0="amd"
	elif [ "$gpucheck" = "2" ]; then
	gpu0="nvidia"
	elif [ "$gpucheck" = "3" ]; then
	gpu0="vm"
	fi

	if [ $gpu0 = "nvidia" ]; then
	printf "%b\nNvidia selected.\nInstalling GPU Drivers first.\n" "$*"
	arch-chroot ${HOLO_INSTALL_DIR} pacman -Sy --noconfirm nvidia-open opencl-nvidia nvidia-utils nvidia-settings
	#printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean n  --answerdiff n --answeredit y --answerupgrade y sway-nvidia
	#printf "%b\noptions root=LABEL=$drivename0 rw nvidia-drm.modeset=1 lsm=landlock,lockdown,yama,integrity,apparmor,bpf\n" "$*" >> /mnt/boot/loader/entries/arch.conf
	elif [ $gpu0 = "amd" ]; then
	printf "%b\nAMD selected.\nInstalling amdgpu-fan and corectrl" "$*"
	#printf "%b\noptions root=LABEL=$drivename0 rw lsm=landlock,lockdown,yama,integrity,apparmor,bpf\n" "$*" >> /mnt/boot/loader/entries/arch.conf
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y amdgpu-fan
	arch-chroot ${HOLO_INSTALL_DIR} pacman -Sy --noconfirm corectrl
	printf "%b3\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y pamac-aur
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y ast-firmware
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y ckbcomp
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y mkinitcpio-openswap
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y mkinitcpio-firmware
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y text-engine-git
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y protontricks
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y game-devices-udev
	#printf "%b2 7\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y mangohud
	#printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y gamescope
	printf "%b2\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y dxvk-bin
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y ntfix
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y heroic-games-launcher
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y systemd-kcm
	#printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean n  --answerdiff n --answeredit y --answerupgrade y swaysettings-git
	printf "%b2\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean n  --answerdiff n --answeredit y --answerupgrade y github-desktop
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable apparmor
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable systemd-boot-update.service
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable dhcpcd
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable cronie
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable chronyd
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable NetworkManager
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable firewalld
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable cups
	arch-chroot ${HOLO_INSTALL_DIR} systemctl enable sddm
	arch-chroot ${HOLO_INSTALL_DIR} systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service
	arch-chroot ${HOLO_INSTALL_DIR} pacman -Sy --noconfirm xdg-user-dirs
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y xdg-environment
	printf "%b1\n" "$*" | arch-chroot ${HOLO_INSTALL_DIR} sudo -Su "$HOLOUSER" yay --noconfirm --nodiffmenu --noremovemake --answerclean a  --answerdiff n --answeredit y --answerupgrade y xdg-autostart
	mkdir -p ${HOLO_INSTALL_DIR}/usr/share/wallpapers/coffee/
	#mkdir -p /mnt/usr/share/backgrounds/gnome/
	cp /opt/backgrounds/coffee/* ${HOLO_INSTALL_DIR}/usr/share/wallpapers/coffee/
	#cp /opt/backgrounds/coffee/* /mnt/usr/share/backgrounds/gnome/
	#cp /opt/os-release ${HOLO_INSTALL_DIR}/etc/
	#cp /opt/lsb-release ${HOLO_INSTALL_DIR}/etc/
	cp -r /opt/* ${HOLO_INSTALL_DIR}/opt/
	#cp /opt/sway.desktop ${HOLO_INSTALL_DIR}/usr/share/wayland-sessions/
	cp /usr/local/bin/coffeebrewer ${HOLO_INSTALL_DIR}/usr/local/bin/
	arch-chroot ${HOLO_INSTALL_DIR} chmod 755 /usr/local/bin/coffeebrewer
	#arch-chroot ${HOLO_INSTALL_DIR} chmod 755 /usr/share/wayland-sessions/sway.desktop
	arch-chroot ${HOLO_INSTALL_DIR} userdel -r liveuser
	check_download $? "installing base package"
	sleep 2
	clear
	
	sleep 1
	clear
	echo "\nBase system installation done, generating fstab..."
	genfstab -U -p /mnt >> /mnt/etc/fstab
	sleep 1
	clear

    echo "Configuring first boot user accounts..."
	rm ${HOLO_INSTALL_DIR}/etc/skel/Desktop/*
    arch-chroot ${HOLO_INSTALL_DIR} rm /etc/sddm.conf.d/* 
	mv /etc/holoinstall/post_install_shortcuts/steam.desktop /etc/holoinstall/post_install_shortcuts/desktopshortcuts.desktop ${HOLO_INSTALL_DIR}/etc/xdg/autostart
    mv /etc/holoinstall/post_install_shortcuts/steamos-gamemode.desktop ${HOLO_INSTALL_DIR}/etc/skel/Desktop	
	echo "\nCreating user ${HOLOUSER}..."
	echo -e "${ROOTPASS}\n${ROOTPASS}" | arch-chroot ${HOLO_INSTALL_DIR} passwd root
	arch-chroot ${HOLO_INSTALL_DIR} useradd --create-home ${HOLOUSER}
	echo -e "${HOLOPASS}\n${HOLOPASS}" | arch-chroot ${HOLO_INSTALL_DIR} passwd ${HOLOUSER}
	echo "${HOLOUSER} ALL=(root) NOPASSWD:ALL" > ${HOLO_INSTALL_DIR}/etc/sudoers.d/${HOLOUSER}
	chmod 0440 ${HOLO_INSTALL_DIR}/etc/sudoers.d/${HOLOUSER}
	echo "127.0.1.1    ${HOLOHOSTNAME}" >> ${HOLO_INSTALL_DIR}/etc/hosts
	sleep 1
	clear

	echo "\nInstalling bootloader..."
	mkdir -p ${HOLO_INSTALL_DIR}/boot/efi
	mount -t vfat ${efi_partition} ${HOLO_INSTALL_DIR}/boot/efi
	arch-chroot ${HOLO_INSTALL_DIR} holoiso-grub-update
	sleep 1
	clear
}
full_install() {
	if [[ "${GAMEPAD_DRV}" == "1" ]]; then
		echo "You're running this on Anbernic Win600. A suitable gamepad driver will be installed."
		arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs_addon | grep win600-xpad-dkms)
	fi
	if [[ "${FIRMWARE_INSTALL}" == "1" ]]; then
		echo "You're running this on a Steam Deck. linux-firmware-neptune will be installed to ensure maximum kernel-side compatibility."
		arch-chroot ${HOLO_INSTALL_DIR} pacman -Rdd --noconfirm linux-firmware
		arch-chroot ${HOLO_INSTALL_DIR} pacman -U --noconfirm $(find /etc/holoinstall/post_install/pkgs_addon | grep linux-firmware-neptune)
		arch-chroot ${HOLO_INSTALL_DIR} mkinitcpio -P
	fi
	echo "\nConfiguring Steam Deck UI by default..."		
    ln -s /usr/share/applications/steam.desktop ${HOLO_INSTALL_DIR}/etc/skel/Desktop/steam.desktop
	echo -e "[General]\nDisplayServer=wayland\n\n[Autologin]\nUser=${HOLOUSER}\nSession=gamescope-wayland.desktop\nRelogin=true\n\n[X11]\n# Janky workaround for wayland sessions not stopping in sddm, kills\n# all active sddm-helper sessions on teardown\nDisplayStopCommand=/usr/bin/gamescope-wayland-teardown-workaround" >> ${HOLO_INSTALL_DIR}/etc/sddm.conf.d/autologin.conf
	arch-chroot ${HOLO_INSTALL_DIR} usermod -a -G rfkill ${HOLOUSER}
	arch-chroot ${HOLO_INSTALL_DIR} usermod -a -G wheel ${HOLOUSER}
	echo "Preparing Steam OOBE..."
	arch-chroot ${HOLO_INSTALL_DIR} touch /etc/holoiso-oobe
	echo "Cleaning up..."
	cp /etc/skel/.bashrc ${HOLO_INSTALL_DIR}/home/${HOLOUSER}
    arch-chroot ${HOLO_INSTALL_DIR} rm -rf /etc/holoinstall
	sleep 1
	clear
}


# The installer itself. Good wuck.
echo "SteamOS 3 Installer"
echo "Start time: $(date)"
echo "Please choose installation type:"
HOLO_INSTALL_TYPE=$(zenity --list --title="Choose your installation type:" --column="Type" --column="Name" 1 "Install HoloISO, version $(cat /etc/os-release | grep VARIANT_ID | cut -d "=" -f 2 | sed 's/"//g') " \2 "Exit installer"  --width=700 --height=220)
if [[ "${HOLO_INSTALL_TYPE}" == "1" ]] || [[ "${HOLO_INSTALL_TYPE}" == "barebones" ]]; then
	echo "Installing SteamOS, barebones configuration..."
	base_os_install
	full_install
	zenity --warning --text="Installation finished! You may reboot now, or type arch-chroot /mnt to make further changes" --width=700 --height=50
else
	zenity --warning --text="Exiting installer..." --width=120 --height=50
fi

echo "End time: $(date)"
