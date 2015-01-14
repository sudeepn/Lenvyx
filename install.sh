# Install support for brightness keybord buttons
xorg_dir="/etc/X11/xorg.conf.d/"
if [[ ! -e $xorg_dir ]]; then
    sudo mkdir $xorg_dir
fi
sudo cp 20-intel.conf $xorg_dir

# Install switchable graphics init script
echo "copying custom switchable graphics init file (turns off radeon card)"
sudo cp switchable-graphics.conf /etc/init/

# update grub setup
echo "update grub config (/etc/default/grub) to disable radeon power management"
cp /etc/default/grub /tmp/grub.back
cat /etc/default/grub | sed 's/splash"/splash radeon.runpm=0"/' > /tmp/new-grub
sudo mv /tmp/new-grub /etc/default/grub
sudo update-grub

echo "patch ok, you need to restart now"
