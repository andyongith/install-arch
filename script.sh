#!/usr/bin/bash

echo -n root partition\(e.g. /dev/sda2\) : 
read ROOT

echo -n EFI partition\(e.g. /dev/sda1\) : 
read ESP

echo
echo -n Enter root password :
read RTPASSWD

echo
echo -n Enter username:
read USERNAME
echo -n Enter passwword:
read  PASSWORD

mkfs.vfat -F32 -n "ESP" $ESP
mkfs.ext4 -L "Arch-root" $ROOT

mount $ROOT /mnt/
mkdir -p /mnt/boot/efi
mount $ESP /mnt/boot/efi/

customize-pacman-conf() {
  if grep -q "#Color" $1; then
    sed -i "`grep -n "#Color" $1 | cut -d: -f1`s/.*/Color/" $1
  fi
  if grep -q "#VerbosePkgLists" $1; then
    sed -i "`grep -n "#VerbosePkgLists" $1 | cut -d: -f1`s/.*/VerbosePkgLists/" $1
  fi
  if grep -q "#ParallelDownloads" $1; then
    sed -i "`grep -n "#ParallelDownloads" $1 | cut -d: -f1`s/.*/ParallelDownloads = 5\nILoveCandy/" $1
  fi
}
customize-pacman-conf /etc/pacman.conf

echo
echo "Updating mirrorlist... This might take some time"
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Sy archlinux-keyring
pacstrap /mnt/ \
  base base-devel \
  linux-lts linux-firmware linux-lts-headers \
  efibootmgr grub os-prober \
  intel-ucode amd-ucode \
  exfat-utils \
  networkmanager \
  vi vim \
  reflector man-db \
  --noconfirm --needed
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab

customize-pacman-conf /mnt/etc/pacman.conf

echo -e "
#!/usr/bin/bash

systemctl enable NetworkManager

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

sed -i 's/#en_IN/en_IN/' /etc/locale.gen
locale-gen
echo \"LANG=en_IN.UTF-8\" >> /etc/locale.conf

grep '# %wheel' /etc/sudoers | grep -q -v 'NOPASSWD' && \\
sed -i \"$\(grep -n '# %wheel' /etc/sudoers | grep -v 'NOPASSWD' | cut -d: -f1)s/# //\" /etc/sudoers
grep '# %sudo' /etc/sudoers | grep -q -v 'NOPASSWD' && \\
sed -i \"$\(grep -n '# %sudo' /etc/sudoers | grep -v 'NOPASSWD' | cut -d: -f1)s/# //\" /etc/sudoers

sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
grub-install --bootloader-id=Arch --efi-directory=/boot/efi/ --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

echo \"${RTPASSWD}\n${RTPASSWD}\n\" | passwd
useradd -m -U -G wheel,network,scanner,power,audio,disk,input,video ${USERNAME}
echo \"${PASSWORD}\n${PASSWORD}\n\" | passwd ${USERNAME}

" > /mnt/afterscript.sh

arch-chroot /mnt sh afterscript.sh

rm /mnt/afterscript.sh