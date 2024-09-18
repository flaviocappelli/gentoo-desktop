#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Perform some system cleaning actions. For Gentoo
# and other Linux distributions with systemd (running).


# Immediately abort on errors.
set -e

# Safety check.
if [ ! -d /run/systemd/system ]; then
    echo ""
    echo "SYSTEMD not running. Sorry, this script is designed"
    echo "for Linux distributions based on systemd. Aborting."
    echo ""
    exit 1
fi


# This does not need an explanation!
show_usage_and_exit()
{
    echo ""
    echo "Usage:  $(basename $0) options"
    echo ""
    echo "Options:"
    echo "  -h  display this usage summary"
    echo "  -a  carry out all cleaning actions"
    echo "  -c  clean only the cups spool directory"
    echo "  -d  clean only the systemd journal and coredumps"
    echo "  -e  clean only the elog duplicates (Gentoo only)"
    echo "  -r  clean only the rotated logs in /var/log"
    echo "  -s  clean only the samba cache and logs"
    echo "  -t  clean only the timeshift logs"
    echo ""
    exit 1
}


# GENTOO ONLY.
# Remove elog duplicates (Gentoo only). This assume PORTAGE_ELOG_SYSTEM="echo save"
# with 'split-elog split-log' NOT set (see https://wiki.gentoo.org/wiki/Portage_log).
clean_elog_dups()
{
    if [ -d /var/log/portage/elog ]; then
        echo -n "Removing elog duplicates... "
        if [ $(ls -A /var/log/portage/elog | wc -l) -gt 1 ]; then

            # First remove elog duplicates with the same contents (keep the
            # most recent, see https://unix.stackexchange.com/questions/192701)
            md5sum /var/log/portage/elog/* | sort -r | awk 'h[$1]{ printf "%s\0", $2; next }{ h[$1] = $2 }' | xargs -0 rm -f

            # Then remove elog duplicates related to the same package.
            ls /var/log/portage/elog/* | sort -r | awk -F ':' 'h[$1$2]{ printf "%s:%s:%s\0", $1, $2, $3; next }{ h[$1$2] = $1$2 }' | xargs -0 rm -f

        fi
        echo "ok"
    fi
}


# Clean cups spool folder if no jobs are running (abort otherwise).
clean_cups_spool()
{
    if command -v cancel &>/dev/null; then
        echo -n "Cleaning cups spool directory... "
        QUEUED_JOBS="$(lpstat -R)"
        if [ -n "$QUEUED_JOBS" ]; then
            echo "jobs in print queue, aborting"
        else
            cancel -a -x
            echo "ok"
        fi
    fi
}


# Clean samba cache and logs. Samba services (if
# running) must be stopped and the end restarted.
clean_samba_cache()
{
    local NMB_S=0
    local SMB_S=0
    local NMBD_S=0
    local SMBD_S=0
    local SAMBA_S=0
    local WINBIND_S=0
    local WINBINDD_S=0
    local SAMBA_ADDC_S=0

    # Detect which samba services are running. NOTE: Samba services slightly differ among
    # Linux distros (and some systems have some services duplicated using symbolic links).
    [[ -e /lib/systemd/system/nmb.service ]] && [[ ! -L /lib/systemd/system/nmb.service ]] && systemctl is-active --quiet nmb && NMB_S=1
    [[ -e /lib/systemd/system/smb.service ]] && [[ ! -L /lib/systemd/system/smb.service ]] && systemctl is-active --quiet smb && SMB_S=1
    [[ -e /lib/systemd/system/nmbd.service ]] && [[ ! -L /lib/systemd/system/nmbd.service ]] && systemctl is-active --quiet nmbd && NMBD_S=1
    [[ -e /lib/systemd/system/smbd.service ]] && [[ ! -L /lib/systemd/system/smbd.service ]] && systemctl is-active --quiet smbd && SMBD_S=1
    [[ -e /lib/systemd/system/samba.service ]] && [[ ! -L /lib/systemd/system/samba.service ]] && systemctl is-active --quiet samba && SAMBA_S=1
    [[ -e /lib/systemd/system/winbind.service ]] && [[ ! -L /lib/systemd/system/winbind.service ]] && systemctl is-active --quiet winbind && WINBIND_S=1
    [[ -e /lib/systemd/system/winbindd.service ]] && [[ ! -L /lib/systemd/system/winbindd.service ]] && systemctl is-active --quiet winbindd && WINBINDD_S=1
    [[ -e /lib/systemd/system/samba-ad-dc.service ]] && [[ ! -L /lib/systemd/system/samba-ad-dc.service ]] && systemctl is-active --quiet samba-ad-dc && SAMBA_ADDC_S=1

    # ONLY FOR DEBUG.
    #echo "NMB_S        = ${NMB_S}"
    #echo "SMB_S        = ${SMB_S}"
    #echo "NMBD_S       = ${NMBD_S}"
    #echo "SMBD_S       = ${SMBD_S}"
    #echo "SAMBA_S      = ${SAMBA_S}"
    #echo "WINBIND_S    = ${WINBIND_S}"
    #echo "WINBINDD_S   = ${WINBINDD_S}"
    #echo "SAMBA_ADDC_S = ${SAMBA_ADDC_S}"

    # Stop running Samba services.
    echo -n "Stopping running samba services... "
    [[ ${NMB_S} -eq 1 ]] && systemctl stop nmb
    [[ ${SMB_S} -eq 1 ]] && systemctl stop smb
    [[ ${NMBD_S} -eq 1 ]] && systemctl stop nmbd
    [[ ${SMBD_S} -eq 1 ]] && systemctl stop smbd
    [[ ${SAMBA_S} -eq 1 ]] && systemctl stop samba
    [[ ${WINBIND_S} -eq 1 ]] && systemctl stop winbind
    [[ ${WINBINDD_S} -eq 1 ]] && systemctl stop winbindd
    [[ ${SAMBA_ADDC_S} -eq 1 ]] && systemctl stop samba-ad-dc
    echo "ok"

    # Clean samba cache and logs.
    # NOTE: /var/lib/samba MUST NOT BE MODIFIED.
    echo -n "Cleaning samba cache and logs... "
    rm -f /var/log/samba/log.*
    rm -rf /var/cache/samba/*
    rm -rf /var/run/samba/*
    echo "ok"

    echo -n "Restarting samba services... "
    [[ ${SAMBA_ADDC_S} -eq 1 ]] && systemctl start samba-ad-dc
    [[ ${WINBINDD_S} -eq 1 ]] && systemctl start winbindd
    [[ ${WINBIND_S} -eq 1 ]] && systemctl start winbind
    [[ ${SAMBA_S} -eq 1 ]] && systemctl start samba
    [[ ${SMBD_S} -eq 1 ]] && systemctl start smbd
    [[ ${NMBD_S} -eq 1 ]] && systemctl start nmbd
    [[ ${SMB_S} -eq 1 ]] && systemctl start smb
    [[ ${NMB_S} -eq 1 ]] && systemctl start nmb
    echo "ok"
}


# Clean systemd journal and coredumps.
clean_systemd_logs()
{
    echo -n "Cleaning systemd journal and coredumps... "

    # Flush the systemd journal. NOTE: set -e must be disabled
    # during the while loop and re-enabled afterwards; since the
    # set -e implementations vary greatly between shells/versions,
    # the best solution to avoid headaches is to use a subshell.
    (
        set +e
        while : ; do
            RESULT="$(journalctl --flush --sync --rotate --vacuum-time=1s 2>&1 | grep -v 0B)"
            [[ -z "${RESULT}" ]] && break
        done
    )

    # Remove old coredumps (if any).
    rm -f /var/lib/systemd/coredump/*

    echo "ok"
}


# Clean logs generated by timeshift.
clean_timeshift_logs()
{
    echo -n "Cleaning timeshift logs... "

    rm -f /var/log/timeshift/*

    echo "ok"
}


# Clean rotated logs in /var/log.
clean_rotated_logs()
{
    echo -n "Cleaning rotated logs in /var/log... "

    rm -f $(find /var/log -name '*.gz')
    rm -f $(find /var/log -name '*.old')
    rm -f $(find /var/log -name '*.[0-9]')
    rm -f $(find /var/log -name '*.[1-9].log*')

    echo "ok"
}


# Process options (if any).
ELOG_DUPS=0
CUPS_SPOOL=0
SAMBA_CACHE=0
ROTATED_LOGS=0
SYSTEMD_LOGS=0
TIMESHIFT_LOGS=0
ACTION_ENABLED=0
while getopts ":acdehrst" opt; do
    case ${opt} in
        a) ELOG_DUPS=1
           CUPS_SPOOL=1
           SAMBA_CACHE=1
           ROTATED_LOGS=1
           SYSTEMD_LOGS=1
           TIMESHIFT_LOGS=1
           ACTION_ENABLED=1
           ;;
        c) CUPS_SPOOL=1
           ACTION_ENABLED=1
           ;;
        d) SYSTEMD_LOGS=1
           ACTION_ENABLED=1
           ;;
        e) ELOG_DUPS=1
           ACTION_ENABLED=1
           ;;
        h) show_usage_and_exit
           ;;
        r) ROTATED_LOGS=1
           ACTION_ENABLED=1
           ;;
        s) SAMBA_CACHE=1
           ACTION_ENABLED=1
           ;;
        t) TIMESHIFT_LOGS=1
           ACTION_ENABLED=1
           ;;
        ?) echo -e "\nError: invalid option -${OPTARG}  (use -h for help)\n"
           exit 1
           ;;
    esac
done

# Check if a clean action is enabled.
if [ ${ACTION_ENABLED} -eq 0 ]; then
    echo -e "\nError: at least one option must be specified  (use -h for help)\n"
    exit 1
fi

# Ensure daemons are reloaded (after a system update, daemons must
# be reloaded, before any of them can be stopped or (re)started).
systemctl daemon-reload

# Perform clean actions.
echo ""
[[ $ELOG_DUPS -eq 1 ]] && clean_elog_dups
[[ $CUPS_SPOOL -eq 1 ]] && clean_cups_spool
[[ $SAMBA_CACHE -eq 1 ]] && clean_samba_cache
[[ $SYSTEMD_LOGS -eq 1 ]] && clean_systemd_logs
[[ $ROTATED_LOGS -eq 1 ]] && clean_rotated_logs
[[ $TIMESHIFT_LOGS -eq 1 ]] && clean_timeshift_logs
echo ""
exit 0
