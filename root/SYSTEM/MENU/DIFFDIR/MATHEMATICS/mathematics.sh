# Remove old "mathematics" menu (if any).
rm -f /etc/xdg/menus/applications-merged/[Mm]athematics.menu
rm -f /usr/share/desktop-directories/[Mm]athematics.directory

# Add my menu.
cp -f mathematics.menu /etc/xdg/menus/applications-merged/
cp -f mathematics.directory /usr/share/desktop-directories/
