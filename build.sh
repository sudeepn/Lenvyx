# Build script
dpkg-deb --build switchable-graphics
dpkg-deb --build lenvyx-flash
mv *.deb build/
