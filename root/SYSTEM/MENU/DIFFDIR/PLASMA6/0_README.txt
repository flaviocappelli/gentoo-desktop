
The "Settings" menu has been removed in PLASMA 6.3 and merged with the "System" menu!
I don't like such change because combining system apps and settings creates confusion.

The "plasma-applications.menu.diff" patch restores the "Settings" menu, provided the
"/usr/share/desktop-directories/kf5-settingsmenu.directory" file exists. This file has
not been removed by the PLASMA maintainers at this time; if this happens in the future,
simply restore the copy saved here.
