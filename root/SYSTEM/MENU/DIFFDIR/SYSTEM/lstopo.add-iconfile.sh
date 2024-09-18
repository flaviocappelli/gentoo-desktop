EXE="/usr/bin/lstopo"
PIXMAP="lstopo.png"

if [ -e "$EXE" ]; then
  cp -u $PIXMAP /usr/share/pixmaps
else
  rm -f /usr/share/pixmaps/$PIXMAP
fi
