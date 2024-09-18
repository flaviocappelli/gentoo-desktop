
# NOTE
If the submenus disappear, the XDG_CONFIG_DIR variable has probably been
overwritten (and the path "/etc/xdg" has been lost). Make sure that
XDG_CONFIG_DIRS contains the path "/etc/xdg". <br/>

# MY PATCHES FOR KDE/PLASMA DESKTOP FILES
I don't like the content and look of the menu we get with the default .desktop
files in KDE/PLASMA. In this folder (and its subdirs) there are patches for some
.desktop files, used to make the KDE/PLASMA menu cleaner and nicer. To apply
them, simply run "patch_menu.sh".

How it works: each .desktop file in "/usr/share/applications/" is first
simplified by the python script "simplify_desktopfiles.py", then a patch is
applied (if it exists) by the bash script "patch_menu.sh". The simplification:

* Eliminate unnecessary lines in the .desktop file: this ensures that upstream
  changes in lines we are not interested in (or added lines we are not interested
  in) do not invalidate any patch previously created.

* Reorder items in the "MimeType" entry: in Gentoo (and maybe also in other distros)
  MimeType is sometimes generated at install time;  subsequent  reinstallations of
  the same package may generate a different "MimeType" entry (and consequently a
  different .desktop file) causing the patch to fail; reordering the "MimeType"
  elements solves the issue.

* Reorders all the lines of the final .desktop file, so that simply changing the
  position of the various entries in the original .desktop file does not invalidate
  the created patch.

These modifications minimize the maintenance of such patches (which being created
by hand, require a certain amount of time and effort); however, two simple rules
must be followed to avoid problems:

1. Always run "patch_menu.sh" immediately after the emerge, i.e. before creating
   a new patch, because otherwise the patch will be created not on the simplified
   .desktop file but on the original one (causing a failure of the patch itself
   when running "patch_menu.sh" a second time).

2. Be careful not to change the order of the lines rearranged by the script
   "simplify_desktopfiles.py" in the generated patch, otherwise the patch will be
   applied correctly only the first time: the next start of "patch_menu.sh" would
   change the order of the lines, making the new simplified .desktop file different
   from the previous one (i.e. the one on which the patch was generated). The required
   order is easily understood by looking at the "simplify_desktopfiles.py" script
   (code after comment "# Sort lines in each section of a desktop file").

By following these two simple rules, you should have no problems creating and applying
your patches (unless there are bugs in the "simplify_desktopfiles.py" script, or other
aspects of the desktop files not yet considered).
