#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Unlock/mount/unmount/lock the ZFS encrypted user's datasets on
# login/logout (see /etc/pam.d/system-auth). I implemented this
# script because on Gentoo the 'pam_zfs_key.so' module (from ZFS
# <= 2.1.15) does not work (at least with my zpool configuration).
# I will try the module from ZFS 2.2.x when it will be stabilized.
#
# This script is called by the 'pam_exec.so' PAM module. Note the
# variables ${PAM_USER}, ${PAM_TYPE}, ${PAM_SERVICE}, ${PAM_TTY}
# and ${PAM_RHOST} are provided by such module (see the manpage).


# Enable unmount and lock on last logout. Reason to not enabled
# it might be the need to access the datasets remotely via SSH
# (with passkey authentication) even after the user logout.
LOCK_ON_LAST_LOGOUT=1


# DO NOT CHANGE THESE VARIABLES UNLESS YOU KNOW WHAT YOU ARE DOING.
ZPOOL_NAME="storage"
ZPOOL_MOUNTPOINT="/mnt/STORAGE"


# FOR DEBUG.
TRACE_ENABLED=0
TRACE_LOG_FILE="/tmp/pam_zfs_helper.log"


# --------------- NOTHING TO MODIFY BELOW THIS POINT ---------------

# I don't know why, but opening a remote folder in KDE/PLASMA (with
# 'dolphin sftp://<remote host>') causes two or more concurrent calls
# to this script (for pam type 'open_session' and 'close_session') that
# must be serialized to avoid problems. To deal with that, this script
# implements the functions get_script_lock() and release_script_lock().
# NOTE: don't confuse the lock and unlock on this script with the lock
# and unlock of the ZFS encrypted datasets.

# Temporary file used for serializing access to this script.
SCRIPT_LOCK_FILE="/run/pam_zfs_helper.lock"

# Temporary file used for counting open sessions.
SESSION_FILE_COUNTER="/run/pam_zfs_helper/session_counter.${PAM_USER}"

# Safety checks.
[[ -z "${PAM_USER}" ]] && exit 0
[[ -z "${PAM_TYPE}" ]] && exit 0
[[ -z "${PAM_SERVICE}" ]] && exit 0

# Ignore the ${PAM_USER} that does not have a folder under the zpool.
[[ ! -d "${ZPOOL_MOUNTPOINT}/${PAM_USER}" ]] && exit 0

# PAM service that I'm considering (others are ignored):
#
# - text login on Virtual Terminal ("login"),
# - graphical login via SDDM for KDE/PLASMA ("sddm")
# - remote login via SSH with password or passkey ("sshd")
#
# NOTE: the PAM service "systemd-user" is ignored because it seems to
# have only the type "open_session", but not the type "close_session".
[[ "${PAM_SERVICE}" != "login" ]] && [[ "${PAM_SERVICE}" != "sddm" ]] && [[ "${PAM_SERVICE}" != "sshd" ]] && exit 0

# -------------------------------------- FUNCTIONS --------------------------------------

function log()
{
    local description
    case "${PAM_SERVICE}" in
        login) description="'${PAM_SERVICE}' (${PAM_TTY})"   ;;
         sshd) description="'${PAM_SERVICE}' (${PAM_RHOST})" ;;
            *) description="'${PAM_SERVICE}'"                ;;
    esac
    logger -t "pam_zfs_helper.sh" "user '${PAM_USER}': service ${description}: $1"
}

function get_script_lock()
{
    # Try to get the lock on this script. If it succeeds, then traps the
    # INT, TERM and EXIT signals to ensure that the lock file is removed
    # if something goes wrong, then returns 0 (ok). If it fails to acquire
    # the lock, then tries again (up to 1000 times), then returns 1 (fail).
    for (( i=1; i<=1000; i++ )); do
        if ( set -o noclobber; echo "$$" > "${SCRIPT_LOCK_FILE}" ) 2> /dev/null; then
            trap 'rm -f "${SCRIPT_LOCK_FILE}"; exit $?' INT TERM EXIT
		    log "script lock aquired after $i attempt(s)"
            return 0
        fi
    done
    log "failed to aquire script lock after 1000 attempts"
    return 1
}

function release_script_lock()
{
    rm -f "${SCRIPT_LOCK_FILE}"
    trap - INT TERM EXIT
}

