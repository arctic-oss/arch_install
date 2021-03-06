#!/usr/bin/env bash

printf '\033c'
echo "Welcome....."

echo "Running reflector....."
reflector --latest 20 --sort rate --protocol htpps --download-timeout 5 --save /etc/pacman.d/mirrorlsit
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

pacman --noconfirm -Syy archlinux-keyring

timedatectl set-ntp true
loadkeys us

echo ""
read -p "Already partitioned and mounted? [y/n]: " partcompleted

if [[ $partcompleted = n ]]; then
	while :
	do
		lsblk
		echo ""
		read -p "Enter the drive: " drive
		cfdisk $drive
		read -p "Is partition completed? [y/n]: " iscompleted
		if [[ $iscompleted = y ]]; then
			break
		fi
	done

	lsblk
	echo ""
	echo "Enter the Root Partition: "
	read rootpartition
	mkfs.ext4 $rootpartition
	mount $rootpartition /mnt

	lsblk
	echo ""
	echo "Enter the Efi Partition: "
	read efipartition
	mkfs.fat -F 32 $efipartition
	mkdir -p /mnt/boot/efi
	mount $efipartition /mnt/boot/efi

	read -p "Did you also create a Swap Partition? [y/n]: " answer
	if [[ $answer = y ]]; then
		lsblk
		echo ""
		echo "Enter the Swap Partition: "
		read swappartition
		mkswap $swappartition
		swapon $swappartition
	fi

	read -p "Did you create a separate Home Partition? [y/n]: " homesep
	if [[ $homesep = y ]]; then
		lsblk
		echo ""
		echo "Enter the Home Partition: "
		read homepartition
		mkfs.ext4 $homepartition
		mkdir /mnt/home
		mount $homepartition /mnt/home
	fi
fi

echo ""
lsblk
echo ""

pacstrap --needed /mnt base base-devel linux linux-firmware linux-headers intel-ucode
genfstab -U /mnt >> /mnt/etc/fstab
cp pacman.conf /mnt/
sed '1,/^#part2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
rm /mnt/arch_install2.sh
umount -R /mnt
echo ""
echo "Installation Completed... Reboot Now."
echo ""
exit


#part2
printf '\033c'

cat pacman.conf > /etc/pacman.conf
rm pacman.conf

pacman -Sy --noconfirm --needed sed fzf chaotic-mirrorlist chaotic-keyring

sed -i 's/#\[chaotic-aur\]$/\[chaotic-aur\]/' /etc/pacman.conf
sed -i 's/#Include = \/etc\/pacman.d\/chaotic-mirrorlist$/Include = \/etc\/pacman.d\/chaotic-mirrorlist/' /etc/pacman.conf

region=$(ls /usr/share/zoneinfo | fzf --prompt="Select your Region: > ")
city=$(ls /usr/share/zoneinfo/$region | fzf --prompt="Selce your City: > ")
echo ""
ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime

hwclock --systohc

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Enter Username: "
read username

echo ""
echo "Enter Hostname: "
read hostname

echo $hostname > /etc/hostname

echo "127.0.0.1\tlocalhost
::1\t\tlocalhost
127.0.1.1\t$hostname.localdomain\t$hostname" > /etc/hosts

sed -i 's/COMPRESSION="xz"$/#COMPRESSION="xz"/' /etc/mkinitcpio.conf
mkinitcpio -p linux

echo ""
echo "Set root account password: "
passwd


pacman -Sy --noconfirm --needed grub efibootmgr os-prober
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

pacman -Sy --noconfirm --needed xorg-server xorg-xrdb xorg-xinit xorg-xwininfo \
    xorg-xrandr xorg-xkill xorg-xsetroot xorg-xprop \
    otf-cascadia-code ttf-iosevka-nerd noto-fonts ttf-jetbrains-mono ttf-font-awesome \
    sxiv mpv ffmpeg imagemagick bibata-cursor-theme dracula-gtk-theme \
    fzf man-db xwallpaper youtube-dl python-pywal xclip maim \
    zip unzip unrar p7zip yay papirus-icon-theme spaceship-prompt-git \
    zsh zsh-syntax-highlighting zsh-autosuggestions zsh-completions \
    vim rsync bash-completion reflector dmenyou firefox dosfstools git \
    dhcpcd networkmanager xdg-user-dirs pipewire pipewire-pulse pamixer jq \
    bspwm sxhkd picom-ibhagwan-git polybar-wireless alacritty dunst libnotify

systemctl enable NetworkManager
systemctl enable reflector.timer

sed -i "s/^# %wheel ALL=(ALL:ALL) ALL$/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

echo ""
echo "Adding User....."
echo ""
useradd -mG wheel,network,audio,video -s /bin/zsh $username
passwd $username

git clone https://github.com/anilbeesetti/dotfiles.git /home/$username/tmpdotfiles
rsync -avxHAXP --exclude '.git*' /home/$username/tmpdotfiles/ /home/$username/
rm -rf /home/$username/tmpdotfiles

exit
