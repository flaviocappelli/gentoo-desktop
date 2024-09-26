EXE="/usr/bin/meld"

if [ -e "$EXE" ]; then
  cp -u org.gnome.Meld.servicemenu /usr/share/kio/servicemenus/meld.desktop
else
  rm -f /usr/share/kio/servicemenus/meld.desktop
fi
