# Adding a few repos
echo "adding ubuntu-tweak ppa"
sudo add-apt-repository -y ppa:ubuntu-tweak-testing/ppa

# Updating sources
sudo apt-get update

# Installing a few packages
echo "installing gxmessage and ubuntu-tweak"
sudo apt-get install -y gxmessage ubuntu-tweak

# Install switchable graphics init script
echo "copying custom switchable graphics init file"
sudo cp switchable-graphics/switchable-graphics.conf /etc/init/

# TODO: check presence before appending
if grep -Fxq "blacklist radeon" /etc/modprobe.d/blacklist.conf
then
  echo "radeon driver already blacklisted"
else
  echo "blacklisting radeon driver"
  sudo bash -c 'echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf'
fi

# update grub setup
echo "updaing grub config"
cp /etc/default/grub /tmp/grub.back
cat /etc/default/grub | sed 's/splash"/splash acpi_backlight=vendor"/' > /tmp/new-grub
sudo mv /tmp/new-grub /etc/default/grub
sudo update-grub

# Install synaptics config
echo "updaing synaptics config"
cp /usr/share/X11/xorg.conf.d/50-synaptics.conf /tmp/50-synaptics.conf.back
sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp ./envy-touchpad/50-synaptics.conf /etc/X11/xorg.conf.d/
