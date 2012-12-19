sudo apt-get install gxmessage
sudo dpkg -i build/*.deb
./build/install-jdk-7
./build/install-ubuntu-tweak

cp /usr/share/X11/xorg.conf.d/50-synaptics.conf /tmp/50-synaptics.conf.back
sudo mkdir -p /etc/X11/xorg.conf.d
sudo cp ./envy-touchpad/50-synaptics.conf /etc/X11/xorg.conf.d/