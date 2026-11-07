#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.1
#
# Perform some system cleaning actions. For Gentoo
# and other Linux distributions with systemd (running).
#
# ShellCheck (-s bash -o all): PASS (2026-10-29)


# Exit immediately on command failures (unless explicitly handled).
set -euo pipefail


# Safety check.
if [[ ! -d /run/systemd/system ]]; then
    printf '\nSYSTEMD not running. Sorry, this script is designed\n'
    printf 'for Linux distributions based on systemd. Aborting.\n\n'
    exit 1
fi

# Error handling.
fatal_error()
{
    printf "\nError: %s\n\n" "${1}" >&2
    exit 1
}


# This does not need any explanation!
show_usage_and_exit()
{
    cat <<EOF

Usage:  ${0##*/} options

Options:
  -h  display this usage summary
  -a  carry out all cleaning actions
  -c  clean only the cups spool directory
  -e  clean only the elog duplicates (Gentoo only)
  -j  clean only the systemd journal and coredumps
  -r  clean only the rotated logs in /var/log
  -s  clean only the samba cache and logs
  -t  clean only the timeshift logs

EOF
    # Help (-h) should not be considered an error.
    exit 0
}


# GENTOO ONLY.
# Remove elog duplicates (Gentoo only). This assume PORTAGE_ELOG_SYSTEM="echo save"
# with 'split-elog split-log' NOT set (see https://wiki.gentoo.org/wiki/Portage_log).
clean_elog_dups()
{
    local elog_dir=/var/log/portage/elog
    local filelist file hash filename key
    local -A hashseen=() pkgseen=()             # Associative arrays (Bash 4+).

    [[ -d "${elog_dir}" ]] || return 0

    printf 'Removing elog duplicates... '

    # Get list of elog files.
    if ! filelist=$(find "${elog_dir}" -maxdepth 1 -type f -name '*.log'); then
        fatal_error 'Cannot enumerate elog files'
    fi

    # Remove elog files with identical contents. Keep one
    # file per MD5 hash; the retained filename is arbitrary.
    while IFS= read -r file; do
        [[ -n "${file}" ]] || continue

        # Get hash of elog file.
        hash=$(md5sum < "${file}") || fatal_error "Cannot hash file '${file}'"
        hash=${hash%% *}                        # Remove ' -' after the hash.

        # Check if key (hash) is already stored.
        if [[ -v 'hashseen[$hash]' ]]; then
            rm -f -- "${file}" || fatal_error "Cannot remove file '${file}'"
        else
            hashseen[${hash}]=1                 # Store the hash
        fi
    done <<< "${filelist}"                      # Process elog file list.

    # Rebuild list of remaining elog files.
    if ! filelist=$(find "${elog_dir}" -maxdepth 1 -type f -name '*.log'); then
        fatal_error 'Cannot enumerate elog files'
    fi

    # Sort by descending timestamp, not by package version.
    if ! filelist=$(printf '%s\n' "${filelist}" | sort -t: -k3,3r); then
        fatal_error 'Cannot sort elog file list'
    fi

    # Remove older elog files belonging to the same category/package
    # (keep at most two logs per category/package, newest first).
    while IFS= read -r file; do
        [[ -n "${file}" ]] || continue

        # Get the filename (remove path). It has this format:
        # <category>:<package>-<version>:<date>-<time>.log
        filename=${file##*/}

        # Get the key (category:package).
        key=${filename%%-[0-9]*};

        # Keep at most two files per key.
        if [[ -v 'pkgseen[$key]' ]]; then
            if (( pkgseen[${key}] >= 2 )); then
                rm -f -- "${file}" || fatal_error "Cannot remove file '${file}'"
                continue
            fi
            ((++pkgseen[${key}]))
        else
            pkgseen[${key}]=1
        fi
    done <<< "${filelist}"

    printf 'ok\n'
}


# Clean cups spool folder if no jobs are running (abort otherwise).
clean_cups_spool()
{
    if command -v cancel &>/dev/null; then
        printf 'Cleaning cups spool directory... '
        QUEUED_JOBS="$(lpstat -R)"
        if [[ -n "${QUEUED_JOBS}" ]]; then
            printf 'jobs in print queue, aborting\n'
        else
            cancel -a -x
            printf 'ok\n'
        fi
    fi
}


# Clean samba cache, old sockets (see https://bugzilla.samba.org/show_bug.cgi?id=12435)
# and logs. Samba services (if running) must be stopped (and restarted after the clean).
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
    #printf 'NMB_S        = %s\n' "${NMB_S}"
    #printf 'SMB_S        = %s\n' "${SMB_S}"
    #printf 'NMBD_S       = %s\n' "${NMBD_S}"
    #printf 'SMBD_S       = %s\n' "${SMBD_S}"
    #printf 'SAMBA_S      = %s\n' "${SAMBA_S}"
    #printf 'WINBIND_S    = %s\n' "${WINBIND_S}"
    #printf 'WINBINDD_S   = %s\n' "${WINBINDD_S}"
    #printf 'SAMBA_ADDC_S = %s\n' "${SAMBA_ADDC_S}"

    # Stop running Samba services.
    printf 'Stopping running samba services... '
    (( NMB_S )) && systemctl stop nmb
    (( SMB_S )) && systemctl stop smb
    (( NMBD_S )) && systemctl stop nmbd
    (( SMBD_S )) && systemctl stop smbd
    (( SAMBA_S )) && systemctl stop samba
    (( WINBIND_S )) && systemctl stop winbind
    (( WINBINDD_S )) && systemctl stop winbindd
    (( SAMBA_ADDC_S )) && systemctl stop samba-ad-dc
    printf 'ok\n'

    # Clean samba cache, old sockets and logs (NOTE:
    # do not modify other subdirs in /var/lib/samba).
    printf 'Cleaning samba cache, old sockets and logs... '
    rm -f /var/log/samba/log.*
    rm -f /var/lib/samba/private/msg.sock/*
    rm -rf /var/cache/samba/*
    rm -rf /var/run/samba/*
    printf 'ok\n'

    printf 'Restarting samba services... '
    (( SAMBA_ADDC_S )) && systemctl start samba-ad-dc
    (( WINBINDD_S )) && systemctl start winbindd
    (( WINBIND_S )) && systemctl start winbind
    (( SAMBA_S )) && systemctl start samba
    (( SMBD_S )) && systemctl start smbd
    (( NMBD_S )) && systemctl start nmbd
    (( SMB_S )) && systemctl start smb
    (( NMB_S )) && systemctl start nmb
    printf 'ok\n'
}


# Clean systemd journal and coredumps.
clean_systemd_logs()
{
    printf 'Cleaning systemd journal and coredumps... '

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

    printf 'ok\n'
}


# Clean logs generated by timeshift.
clean_timeshift_logs()
{
    printf 'Cleaning timeshift logs... '

    rm -f /var/log/timeshift/*

    printf 'ok\n'
}


# Clean rotated logs in /var/log (and some others).
clean_rotated_logs()
{
    printf 'Cleaning rotated logs in /var/log... '

    # Safety constraint: -xdev prevents find from descending into directories on
    # other filesystems. NOTE: When modifying the search criteria, for the first
    # run, use -print instead of -delete to verify which files would be deleted.
    local EXEC='-delete'
    find /var/log -xdev -type f -name '*.gz'    "${EXEC}"
    find /var/log -xdev -type f -name '*.old'   "${EXEC}"
    find /var/log -xdev -type f -name '*.log-*' "${EXEC}"
    #find /var/log -xdev -type f -name '*.[0-9]' "${EXEC}"

    # Other logs that can be safely deleted.
    rm -f /var/log/cpufreq-bench/*.log
    rm -f /var/log/cups/*.O

    printf 'ok\n'
}


# Process options (if any).
ELOG_DUPS=0
CUPS_SPOOL=0
SAMBA_CACHE=0
ROTATED_LOGS=0
SYSTEMD_LOGS=0
TIMESHIFT_LOGS=0
ACTION_ENABLED=0
while getopts ':acehjrst' opt; do
    case "${opt}" in
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
        e) ELOG_DUPS=1
           ACTION_ENABLED=1
           ;;
        h) show_usage_and_exit
           ;;
        j) SYSTEMD_LOGS=1
           ACTION_ENABLED=1
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
        :) fatal_error "Option '-${OPTARG}' requires an argument (use -h for help)"
           ;;
        *) fatal_error "Invalid option '-${OPTARG}' (use -h for help)"
           ;;
    esac
done
shift $((OPTIND - 1))

# Check extra options.
(( $# )) && fatal_error "Invalid argument '${1}'\n\n"

# Check if at least one action is enabled.
(( ACTION_ENABLED )) || fatal_error 'At least one option must be specified (use -h for help)'

# Ensure daemons are reloaded (after a system update, daemons must
# be reloaded, before any of them can be stopped or (re)started).
systemctl daemon-reload

# Perform requested clean actions.
printf '\n'
(( ELOG_DUPS )) && clean_elog_dups
(( CUPS_SPOOL )) && clean_cups_spool
(( SAMBA_CACHE )) && clean_samba_cache
(( SYSTEMD_LOGS )) && clean_systemd_logs
(( ROTATED_LOGS )) && clean_rotated_logs
(( TIMESHIFT_LOGS )) && clean_timeshift_logs
printf '\n'
exit 0