function unlock_and_mount_zpool()
{
    # Check if the main user's storage dataset is
    # already unlocked and mounted (if so, do nothing).
    mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
    if [ $? -ne 0 ]; then

        # No, try to unlock and mount it.
        echo "$1" | zfs load-key "${ZPOOL_NAME}/${PAM_USER}"
        zfs list -rH -o name "${ZPOOL_NAME}/${PAM_USER}" | xargs -L 1 zfs mount

        # Check if the operation was successfully.
        mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
        if [ $? -eq 0 ]; then
            log "${ZPOOL_NAME}/${PAM_USER} unlocked and mounted"
        fi
    fi
}

function increment_session_counter()
{
    # Increment the session's counter only if the main
    # user's storage dataset is unlocked and mounted.
    mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
    if [ $? -eq 0 ]; then

        # Increment the counter.
        mkdir -p $(dirname "$SESSION_FILE_COUNTER")
        expr $(cat $SESSION_FILE_COUNTER 2>/dev/null) + 1 >$SESSION_FILE_COUNTER
        log "session count: $(cat $SESSION_FILE_COUNTER)"
    fi
}

function decrement_session_counter()
{
    # Decrement the session's counter only if the main
    # user's storage dataset is unlocked and mounted.
    mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
    if [ $? -eq 0 ]; then

        # Decrement the counter.
        mkdir -p $(dirname "$SESSION_FILE_COUNTER")
        expr $(cat $SESSION_FILE_COUNTER 2>/dev/null) - 1 >$SESSION_FILE_COUNTER
        log "session count: $(cat $SESSION_FILE_COUNTER)"
    fi
}

function umount_and_lock_zpool()
{
    # Ensure the main user's storage dataset is unlocked and mounted.
    mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
    if [ $? -eq 0 ]; then

        # Sync and wait a little bit of time.
        sync
        sleep 1

        # Unmount the zpool and unload the key.
        zfs unmount "${ZPOOL_NAME}/${PAM_USER}"
        zfs unload-key "${ZPOOL_NAME}/${PAM_USER}"

        # Check if the operation was successfully.
        mountpoint -q "${ZPOOL_MOUNTPOINT}/${PAM_USER}"
        if [ $? -eq 0 ]; then
            log "${ZPOOL_NAME}/${PAM_USER} unmount failed"
        else
            log "${ZPOOL_NAME}/${PAM_USER} unmounted and locked"
        fi
    fi
}


# Try to obtain the lock on this script.
if get_script_lock; then

    # Log the PAM type.
    log "${PAM_TYPE}"

    # Handle the PAM call.
    case "${PAM_TYPE}" in

        auth)
            unlock_and_mount_zpool "$(cat -)"       # ($1 = login password)
            ;;

        password)
            # Nothing to do here. Unfortunately 'expose_authtok' is not supported by
            # 'pam_exec.so' on the password 'PAM_TYPE', so there is no way to pass the
            # new password to this script. This means that the ZFS encryption password
            # cannot be changed automatically: it must be changed manually after 'passwd'
            # with the command 'zfs change-key -o keyformat=passphrase ${ZPOOL_NAME}/$USER'
            # (by root or sudo), at least until 'pam_zfs_key.so' will finally work!
            ;;

        open_session)
            increment_session_counter
            ;;

        close_session)
            decrement_session_counter
            if [ ${LOCK_ON_LAST_LOGOUT} -ne 0 ]; then
                if [ $(cat "$SESSION_FILE_COUNTER") -eq 0 ]; then
                    umount_and_lock_zpool
                fi
            fi
            ;;

        *)  log "unknow pam type"
            ;;
    esac

    # Trace the call if enabled.
    if [ ${TRACE_ENABLED} -ne 0 ]; then
        date >> "${TRACE_LOG_FILE}"
        echo "USER: $USER" >> "${TRACE_LOG_FILE}"
        echo "PAM_RHOST: $PAM_RHOST" >> "${TRACE_LOG_FILE}"
        echo "PAM_RUSER: $PAM_RUSER" >> "${TRACE_LOG_FILE}"
        echo "PAM_SERVICE: ${PAM_SERVICE}" >> "${TRACE_LOG_FILE}"
        echo "PAM_TTY: $PAM_TTY" >> "${TRACE_LOG_FILE}"
        echo "PAM_USER: ${PAM_USER}" >> "${TRACE_LOG_FILE}"
        echo "PAM_TYPE: ${PAM_TYPE}" >> "${TRACE_LOG_FILE}"
        if [ -e "${SESSION_FILE_COUNTER}" ]; then
            echo "session count: $(cat $SESSION_FILE_COUNTER)" >> "${TRACE_LOG_FILE}"
        fi
        echo "-----------------------------------------------------------------------" >> "${TRACE_LOG_FILE}"
    fi

    # Release the lock.
    release_script_lock
fi
exit 0
