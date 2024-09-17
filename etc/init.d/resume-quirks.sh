#!/bin/sh
#
# by F.C.
# Together with "/etc/systemd/system/resume-quirks.service"
# run required special quirk actions after a system resume. To
# enable this script type 'systemctl enable resume-quirks.service'.

# Remove the touchpad driver.
# rmmod ....

# Wait some time.
sleep 1

# Reload the touchpad driver. This should solve the missing
# tap-to-click action that sometimes happens after a resume.
# modprobe ...

# Other required actions.
#...

# Notify the journald that this script has been executed.
if [ -x /usr/bin/systemd-cat ]; then
  echo 'executed' | systemd-cat -t 'resume-quirks.sh' -p info
fi

# DEBUG ONLY - Check if this script is working.
#echo "$(date) : resume-quirks.sh executed" >>/root/resume.log
