#!/bin/bash


# 1) In BIOS, disable UEFI Secure Boot
# 2) When installing, use Custom Partitioning to create a swap partition
#    of RAM size + 4GiB.  See:
#    https://fedoraproject.org/wiki/Changes/SwapOnZRAM
#    https://pagure.io/fedora-workstation/blob/master/f/hibernationstatus.md
#    https://www.phoronix.com/forums/forum/software/distributions/1231542-fedora-34-looking-to-tweak-default-zram-configuration?p=1231544#post1231544

# All of these are measured from the moment the user stops using the computer,
# and are not additive, so must be ordered.
SECONDS_UNTIL_BLANK=180
SECONDS_UNTIL_SUSPEND=600
SECONDS_UNTIL_HIBERNATE=1200
if ((SECONDS_UNTIL_BLANK >= SECONDS_UNTIL_SUSPEND)) || ((SECONDS_UNTIL_SUSPEND >= SECONDS_UNTIL_HIBERNATE))
then
	echo "Must specify SECONDS_UNTIL_BLANK < SECONDS_UNTIL_SUSPEND < SECONDS_UNTIL_HIBERNATE" 1>&2
	exit 1
fi


dnf install -y powertop tlp


# Ensure that the dracut image can handle resume from hibernation.
# See: man dracut.conf
# See: https://www.ctrl.blog/entry/fedora-hibernate.html
{
cat <<EOF
add_dracutmodules+=" resume "
EOF
} >/etc/dracut.conf.d/99-framework.conf


# Put in some optimized TLP tunings.  (NOTE: the *_CHARGE_BAT_THRESH values are not yet adhered to, but may be in the future)
# See: /etc/tlp.conf
# See: https://community.frame.work/t/bios-guide/4178/28
{
cat <<EOF
PCIE_ASPM_ON_AC=performance
PCIE_ASPM_ON_BAT=powersupersave
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
RESTORE_THRESHOLDS_ON_BAT=1
DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE="bluetooth"
#CPU_MAX_PERF_ON_BAT=30
#CPU_BOOST_ON_BAT=0
EOF
} >/etc/tlp.d/99-framework.conf


# Minimize swapping.
# See: man sysctl.conf
# See: https://linuxhint.com/understanding_vm_swappiness/
{
cat <<EOF
vm.swappiness = 1
EOF
} >/etc/sysctl.d/99-framework.conf


# logind does not distinguish between idleness on battery vs. idleness on AC power, so
# we do not use IdleAction settings here and instead rely on the GNOME Power settings plugin, below.
# See: man logind.conf
mkdir -p /etc/systemd/logind.conf.d
{
cat <<EOF
[Login]
HandlePowerKey=hibernate
HandleSuspendKey=suspend-then-hibernate
HandleLidSwitch=suspend-then-hibernate
#IdleAction=suspend-then-hibernate
#IdleActionSec=600
EOF
} >/etc/systemd/logind.conf.d/99-framework.conf


# Set when we transition from suspended to hibernation.
# See: man systemd-sleep.conf
mkdir -p /etc/systemd/sleep.conf.d
{
cat <<EOF
[Sleep]
# The delay before hibernation is measured from start of suspend mode.
HibernateDelaySec=$((SECONDS_UNTIL_HIBERNATE - SECONDS_UNTIL_SUSPEND))
EOF
} >/etc/systemd/sleep.conf.d/99-framework.conf


# This symlink sacrifices normal "suspend" to make all uses of "suspend" into "suspend-then-hibernate".
# This is because the GNOME Power settings plugin does not support "suspend-then-hibernate", but rather only "suspend".
# The sacrifice seems fine, given that I can't think of a circumstance where I would care to suspend but not eventually hibernate.
# See: https://medium.com/@gayanper/make-ubuntu-sleep-like-windows-4761a91f62c2
ln -nsT /usr/lib/systemd/system/systemd-suspend-then-hibernate.service /etc/systemd/system/systemd-suspend.service


# Set the timeout for transition to blank screen and to suspend (which will act like "suspend-then-hibernate" due to the symlink above).
# Improve text size without turning on experimental scaling features.
{
cat <<EOF
[org/gnome/desktop/session]
#idle-delay corresponds to "Blank Screen" in GNOME Power Control Panel.  It is measured from start of inactivity.
idle-delay=uint32 ${SECONDS_UNTIL_BLANK}

[org/gnome/settings-daemon/plugins/power]
power-button-action='hibernate'
#sleep-inactive-battery-timeout corresponds to "Automatic Suspend"..."On Battery Power" settings in GNOME Power settings panel.  It is measured from start of inactivity.
sleep-inactive-battery-timeout=${SECONDS_UNTIL_SUSPEND}
sleep-inactive-battery-type='suspend'
sleep-inactive-ac-timeout=3600
sleep-inactive-ac-type='nothing'

[org/gnome/desktop/interface]
#text-scaling-factor corresponds to "Large Text" setting in the GNOME Accessibility settings panel.
text-scaling-factor 1.25
EOF
} >/etc/dconf/db/local.d/99-framework


# Lock settings related to blanking/suspend/hibernate so they don't get misconfigured into a non-functional setup by users.
{
cat <<EOF
/org/gnome/desktop/session/idle-delay
/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout
/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type
EOF
} >/etc/dconf/db/local.d/locks/99-framework


# Apply the settings.  Any logged-in GNOME user will need to logout (but not reboot) to have them take effect.
dracut -f
grub2-mkconfig -o /boot/grub2/grub.cfg
systemctl enable --now fstrim.timer
systemctl enable --now powertop
systemctl enable --now tlp
systemctl unmask systemd-rfkill.service
sysctl --system
systemctl daemon-reload
dconf update

