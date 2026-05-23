#!/bin/sh

# Exit immediately if any command fails
set -e

echo "=========================================================="
echo " Custom FreeBSD GNOME + LightDM + NVIDIA-DRM Script       "
echo "=========================================================="

# 1. Update package database and upgrade existing system components
echo ""
echo "[1/9] Updating package repositories and upgrading system..."
env ASSUME_ALWAYS_YES=yes pkg update
env ASSUME_ALWAYS_YES=yes pkg upgrade

# 2. Install desktop core, utilities, fonts, LightDM, and NVIDIA DRM tools
echo ""
echo "[2/9] Installing applications, LightDM, GNOME, Fonts, and Drivers..."
env ASSUME_ALWAYS_YES=yes pkg install xorg gnome lightdm lightdm-gtk-greeter nvidia-drm-kmod nvidia-settings nvidia-xconfig nano gedit sudo mkfontscale urw-base35-fonts noto firefox vlc gnome-terminal gnome-system-monitor

# 3. Append background services and modules to /etc/rc.conf via sysrc
echo ""
echo "[3/9] Writing configuration values via sysrc..."
sysrc dbus_enable="YES"
sysrc lightdm_enable="YES"
sysrc kld_list+=" nvidia-drm"
sysrc kld_list+=" nvidia-modeset"

# 4. Configure system boot properties in /boot/loader.conf
echo ""
echo "[4/9] Applying DRM modeset parameters to /boot/loader.conf..."
if grep -q 'hw.nvidiadrm.modeset="1"' /boot/loader.conf 2>/dev/null; then
    echo "--> Direct Rendering Manager options already exist. Skipping."
else
    echo 'hw.nvidiadrm.modeset="1"' >> /boot/loader.conf
    echo "--> Appended hw.nvidiadrm.modeset=\"1\" to /boot/loader.conf"
fi

# 5. Mount procfs (Required for GNOME to track system processes)
echo ""
echo "[5/9] Inspecting and configuring /proc file system..."
if grep -q "proc" /etc/fstab; then
    echo "--> procfs entry already exists in /etc/fstab."
else
    echo "proc /proc procfs rw 0 0" >> /etc/fstab
    echo "--> Appended procfs to /etc/fstab."
fi

# Live mount procfs right now to prevent needing an explicit reboot loop
if ! mount | grep -q "procfs"; then
    mount -t procfs proc /proc
fi

# 6. Add user 'hema' to required system permission groups
echo ""
echo "[6/9] Assigning permission groups for user 'hema'..."
pw groupmod video -m hema || echo "--> Note: User group step skipped or user already added."
pw groupmod wheel -m hema || echo "--> Note: User group step skipped or user already added."

# 7. Configure sudoers to uncheck # before wheel and validate via visudo
echo ""
echo "[7/9] Unleashing sudo privileges for wheel group members..."
SUDOERS_FILE="/usr/local/etc/sudoers"

if [ -f "$SUDOERS_FILE" ]; then
    # Safely remove the comment character '#' located directly before '%wheel ALL=(ALL:ALL) ALL'
    sed -i '' 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$SUDOERS_FILE"
    sed -i '' 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' "$SUDOERS_FILE"
    
    # Run the safety syntax validation compiler checker built into visudo
    echo "--> Validating sudoers file consistency using visudo..."
    visudo -c
else
    echo "ERROR: Sudoers file not found at $SUDOERS_FILE. Is the sudo package missing?"
    exit 1
fi

# 8. Generate the updated X11 hardware display file for NVIDIA (20-nvidia.conf)
echo ""
echo "[8/9] Generating Xorg configuration overrides (20-nvidia.conf)..."

cat << 'EOF' > /usr/local/etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
EndSection
EOF
echo "--> Created /usr/local/etc/X11/xorg.conf.d/20-nvidia.conf"

# 9. Force rebuild the system font cache
echo ""
echo "[9/9] Rebuilding the system font cache..."
fc-cache -f

echo ""
echo "=========================================================="
echo " SUCCESS! GNOME with LightDM and NVIDIA setups complete.  "
echo " Please execute: reboot                                   "
echo "=========================================================="
