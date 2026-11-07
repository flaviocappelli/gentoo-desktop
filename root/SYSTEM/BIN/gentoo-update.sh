#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024-2026 Flavio Cappelli
# Version 1.3
#
# Automate (as much as possible) upgrades and rebuilds of Gentoo
# systems. This script can also be invoked in "pretend mode" (-p),
# useful to safely check for updates via cron or systemd timer.
#
# Usage
# -----
#   gentoo-update.sh -h
#
# Examples
# --------
#   upgrade system
#     gentoo-update.sh
#
#   only check for upgrades
#     gentoo-update.sh -p
#
#   rebuild all installed packages
#     gentoo-update.sh @world
#
#   rebuild gentoo-kernel + external modules
#     gentoo-update.sh sys-kernel/gentoo-kernel @modules
#
#   install lyx + firefox + thunderbird, fetch first, use --jobs=1
#     gentoo-update.sh -w -f -J app-office/lyx firefox thunderbird
#
# ShellCheck (-s bash -o all): PASS (2026-11-06)


# Exit immediately on command failures (unless explicitly handled).
set -euo pipefail



# --- Configuration ------------------------------------------------------------

# Custom sets (e.g. 'math' 'fpga' ...). If empty, the script will
# attempt to determine custom sets automatically (sets detected as
# invalid are not included, see get_valid_custom_sets() function).
# If this detection is not correct, you can explicitly list your
# sets here, or disable them completely with GU_CUSTOM_SETS=('').
GU_CUSTOM_SETS=()

# Name of the local (personal) repository; leave empty if unused.
# If not specified here but still installed, the local repository
# will be parsed like the other found repositories, but no checks
# will be performed about possible upgrades for the local ebuilds.
GU_LOCAL_REPO_NAME='local'

# Script to run after a successful 'emerge' operation, in order to
# fix incorrect, poorly constructed, incomplete or ugly '*.desktop'
# files. Leave empty if you are not interested in such improvements.
GU_PATCH_MENU_SCRIPT='/root/SYSTEM/BIN/patch_menu.sh'

# Path to the script that defines the Gentoo bash function 'ver_test'
# (version comparison), relative to the ECLASS folder. Many eclasses
# and ebuilds depend on such function, so I'm confident it will remain
# available for a long time. Note: 'ver_test' was previously defined
# in 'eapi7-ver' eclass; if moved again, just update this variable.
GU_VER_TEST_REL_PATH='tests/version-funcs.sh'

# DEBUG ONLY: Set to 1 to print some diagnostics.
GU_DEBUG=0



# --- Global Variables ---------------------------------------------------------

# NOTE: Portage variables and installed repositories are
#       automatically retrieved from the Portage settings.

# Error control.
GU_FATAL_ERROR=0
GU_JOB_INTERRUPTED=0
GU_INCOMPLETE_BUILD=0

# Options.
GU_FETCH_FIRST=0
GU_ADD_TO_WORLD=0
GU_FORCE_ONE_JOB=0
GU_IGNORE_BINHOST=0
GU_FORCE_SYNC_REPOS=0
GU_FORCE_NOSYNC_REPOS=0
GU_RESUME_FROM_DEPCLEAN=0
GU_PRETEND_ONLY_MODE=0
GU_EMERGE_OPTIONS=()

# Atoms and sets.
GU_PKG_ARGS=()
GU_SET_ARGS=()

# System maintenance.
GU_SYNC_REPOS=0
GU_SKIP_ECLEAN=0
GU_SKIP_DEPCLEAN=0
GU_SKIP_BROKEN_CHECK=0
GU_SKIP_UPDATE_ENV_ETC=0
GU_SKIP_PATCH_DESKTOPFILES=0
GU_SKIP_CHECK_LOCAL=0
GU_SKIP_FINAL_MSG=0

# Associative array (see "help declare")
# used to get portage variables and repos.
declare -A GU_PORTAGE_VARS
declare -A GU_PORTAGE_REPOS

# Indicate whether the binhost network package folder is
# mounted and whether it was this script that mounted it.
GU_NET_PKGDIR_MOUNTED=0
GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT=0

# PID of child process.
GU_ACTIVE_CHILD_PID=0

# Check standard input.
if [[ ! -t 0 ]]; then
    # STDIN from file or pipe.
    GU_STDIN_TTY=0
else
    # STDIN from terminal (tty).
    GU_STDIN_TTY=1
fi

# Check standard output and standard error; set
# ANSI escape codes used to colorize the messages
# (see https://stackoverflow.com/questions/5947742).
# NOTE: colors are disabled when stdout or stderr
#       are redirected to a file or a pipe.
if [[ ! -t 1 ]]; then
    # STDOUT to file or pipe.
    GU_STDOUT_TTY=0
    GU_STDOUT_RESET=''
    GU_STDOUT_GREEN=''
    GU_STDOUT_YELLOW=''
else
    # STDOUT to terminal (tty).
    GU_STDOUT_TTY=1
    GU_STDOUT_RESET='\e[0m'
    GU_STDOUT_GREEN='\e[1;32m'
    GU_STDOUT_YELLOW='\e[1;33m'
fi
if [[ ! -t 2 ]]; then
    # STDERR to file or pipe.
    #GU_STDERR_TTY=0
    GU_STDERR_RESET=''
    GU_STDERR_PURPLE=''
    GU_STDERR_RED=''
else
    # STDERR to terminal (tty).
    #GU_STDERR_TTY=1
    GU_STDERR_RESET='\e[0m'
    GU_STDERR_PURPLE='\e[1;35m'
    GU_STDERR_RED='\e[1;31m'
fi



# --- Helpers ------------------------------------------------------------------

warning()
{
    printf "\n${GU_STDERR_PURPLE}[WARNING] %s${GU_STDERR_RESET}\n\n" "$*" >&2
}


fatal_error()
{
    printf "\n${GU_STDERR_RED}[ERROR] %s${GU_STDERR_RESET}\n\n" "$*" >&2
    GU_FATAL_ERROR=1
    exit 1
}


show_usage_and_exit()
{
    cat <<EOF

Usage:
  ${0##*/} [options] [atom [atom ...]] [@set]

Arguments:
  atom is a valid Portage package atom (i.e. 'categoty/package' or simply
       'package' when unambiguous) optionally including a version or slot.

  @set can be @world, @system, @modules (i.e. external kernel modules) or
       any valid custom set declared in '/etc/portage/sets/'. If atoms and
       @set are specified together, atoms are processed first.

Options:
  -h  Display this help and exit.

  -s  Synchronize repositories: by default, repos are not synchronized
      when atoms or @set are specified; cannot be combined with -n.

  -n  Do not synchronize repositories: by default, repos are synchronized
      when no atoms or @set are specified; cannot be combined with -s.

  -f  Fetch required distfiles before install/upgrade/rebuild operations.

  -w  Add specified atoms or @set to list of explicit installed packages
      (by default, this script does not modify /var/lib/portage/world*).

  -J  Set jobs=1 in emerge; by default, rebuilding @system or @world with
      this option is not permitted; use -JJ to override such restriction.

  -p  Pretend mode (i.e. emerge preview only); synchronization follows the
      above rules (e.g., with explicit atoms or @set, sync requires -s).

  -r  Resume maintenance from the dependency-cleanup stage; cannot be
      combined with atoms, @set, or any other option listed above.

  -H  Ignore binhost: prevent network errors when the binhost shared
      folder is not available; all packages are emerged from sources.

Operation modes:
  ${0##*/} [-nfJH]
      PERFORM A FULL UPGRADE. Sync repos (unless disabled), emerge updated
      packages, run depclean, preserved rebuild, revdep rebuild, cleanups,
      etc-update and env-update. Also scan the local repo (if configured)
      for ebuild updates available in other installed repositories.

  ${0##*/} -p[nH]
      PREVIEW A FULL UPGRADE. Sync repos (unless disabled) and display all
      available package updates. Also scan the local repository for ebuild
      updates available in other installed repositories.

  ${0##*/} [-sfwJH] <atom [atom... [@set]] | @set>
      EMERGE PACKAGES AND SET (at least one argument is expected). Install,
      upgrade or rebuild the given atoms first, then all packages pulled in
      by the @set. Run some maintenance afterward (if only atoms are given,
      do not run depclean nor remove obsolete distfiles or binary packages).
      @system and @world are subject to the job restriction indicated above.

  ${0##*/} -p[sH] <atom [atom... [@set]] | @set>
      PREVIEW EMERGE OF PACKAGES AND SET. As above, but only display proposed
      builds (the given atoms first, then all packages pulled in by the @set).

  ${0##*/} -r[H]
      RESUME MAINTENANCE. Skip sync and package emerge operations, but resume
      following maintenance tasks (depclean, preserved rebuild, revdep-rebuild,
      cleanups, etc-update and env-update). Also scan the local repository for
      ebuild updates available in other installed repositories.

All operations involving the local repository are skipped if no local repository
is configured inside the script.

Examples:
  ${0##*/}
  ${0##*/} -p @world
  ${0##*/} sys-kernel/gentoo-kernel @modules
  ${0##*/} -w thunderbird
  ${0##*/} -r

EOF
    # Help (-h) should not be considered an error.
    exit 0
}



# --- Required cleanup actions -------------------------------------------------

# Return the state of a process.
# shellcheck disable=SC2329 # Called by terminate_active_command(),
# that is called by cleanup_on_exit(), that is invoked by trap on exit.
get_process_state()
{
    local pid=$1
    local state

    state=$(ps -o stat= -p "${pid}" 2>/dev/null) || state=''
    state=${state//[[:space:]]/}
    printf '%s' "${state}"
}


# Terminate the child process started by run_managed(). Descendants of the child
# (if any) are NOT terminated (Portage commands should be properly implemented).
# shellcheck disable=SC2329 # Called by cleanup_on_exit().
terminate_active_command()
{
    local pid=${GU_ACTIVE_CHILD_PID:-0}
    local state
    local i

    (( pid > 0 )) || return 0

    # Get state of a process. An empty result means that the process
    # no longer exists. A state beginning with Z indicates a zombie.
    # Zombie processes have already terminated and cannot be killed,
    # they only need to be collected by their parent using 'wait'.
    state=$(get_process_state "${pid}")
    if ! [[ -z ${state} || ${state} == Z* ]]; then

        # First attempt: graceful termination.
        kill -TERM "${pid}" 2>/dev/null || :

        # Allow up to 10 seconds for termination.
        for (( i = 0; i < 50; i++ )); do
            sleep 0.2

            # No process or zombie: termination has completed.
            state=$(get_process_state "${pid}")
            if [[ -z ${state} || ${state} == Z* ]]; then
                break
            fi
        done

        # If the process is still running, force termination.
        state=$(get_process_state "${pid}")
        if ! [[ -z ${state} || ${state} == Z* ]]; then
            warning "SIGTERM timeout, sending SIGKILL to PID ${pid}"
            kill -KILL "${pid}" 2>/dev/null || :
        fi
    fi

    # Wait for the child process to terminate (if it hasn't already).
    # Retrieve its exit status and allow Bash to handle the process's
    # conclusion, removing its corresponding "zombie" entry from the
    # process table. Ignore the exit status returned by `wait`, as the
    # child process might have been terminated via SIGTERM or SIGKILL.
    wait "${pid}" 2>/dev/null || :
    GU_ACTIVE_CHILD_PID=0
}


# Verify whether another process still holds the original flock lock.
# shellcheck disable=SC2329 # Called by cleanup_on_exit().
check_residual_lock()
{
    # Release the original lock reference held by the parent shell. NOTE:
    # we must first close FD 200 in the parent shell. Otherwise, the parent
    # itself would continue holding the lock and the verification would fail.
    exec 200>&-

    # Open the same lock file using a NEW file descriptor (201).
    if ! { exec 201>"${GU_LOCKFILE}"; } 2>/dev/null; then
        return 2
    fi

    # Attempt to acquire the lock using the new open file description.
    if flock -n 201; then
        # Release the verification lock.
        exec 201>&-
        return 0
    else
        # Release the verification lock.
        exec 201>&-
        return 1
    fi
}


# Perform required cleanups on exit (normal or by error or signal).
# shellcheck disable=SC2329             # Invoked indirectly by trap on exit.
cleanup_on_exit()
{
    local exit_code=$?                  # Exit code from the last executed command.

    (( GU_JOB_INTERRUPTED )) && printf '\n'

    # Disable installed traps.
    trap - EXIT INT TERM

    # Terminate the child, if any.
    terminate_active_command

    # Check whether a descendant still holds the script lock.
    # shellcheck disable=SC2310 # Failures handled.
    if ! check_residual_lock; then
        local lock_result=$?
        case ${lock_result} in
            1)  warning "Residual child lock detected"
                ;;
            2)  warning "Lock verification could not be completed"
                ;;
            *)  warning "Invalid lock_result: ${lock_result}"
                ;;
        esac
    fi

    # TODO - OTHER CLEANUP OPERATIONS GO HERE.
    # if [[ -d ${GU_PORTAGE_TMPDIR} ]]; then
    #     # ... clean GU_PORTAGE_TMPDIR/* ...
    # fi
    # emaint --fix cleanresume

    # Unmount GU_PKGDIR when the script terminates (only if the script mounted it).
    unmount_network_binhost_pkgdir

    # Display cause of exit when useful.
    if (( GU_JOB_INTERRUPTED )); then
        # shellcheck disable=SC2059     # Just static color codes.
        printf "\n${GU_STDERR_RED}Script interrupted${GU_STDERR_RESET}\n\n" >&2
    elif (( GU_FATAL_ERROR == 0 && exit_code != 0 )); then
        # shellcheck disable=SC2059     # Just static color codes.
        printf "\n${GU_STDERR_RED}Script terminated with code ${exit_code}${GU_STDERR_RESET}\n\n" >&2
    fi
    return "${exit_code}"
}



# --- Binhost network sharing --------------------------------------------------

# Check whether a given network mount point is defined in /etc/fstab. Return 0 if an
# active entry (i.e. not commented out) matches the specified mount point, 1 otherwise.
# It consider only NFS/NFS4 network filesystems (for a Gentoo binhost shoud be enought).
is_network_mount_defined()
{
    awk -v dir="$1" '
        # Skip commented lines, including those with leading whitespace.
        /^[[:space:]]*#/ { next }

        # Match the mount point and require an NFS filesystem type.
        NF >= 4 && $2 == dir && $3 ~ /^(nfs|nfs4)$/ { found = 1; exit }

        # Return success if a matching entry was found, failure otherwise.
        END { exit !found }
    ' /etc/fstab

    # Return the exit-code of awk.
}


# Unmount GU_PKGDIR when the script terminates (only if the script mounted it).
# This prevents local KDE Dolphin instances from freezing if the remote binhost
# is shut down. NOTE: if GU_PKGDIR was already mounted before the script started,
# it is assumed that root still needs it and is responsible for unmounting it.
unmount_network_binhost_pkgdir()
{
    if (( GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT )); then
        printf "\nNetwork folder '%s' mounted by this script, try to unmount" "${GU_PKGDIR}"
        if ! umount "${GU_PKGDIR}" >/dev/null 2>&1; then
        # TODO - add options -l -f:
        #if ! umount --lazy --force "${GU_PKGDIR}" >/dev/null 2>&1; then
        # NOTE: with --lazy --force the return code is always 0 unless not munted.
            warning 'Unmount of Gentoo binhost shared folder failed'
        else
            GU_NET_PKGDIR_MOUNTED=0
            printf '\nSucceed\n\n'
        fi
        GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT=0
    fi
}



# --- Get portage vars and repos -----------------------------------------------

# Populate the associative array GU_PORTAGE_VARS with the name and value
# of some portage variables: PKGDIR, PORTAGE_TMPDIR, EMERGE_DEFAULT_OPTS.
get_portage_vars()
{
    local output key value

    output=$(python3 - 2>/dev/null <<'EOF'
import sys
import portage

vars = (
    "PKGDIR",
    "PORTAGE_TMPDIR",
    "EMERGE_DEFAULT_OPTS"
)

for var in vars:
    value = portage.settings.get(var, "")
    print(f"{var}\t{value}")
EOF
    ) || fatal_error 'Function get_portage_vars() failed'

    while IFS=$'\t' read -r key value; do
        [[ -n "${key}" ]] && GU_PORTAGE_VARS["${key}"]="${value}"
    done <<< "${output}"
}


# Populate the associative array GU_PORTAGE_REPOS with the name and path
# of all installed portage repos (the repo name is the key, of course).
get_portage_repos()
{
    local output key value

    output=$(python3 - 2>/dev/null <<'EOF'
import sys
import portage

for repo in portage.settings.repositories:
    print(f"{repo.name}\t{repo.location}")
EOF
    ) || fatal_error 'Function get_portage_repos() failed'

    while IFS=$'\t' read -r key value; do
        [[ -n "${key}" ]] && GU_PORTAGE_REPOS["${key}"]="${value}"
    done <<< "${output}"
}



# --- Validate atoms and sets --------------------------------------------------

# Check allowed Gentoo sets.
validate_portage_set()
{
    local item
    local custom_sets=''

    case "${1}" in
        @world|@system|@modules)
            return 0
            ;;
        *)  for item in "${GU_CUSTOM_SETS[@]}"; do
                [[ "@${item}" == "${1}" ]] && return 0
                custom_sets+=", @${item}"
            done
            ;;
    esac
    fatal_error "Unknown set '${1}' (allowed: @world, @system, @modules${custom_sets})"
}


# Check Gentoo atoms (category/package or package). NOTE: use an internal emerge function
# (see https://github.com/gentoo/portage/blob/master/lib/_emerge/is_valid_package_atom.py).
# This only validates format (not existence of atom or package in Portage or other repos).
validate_portage_atom()
{
    local status=0

    # I don't know why, but is_valid_package_atom() considers valid an atom
    # ending in '-' which is clearly incorrect. So, filter out such atoms.
    if [[ "${1}" == *- ]]; then
        status=99
    else
        python3 - "${1}" 2>/dev/null <<'EOF' || status=$?
import sys
from _emerge.is_valid_package_atom import is_valid_package_atom

valid = is_valid_package_atom(sys.argv[1], allow_repo=True)
sys.exit(0 if valid else 99)
EOF
    fi
    case ${status} in
         0) ;;
        99) fatal_error "Invalid package atom '${1}'" ;;
         *) fatal_error 'Python function is_valid_package_atom() failed' ;;
    esac
}


# Validate the specified custom set. Returns: 0 if reasonably valid,
# 1 on errors in the python code, 99 if the set is empty or not valid.
validate_custom_set()
{
    [[ $# -eq 1 ]] || return 1

    python3 - "${1}" 2>/dev/null <<'EOF'
import re
import sys

from _emerge.is_valid_package_atom import is_valid_package_atom

nested_set_re = re.compile(r"@[A-Za-z0-9_-]+\Z")
found_valid_line = False

with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        line = line.split("#", 1)[0].strip()

        # Ignore comments and blank lines.
        if not line:
            continue

        # Validate nested sets.
        if line.startswith("@"):
            if not nested_set_re.fullmatch(line):
                sys.exit(99)
        else:
            # Reject atoms ending in '-'.
            if line.endswith("-"):
                sys.exit(99)

            # Require category/package format.
            if "/" not in line.split(":",1)[0]:
                sys.exit(99)

            # Validate atom.
            if not is_valid_package_atom(line, allow_repo=True):
                sys.exit(99)

        found_valid_line = True

# Empty sets and sets containing only comments are invalid.
sys.exit(0 if found_valid_line else 99)
EOF
}


# Populate GU_CUSTOM_SETS with names of valid custom sets.
get_valid_custom_sets()
{
    local pkg_sets set_name set_file status

    # Get all package sets defined in the system.
    if ! pkg_sets=$(emerge --list-sets); then
        fatal_error "Command 'emerge --list-sets' failed"
    fi

    # Loop over retrieved sets.
    while IFS= read -r set_name; do
        [[ -n "${set_name}" ]] || continue

        # Check if the set is a custom set.
        set_file=/etc/portage/sets/"${set_name}"
        [[ -f "${set_file}" ]] || continue

        # Parse and validate the custom set. Note that validate_custom_set() function can
        # return different exit codes, that are not all errors, so we must call it through
        # shellcheck disable=SC2310     # 'if' and the shellcheck warning must be disabled.
        if validate_custom_set "${set_file}"; then
            GU_CUSTOM_SETS+=("${set_name}")
        else
            status=$?

            # Discriminate an invalid set from errors in Python code.
            if (( status != 99 )); then
                fatal_error "Function validate_custom_set() failed"
            fi
        fi
    done <<< "${pkg_sets}"
}



# --- Run child ----------------------------------------------------------------

# Execute a command asynchronously, retain its PID, waits
# for the command to finish and returns its exit status.
run_managed()
{
    local exit_code

    if (( $# == 0 )); then
        fatal_error 'Missing arguments in function run_managed()'
    fi

    # Start the command in background. FD 200 is deliberately NOT
    # closed here (the child therefore inherits the parent's lock
    # descriptor). Also, explicitly preserve the parent's stdin
    # (without such redirection, Bash would connect stdin of the
    # async commands to /dev/null and emerge --ask will fail).
    "$@" <&0 &

    # Save the PID of the child.
    GU_ACTIVE_CHILD_PID=$!

    # Wait for the child to terminate. On signals SIGINT/SIGTERM
    # the function cleanup_on_exit() will handle the active child.
    if wait "${GU_ACTIVE_CHILD_PID}"; then
        exit_code=0
    else
        exit_code=$?
    fi

    GU_ACTIVE_CHILD_PID=0
    return "${exit_code}"
}



# --- Sync repos ---------------------------------------------------------------

# If allowed, sync Gentoo and other enabled repos. NOTE:
# when redirected to file or pipe, perform a silent sync.
sync_gentoo_and_other_repos()
{
    if (( GU_SYNC_REPOS )); then
        if (( GU_STDOUT_TTY )); then
            printf '\nSYNCING REPOS\n-------------\n\n'
            # shellcheck disable=SC2310 # Failures handled.
            if ! run_managed emerge --sync --ask=n; then
                fatal_error "Command 'emerge --sync' failed"
            fi
            printf '\n\n'
        else
            # Silent sync.
            # shellcheck disable=SC2310 # Failures handled.
            if ! run_managed emerge --sync --ask=n >/dev/null 2>&1; then
                fatal_error "Command 'emerge --sync' failed"
            fi
        fi

        # TODO - is eix still useful? If so and used,
        # update the list of installed packages. See:
        # https://forums.gentoo.org/viewtopic-t-1089544-start-0.html
        # https://wiki.gentoo.org/wiki/Gentoo_Cheat_Sheet
        # https://wiki.gentoo.org/wiki/Eix
        #eix-update
    fi
}



# --- Pretend emerges ----------------------------------------------------------

pretend_emerge()
{
    # shellcheck disable=SC2310 # Failures handled.
    if ! run_managed emerge -pv "$@"; then
        local rc=$?
        fatal_error "Command 'emerge -pv $*' failed with exit code ${rc}"
    fi
    return 0
}


pretend_emerge_sysupdate()
{
    printf '\nAVAILABLE UPDATES\n-----------------\n'
    pretend_emerge -uDN "${GU_EMERGE_OPTIONS[@]}" @world
    printf '\n\n'
}


pretend_emerge_atoms_set()
{
    if (( ${#GU_PKG_ARGS[@]} )); then
        printf '\nUPDATES/REBUILDS (PKGS)\n-----------------------\n'
        pretend_emerge "${GU_EMERGE_OPTIONS[@]}" "${GU_PKG_ARGS[@]}"
        printf '\n\n'
    fi

    if (( ${#GU_SET_ARGS[@]} )); then
        printf '\nUPDATES/REBUILDS (SET)\n----------------------\n'
        for set in "${GU_SET_ARGS[@]}"; do
            case "${set}" in
                @world|@system)
                    pretend_emerge -e "${GU_EMERGE_OPTIONS[@]}" "${set}"
                    ;;
                @modules)
                    pretend_emerge "${GU_EMERGE_OPTIONS[@]}" "@module-rebuild"
                    ;;
                *)  pretend_emerge "${GU_EMERGE_OPTIONS[@]}" "${set}"
                    ;;
            esac
            printf '\n\n'
        done
    fi
}



# --- True emerges -------------------------------------------------------------

run_fetch()
{
    # shellcheck disable=SC2310 # Failures handled.
    if ! run_managed emerge -f --jobs=1 "$@"; then
        fatal_error "Fetch of distfiles failed"
    fi
    return 0
}


# Get the packages to emerge and perform the build if the user allow
# it. NOTE: the first argument passed to this function is a reference
# to a variable (in which the number of completed merges is returned).
run_emerge()
{
    local rc offset=0 pkgs=0
    local logfile=/var/log/emerge.log
    local -n outref=$1
    shift

    # Save the initial logfile size (if the logfile exists; if not, its size
    # is 0). The logfile is used to determine how many merges are completed.
    if [[ -f "${logfile}" ]]; then
        offset=$(stat -c %s "${logfile}") ||
        fatal_error "Command 'stat' failed in run_emerge()"
    fi

    # Emerge exit code:
    #
    # - 130: 'emerge' interrupted by the user at the Y/N confirmation prompt;
    # -   1: any other error (invalid atoms, failed merges, ...);
    # -   0: all merges completed successfully.
    #
    # NOTE: Builds may continue despite failures (especially with --keep-going
    # option set in EMERGE_DEFAULT_OPTS). Also, the exit code will be 1 if any
    # ebuild fails, regardless of how many merges succeed, so it cannot indicate
    # how many packages were successfully build. We must use the logfile for that.

    # shellcheck disable=SC2310 # Failures handled.
    if run_managed emerge "$@"; then
        rc=0
    else
        rc=$?
    fi

    # Check if the emerge was aborted by user on Y/N confirmation (-a option).
    if (( rc == 130 )); then
        warning "Aborted by user"
        exit 0
    fi

    # Use the logfile to count completed merges recorded since the emerge start.
    if [[ -f "${logfile}" ]]; then
        if ! pkgs=$(
            tail -c "+$((offset + 1))" "${logfile}" |
            awk '/::: completed emerge/ { n++ } END { print n+0 }'
        ); then
            fatal_error "Failed to count completed merges in run_emerge()"
        fi
    else
        fatal_error "Log file '${logfile}' not found in run_emerge()"
    fi

    # Fail if emerge failed and no merges completed.
    if (( rc != 0 && pkgs == 0 )); then
        fatal_error "Command 'emerge $*' failed with exit code ${rc}"
    fi

    # Report also partial failures (as warning).
    if (( rc != 0 )); then
        warning "Emerge returned exit code ${rc}, but ${pkgs} merges completed"
        GU_INCOMPLETE_BUILD=1
    fi

    # Return the number of packages emerged through the output variable.
    # shellcheck disable=SC2034  # Var passed by reference (Bash 4.3+).
    outref=${pkgs}
    return 0
}


run_emerge_sysupdate()
{
    local npkgref

    # Fetch first.
    if (( GU_FETCH_FIRST )); then
        printf '\nDOWNLOADING DISTFILES\n---------------------\n'
        run_fetch -uN @world
        printf '\n'
    fi

    # Emerge: return the number of packages
    printf '\nEMERGING PACKAGES\n-----------------\n'
    run_emerge npkgref -avuDN "${GU_EMERGE_OPTIONS[@]}" @world
    printf '\n'

    # If no packages were emerged, skip maintenance.
    # Jump to check the local repository, then exit.
    if (( npkgref )); then
        printf '\n'
    else
       GU_SKIP_ECLEAN=1
       GU_SKIP_DEPCLEAN=1
       GU_SKIP_BROKEN_CHECK=1
       GU_SKIP_UPDATE_ENV_ETC=1
       GU_SKIP_PATCH_DESKTOPFILES=1
       GU_SKIP_FINAL_MSG=1
    fi
}


run_emerge_atoms_set()
{
    local select_opt=''
    local npkgref totalpkgs=0

    # Fetch first.
    if (( GU_FETCH_FIRST )); then
        printf '\nDOWNLOADING DISTFILES\n---------------------\n'
        if (( ${#GU_PKG_ARGS[@]} )); then
            run_fetch "${GU_PKG_ARGS[@]}"
        fi
        if (( ${#GU_SET_ARGS[@]} )); then
            for set in "${GU_SET_ARGS[@]}"; do
                case "${set}" in
                    @world|@system)
                        run_fetch -e "${set}"
                        ;;
                    @modules)
                        run_fetch '@module-rebuild'
                        ;;
                    *)  run_fetch "${set}"
                        ;;
                esac
            done
        fi
        printf '\n\n'
    fi

    # Determine if atoms/custom sets must be added to world set.
    if (( GU_ADD_TO_WORLD )); then
        select_opt='-w'
    else
        select_opt='-1'
    fi

    # By default skip some maintenance operations.
    GU_SKIP_ECLEAN=1
    GU_SKIP_DEPCLEAN=1
    GU_SKIP_BROKEN_CHECK=1
    GU_SKIP_CHECK_LOCAL=1

    # Emerge atom(s).
    if (( ${#GU_PKG_ARGS[@]} )); then
        printf '\nINSTALL/UPDATES/REBUILDS (PKGS)\n-------------------------------\n'
        run_emerge npkgref -av "${select_opt}" "${GU_EMERGE_OPTIONS[@]}" "${GU_PKG_ARGS[@]}"
        (( totalpkgs += npkgref )) || :
        printf '\n\n'
    fi

    # Emerge set.
    if (( ${#GU_SET_ARGS[@]} )); then
        printf '\nINSTALL/UPDATES/REBUILDS (SET)\n------------------------------\n'
        for set in "${GU_SET_ARGS[@]}"; do
            case "${set}" in
                @world|@system)
                    run_emerge npkgref -ave "${GU_EMERGE_OPTIONS[@]}" "${set}"
                    GU_SKIP_DEPCLEAN=0
                    GU_SKIP_ECLEAN=0
                    ;;
                @modules)
                    run_emerge npkgref -av "${GU_EMERGE_OPTIONS[@]}" '@module-rebuild'
                    ;;
                *)  run_emerge npkgref -av "${select_opt}" "${GU_EMERGE_OPTIONS[@]}" "${set}"
                    ;;
            esac
            (( totalpkgs += npkgref )) || :
            printf '\n\n'
        done
    fi

    # If no packages were emerged, skip other maintenance sections.
    if (( totalpkgs )); then
        printf '\n'
    else
        GU_SKIP_UPDATE_ENV_ETC=1
        GU_SKIP_PATCH_DESKTOPFILES=1
        GU_SKIP_FINAL_MSG=1
    fi
}



# --- Scan local repo for updates ----------------------------------------------

# Get the max ebuild version in '$1' (excluding -9999*). If
# no ebuild is found (other than *-9999*) return 0 in outref.
get_max_ebuild_version()
{
    local -n outref=$1
    local file filename max_ver ver

    max_ver=0
    for file in "${2}"/*.ebuild; do
        [[ -f "${file}" ]] || continue
        filename=${file##*/}
        if [[ ! "${filename}" =~ -([0-9].*)\.ebuild$ ]]; then
            fatal_error "Cannot extract version from '${file}'"
        fi

        # BASH_REMATCH is a special GLOBAL array variable that stores the results
        # of captured groups in regular expression matchings using the =~ operator.
        # Being global, it is modified by any subsequent match: function "ver_test"
        # could alter BASH_REMATCH, so we must save the result of the matched group
        # ([0-9].*) before calling "ver_test". Note: captured groups starts from 1.
        ver="${BASH_REMATCH[1]}"

        # Skip live ebuilds.
        if [[ "${ver}" != 9999* ]]; then
            if ver_test "${max_ver}" '-lt' "${ver}"; then
                max_ver="${ver}"
            fi
        fi
    done

    # Return the ebuild max version found through the output variable.
    # shellcheck disable=SC2034  # Var passed by reference (Bash 4.3+).
    outref=${max_ver}
    return 0
}


# Get the max ebuild version in '$1' (from $GU_LOCAL_REPO and excluding
# -9999*) and checks whether the same version exists in $GU_GENTOO_REPO or
# whether a new version exists in any repository (excluding $GU_LOCAL_REPO).
search_updated_ebuild()
{
    local pkg ctg repo l_max_ver r_max_ver

    # Get package name and category.
    pkg="${1##*/}"
    ctg="${1%/*}"
    ctg=${ctg##*/}

    # Dirs 'metadata' and 'profile' must be escluded (they may
    # have subdirs, but such subdirs do not contain ebuilds).
    [[ "${ctg}" == 'metadata' || "${ctg}" == 'profiles' ]] && return 0

    # Get latest version in local repo (excluding -9999*),
    get_max_ebuild_version l_max_ver "${1}"

    # Skip packages with only live ebuild.
    [[ "${l_max_ver}" == "0" ]] && return 0

    # Scan other installed repos for the same package.
    for repo in "${GU_PORTAGE_REPOS[@]}"; do
        if [[ "${repo}" != "${GU_LOCAL_REPO}" ]]; then
            if [[ -d "${repo}/${ctg}/${pkg}" ]]; then

                # Get latest version in scanned repo (excluding -9999*).
                get_max_ebuild_version r_max_ver "${repo}/${ctg}/${pkg}"

                # Compare latest version in local repo with latest version in scanned repo.
                if ver_test "${r_max_ver}" '-gt' "${l_max_ver}" ; then
                    printf "\n  %s/%s-%s\n" "${ctg}" "${pkg}" "${l_max_ver}"
                    printf "    version %s in '%s'\n" "${r_max_ver}" "${repo##*/}"
                elif [[ "${repo}" == "${GU_GENTOO_REPO}" ]]; then
                    if ver_test "${r_max_ver}" "-eq" "${l_max_ver}" ; then
                        printf "\n  %s/%s-%s\n" "${ctg}" "${pkg}" "${l_max_ver}"
                        printf "    same version in 'gentoo'\n"
                    fi
                fi
            fi
        fi
    done
    return 0
}


# Scans all atoms (i.e. packages) from $GU_LOCAL_REPO (see above):
# selects the latest version of the parsed atom and checks whether
# the same version exists in $GU_GENTOO_REPO or whether a new version
# exists in any repository (excluding $GU_LOCAL_REPO of course).
check_local_repo_updates()
{
    if [[ -n "${GU_LOCAL_REPO}" ]]; then
        printf '\nPOSSIBLE UPDATES FOR LOCAL EBUILDS\n----------------------------------\n'
        for dir in "${GU_LOCAL_REPO}"/*/*; do
            if [[ -d "${dir}" ]]; then
                search_updated_ebuild "${dir}"
            fi
        done
        printf '\n'
    fi
}



# --- Privileges ---------------------------------------------------------------

# Ensure the script is run with root privileges. NOTE: the 'id' command
# is provided by 'GNU Coreutils', 'BusyBox', or other essential system
# packages, and is generally available on all major Linux distributions,
# as well as on other Unix-like systems (*BSD, macOS, Solaris, AIX, QNX).
# This is preferable to using the EUID variable (which is easily altered).
GU_CMD_ID='/usr/bin/id'
if [[ -x ${GU_CMD_ID} ]]; then
    if ! GU_USERID=$(${GU_CMD_ID} -u); then
        fatal_error "Command '${GU_CMD_ID}' failed to run"
    fi
    (( GU_USERID )) && fatal_error 'This script needs root privileges'
else
    fatal_error "Command '${GU_CMD_ID}' not available"
fi



# --- Locking ------------------------------------------------------------------

# Use flock, that is an external command provided by sys-apps/util-linux. Note:
# with flock, there is no need to delete the lock file: the lock is associated
# with the open file descriptor, not the existence of the file itself; removing
# this lock file can cause issues, if other processes already have it open.
GU_LOCKFILE='/run/gentoo-update.lock'

# Prevent two instances of this script from running concurrently. The flock
# command holds the advisory lock on file descriptor 200 for the lifetime of
# the script; it is released automatically when the fd is closed on exit.
if ! { exec 200>"${GU_LOCKFILE}"; } 2>/dev/null; then
    fatal_error "Cannot open lock file '${GU_LOCKFILE}'"
fi
if ! flock -n 200; then
    fatal_error 'Another instance (or a child) of this script is still running'
fi

# Also, check whether a Portage operation is already in progress.
# Naturally, we cannot prevent other Portage operations from being
# started in other terminals after this script has begun execution,
# but we trust the administrator's knowledge and common sense!
if pgrep -f '(^|/)(emerge|emerge-webrsync|ebuild|emaint|revdep-rebuild(\.sh)?|eclean)([[:space:]]|$)' >/dev/null; then
    fatal_error 'Detected another Portage operation in progress'
fi



# --- Cleanup / Trap -----------------------------------------------------------

# Install signal handlers and EXIT trap.
# Previous failures do not require cleanups.
trap 'cleanup_on_exit' EXIT
trap 'GU_JOB_INTERRUPTED=1; exit 130' INT
trap 'GU_JOB_INTERRUPTED=1; exit 143' TERM



# --- Get portage variables ----------------------------------------------------

get_portage_vars

GU_PKGDIR=${GU_PORTAGE_VARS['PKGDIR']-}
GU_PORTAGE_TMPDIR=${GU_PORTAGE_VARS['PORTAGE_TMPDIR']-}
GU_EMERGE_DEFAULT_OPTS=${GU_PORTAGE_VARS['EMERGE_DEFAULT_OPTS']-}

# PKGDIR and PORTAGE_TMPDIR should be always defined (however, PKGDIR folder
# may not exist). EMERGE_DEFAULT_OPTS may be empty. See make.conf(5) manpage.
[[ -n "${GU_PKGDIR}" ]] || fatal_error 'Invalid PKGDIR'
[[ -n "${GU_PORTAGE_TMPDIR}" && -d "${GU_PORTAGE_TMPDIR}" ]] ||
    fatal_error "Invalid PORTAGE_TMPDIR ('${GU_PORTAGE_TMPDIR}')"



# --- Get repositories ---------------------------------------------------------

# NOTE: Only repos configured in /etc/portage/repos.conf are returned.

get_portage_repos

GU_GENTOO_REPO=${GU_PORTAGE_REPOS['gentoo']-}
[[ -n "${GU_GENTOO_REPO}" && -d "${GU_GENTOO_REPO}" ]] ||
    fatal_error "Gentoo repository is missing or invalid ('${GU_GENTOO_REPO}')"

GU_LOCAL_REPO=""
if [[ -n "${GU_LOCAL_REPO_NAME}" ]]; then
    GU_LOCAL_REPO=${GU_PORTAGE_REPOS["${GU_LOCAL_REPO_NAME}"]-}
    [[ -n "${GU_LOCAL_REPO}" ]] || fatal_error "Repo '${GU_LOCAL_REPO_NAME}' not found"
    [[ -d "${GU_LOCAL_REPO}" ]] || fatal_error "Path '${GU_LOCAL_REPO}' not found"
fi

# Import the 'ver_test' function.
GU_VER_TEST_SCRIPT="${GU_GENTOO_REPO}/eclass/${GU_VER_TEST_REL_PATH}"
[[ -f "${GU_VER_TEST_SCRIPT}" ]] || fatal_error "Script '${GU_VER_TEST_SCRIPT}' not found"
# shellcheck disable=SC1090     # Ignore the imported script; Gentoo devs know their stuff.
source "${GU_VER_TEST_SCRIPT}" || fatal_error "Failed to source '${GU_VER_TEST_SCRIPT}'"



# --- Get custom sets ----------------------------------------------------------

# Try to determine custom sets automatically (only valid custom sets
# are included into the list). Note also that they can be completely
# disabled with GU_CUSTOM_SETS=(''), see the Configuration section.

if (( ${#GU_CUSTOM_SETS[@]} == 0 )); then
    get_valid_custom_sets
elif [[ "${GU_CUSTOM_SETS[0]}" == '' ]]; then
    GU_CUSTOM_SETS=()
fi



# --- Main code ----------------------------------------------------------------

# Parsing options.
while getopts ':hsnfwprJH' opt; do
    case "${opt}" in
        h) show_usage_and_exit
           ;;
        s) GU_FORCE_SYNC_REPOS=1
           ;;
        n) GU_FORCE_NOSYNC_REPOS=1
           ;;
        f) GU_FETCH_FIRST=1
           ;;
        w) GU_ADD_TO_WORLD=1
           ;;
        p) GU_PRETEND_ONLY_MODE=1
           ;;
        r) GU_RESUME_FROM_DEPCLEAN=1
           ;;
        J) ((++GU_FORCE_ONE_JOB))
           ;;
        H) GU_IGNORE_BINHOST=1
           ;;
        :) fatal_error "Option '-${OPTARG}' requires an argument (use -h for help)"
           ;;
        *) fatal_error "Invalid option '-${OPTARG}' (use -h for help)"
           ;;
    esac
done
shift $((OPTIND - 1))

# Parsing arguments.
for arg in "$@"; do
    if [[ "${arg}" == @* ]]; then
        validate_portage_set "${arg}"
        GU_SET_ARGS+=("${arg}")
    else
        validate_portage_atom "${arg}"
        GU_PKG_ARGS+=("${arg}")
    fi
done

# Validate option combinations.
if (( GU_FORCE_NOSYNC_REPOS && GU_FORCE_SYNC_REPOS )); then
    fatal_error 'Options -n and -s cannot be combined together'
fi
if (( GU_RESUME_FROM_DEPCLEAN )); then
    if (( GU_ADD_TO_WORLD + GU_FETCH_FIRST + GU_FORCE_SYNC_REPOS + GU_FORCE_NOSYNC_REPOS + \
          GU_FORCE_ONE_JOB + GU_PRETEND_ONLY_MODE + ${#GU_PKG_ARGS[@]} + ${#GU_SET_ARGS[@]} )); then
        fatal_error 'Option -r cannot be combined with other options (except -H), atoms or sets'
    fi
elif (( GU_PRETEND_ONLY_MODE )); then
    if (( GU_ADD_TO_WORLD + GU_FETCH_FIRST + GU_FORCE_ONE_JOB )); then
        fatal_error 'Options -f, -w and -J cannot be combined with -p (pretend mode)'
    fi
    if (( ${#GU_PKG_ARGS[@]} + ${#GU_SET_ARGS[@]} )); then
        if (( GU_FORCE_NOSYNC_REPOS )); then
            warning 'Option -n ignored (sync disabled by default when atoms or sets are provided)'
        fi
        (( GU_FORCE_SYNC_REPOS )) && GU_SYNC_REPOS=1
    else
        if (( GU_FORCE_SYNC_REPOS )); then
            warning 'Option -s ignored (sync enabled by default when no atoms or sets are provided)'
        fi
        (( ! GU_FORCE_NOSYNC_REPOS )) && GU_SYNC_REPOS=1
    fi
else  # TRUE EMERGE.
    if (( ${#GU_PKG_ARGS[@]} + ${#GU_SET_ARGS[@]} )); then
        if (( GU_FORCE_NOSYNC_REPOS )); then
            warning 'Option -n ignored (sync disabled by default when atoms or sets are provided)'
        fi
        (( GU_FORCE_SYNC_REPOS )) && GU_SYNC_REPOS=1
    else
        if (( GU_ADD_TO_WORLD )); then
            fatal_error 'Option -w can be used only when atoms or custom sets are provided'
        fi
        if (( GU_FORCE_SYNC_REPOS )); then
            warning 'Option -s ignored (sync enabled by default when no atoms or sets are provided)'
        fi
        (( ! GU_FORCE_NOSYNC_REPOS )) && GU_SYNC_REPOS=1
    fi
fi

# Option -w cannot be used with system sets, only with custom sets.
if (( GU_ADD_TO_WORLD)); then
    for set in "${GU_SET_ARGS[@]}"; do
        case "${set}" in
            @world|@system|@modules)
                fatal_error 'Option -w can be used only with custom sets'
                ;;
            *)  ;;
        esac
    done
fi

# A single -J is forbidden with sets @world and @system.
if (( GU_FORCE_ONE_JOB == 1 )); then
    for set in "${GU_SET_ARGS[@]}"; do
        case "${set}" in
            @world|@system)
                fatal_error "Set '${set}' needs -JJ (beware: it may significantly increase build time)"
                ;;
            *)  ;;
        esac
    done
fi

# Only one set is permitted. NOTE: This script can handle multiple sets, but I  prefer
# to allow only one at a time. Comment out these lines if you don't want this restriction.
if (( ${#GU_SET_ARGS[@]} > 1 )); then
    fatal_error 'Only one set at a time is allowed'
fi

# Set emerge options. NOTE: -w option (add packages to world set) is
# not considered here, but in individual emerge tasks (when required).
if (( GU_FORCE_ONE_JOB )); then
    GU_EMERGE_OPTIONS+=('--jobs=1')
fi
if (( GU_STDOUT_TTY )); then
    # STDOUT to terminal (tty). We don't need to check STDERR.
    GU_EMERGE_OPTIONS+=('--color=y')
    if (( ! GU_STDIN_TTY )); then
        fatal_error 'Redirection from pipe or file not permitted (requires interaction)'
    fi
else
    # STDOUT to file or pipe.
    GU_EMERGE_OPTIONS+=('--color=n')
    if (( ! GU_PRETEND_ONLY_MODE )); then
        fatal_error 'Redirection to pipe or file is permitted only in pretend mode (-p)'
    fi
fi

# Check if the packages are installed from a binary repo and more specifically from a
# network folder (shared by a Gentoo binhost); if so, and such folder is not mounted on
# the current host, try to mount it and if it fails stop the script and display the error.
if [[ -d "${GU_PKGDIR}" && ${GU_IGNORE_BINHOST} == 0 ]]; then
    if printf '%s' "${GU_EMERGE_DEFAULT_OPTS}" | grep -qwE -- '-k|--usepkg'; then
        # Look for binhost shared folder. Note that is_network_mount_defined() function can
        # return different exit codes, that are not all errors, so we must call it through
        # shellcheck disable=SC2310     # 'if' and the shellcheck warning must be disabled.
        if is_network_mount_defined "${GU_PKGDIR}"; then
            if ! mountpoint -q "${GU_PKGDIR}"; then
                printf "\nNetwork folder '%s' not yet mounted, try to mount" "${GU_PKGDIR}"
                if ! mount "${GU_PKGDIR}" >/dev/null 2>&1; then
                    fatal_error 'Mount of Gentoo binhost shared folder failed (use -H to ignore)'
                fi
                printf '\nSucceed\n\n'
                GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT=1
            fi
            GU_NET_PKGDIR_MOUNTED=1
        fi
    fi
fi

# ONLY FOR DEBUG.
if (( GU_DEBUG )); then
    printf '\nDEBUG\n-----\n'
    printf '%-40s %s\n' 'GU_SYNC_REPOS' "${GU_SYNC_REPOS}"
    printf '%-40s %s\n' 'GU_FETCH_FIRST' "${GU_FETCH_FIRST}"
    printf '%-40s %s\n' 'GU_ADD_TO_WORLD' "${GU_ADD_TO_WORLD}"
    printf '%-40s %s\n' 'GU_SKIP_ECLEAN' "${GU_SKIP_ECLEAN}"
    printf '%-40s %s\n' 'GU_SKIP_DEPCLEAN' "${GU_SKIP_DEPCLEAN}"
    printf '%-40s %s\n' 'GU_FORCE_ONE_JOB' "${GU_FORCE_ONE_JOB}"
    printf '%-40s %s\n' 'GU_FORCE_SYNC_REPOS' "${GU_FORCE_SYNC_REPOS}"
    printf '%-40s %s\n' 'GU_FORCE_NOSYNC_REPOS' "${GU_FORCE_NOSYNC_REPOS}"
    printf '%-40s %s\n' 'GU_RESUME_FROM_DEPCLEAN' "${GU_RESUME_FROM_DEPCLEAN}"
    printf '%-40s %s\n' 'GU_PRETEND_ONLY_MODE' "${GU_PRETEND_ONLY_MODE}"
    printf '%-40s %s\n' 'GU_EMERGE_OPTIONS' "${GU_EMERGE_OPTIONS[*]}"
    printf '%-40s %s\n' 'GU_PKG_ARGS' "${GU_PKG_ARGS[*]}"
    printf '%-40s %s\n' 'GU_SET_ARGS' "${GU_SET_ARGS[*]}"
    printf '%-40s %s\n' 'GU_NET_PKGDIR_MOUNTED' "${GU_NET_PKGDIR_MOUNTED}"
    printf '%-40s %s\n' 'GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT' "${GU_NET_PKGDIR_MOUNTED_BY_THIS_SCRIPT}"
    printf '%-40s %s\n' 'GU_GENTOO_REPO' "${GU_GENTOO_REPO}"
    printf '%-40s %s\n' 'GU_LOCAL_REPO' "${GU_LOCAL_REPO}"
    printf '%-40s %s\n' 'Portage variables' '-------------------'
    printf '  %-38s %s\n' 'PKGDIR' "${GU_PKGDIR}"
    printf '  %-38s %s\n' 'PORTAGE_TMPDIR' "${GU_PORTAGE_TMPDIR}"
    printf '  %-38s %s\n' 'EMERGE_DEFAULT_OPTS' "${GU_EMERGE_DEFAULT_OPTS}"
    printf '%-40s %s\n' 'Installed repos' '-------------------'
    for name in "${!GU_PORTAGE_REPOS[@]}"; do
        printf '  %-38s %s\n' "${name}" "${GU_PORTAGE_REPOS[${name}]}"
    done
    printf '\n\n'
fi

# Sync repos, download distfiles, perform emerges.
if (( ! GU_RESUME_FROM_DEPCLEAN )); then

    # Sync repos (if allowed).
    sync_gentoo_and_other_repos

    # Pretend mode?
    if (( GU_PRETEND_ONLY_MODE )); then

        # Yes, skip whole maintenance section.
        GU_SKIP_ECLEAN=1
        GU_SKIP_DEPCLEAN=1
        GU_SKIP_BROKEN_CHECK=1
        GU_SKIP_UPDATE_ENV_ETC=1
        GU_SKIP_PATCH_DESKTOPFILES=1
        GU_SKIP_CHECK_LOCAL=1
        GU_SKIP_FINAL_MSG=1

        # Atoms o sets specified?
        if (( ${#GU_PKG_ARGS[@]} + ${#GU_SET_ARGS[@]} )); then

            # Yes, display only pretended emerges for them.
            pretend_emerge_atoms_set

        else
            # No, display all system updates.
            pretend_emerge_sysupdate

            # Also reenable scanning for possible
            # updates of ebuilds in personal repo.
            GU_SKIP_CHECK_LOCAL=0
        fi

    # True install/update/rebuild. Atoms o sets specified?
    elif (( ${#GU_PKG_ARGS[@]} + ${#GU_SET_ARGS[@]} )); then

        # Yes, emerge only them. NOTE: maintenance sections to
        # be skipped depend on what was actually built; therefore,
        # they are defined directly within the following function.
        run_emerge_atoms_set

    else
        # No, perform full upgrade. NOTE: maintenance sections to
        # be skipped depend on what was actually built; therefore,
        # they are defined directly within the following function.
        run_emerge_sysupdate
    fi
fi

# If allowed, remove unused and superceded packages (if any).
if (( ! GU_SKIP_DEPCLEAN )); then
    printf '\nPERFORMING DEPCLEAN\n-------------------\n'
    # shellcheck disable=SC2310 # Failures handled.
    if ! run_managed emerge --ask=n --depclean; then
        fatal_error "Command 'emerge --depclean' failed"
    fi
    printf '\n\n'
fi

# If allowed, rebuild broken packages (if any).
if (( ! GU_SKIP_BROKEN_CHECK )); then
    printf '\nREBUILDING BROKEN PACKAGES\n--------------------------\n'
    # shellcheck disable=SC2310 # Failures handled.
    if ! run_managed emerge --ask=n @preserved-rebuild; then
        fatal_error "Command 'emerge @preserved-rebuild' failed"
    fi
    printf '\n'
    # shellcheck disable=SC2310 # Failures handled.
    if ! run_managed revdep-rebuild; then
        fatal_error "Command 'revdep-rebuild' failed"
    fi
    printf '\n\n'
fi

# If allowed, remove unused and superceded packages. NOTE: without the -d option
# eclean removes every package that does not have an ebuild in the tree; with -d
# (--deep), eclean removes all packages that are not more installed on the host.
if (( ! GU_SKIP_ECLEAN )); then
    printf '\nREMOVING OUTDATED DISTFILES\n---------------------------\n\n'
    eclean -d distfiles || fatal_error "Command 'eclean -d distfiles' failed"
    printf '\n\n'

    # Skip binary-package cleanup when PKGDIR is mounted:
    # the binhost is responsible to clean binary archives.
    if (( ! GU_NET_PKGDIR_MOUNTED )); then
        printf '\nREMOVING OUTDATED BINARY PACKAGES\n---------------------------------\n\n'
        if [[ -n "${GU_PKGDIR}" ]]; then
            eclean -d packages || fatal_error "Command 'eclean -d packages' failed"
        fi
        printf '\n\n'
    fi
fi

# If allowed, update environment and configuration files (/etc/*).
if (( ! GU_SKIP_UPDATE_ENV_ETC )); then
    printf '\nUPDATING CONFIGURATION\n----------------------\n\n'
    env-update || fatal_error "Command 'env-update' failed"
    etc-update || fatal_error "Command 'etc-update' failed"
    printf '\n\n'
fi

# If allowed, patch menu desktop files.
if (( ! GU_SKIP_PATCH_DESKTOPFILES )); then
    if [[ -n "${GU_PATCH_MENU_SCRIPT}" && -x "${GU_PATCH_MENU_SCRIPT}" ]]; then
        printf '\nPATCHING DESKTOPFILES\n---------------------\n'
        "${GU_PATCH_MENU_SCRIPT}" || fatal_error "Script '${GU_PATCH_MENU_SCRIPT}' failed"
        printf '\n'
    fi
fi

# If allowed, scan for possible updates of ebuilds in personal repo.
if (( ! GU_SKIP_CHECK_LOCAL )); then
    check_local_repo_updates
fi

# Unmount GU_PKGDIR when the script terminates (only if the script mounted it).
unmount_network_binhost_pkgdir

# If allowed, tell the user to source '/etc/profile'
# (unfortunately it cannot be done inside the script).
if (( ! GU_SKIP_FINAL_MSG )); then
    if (( GU_INCOMPLETE_BUILD )); then
        warning 'Incomplete build, see emerge logs'
    else
        printf '\n'
    fi

    # shellcheck disable=SC2059  # Just static color codes.
    {
    printf "${GU_STDOUT_GREEN}Done.\nIf packages were built, run "
    printf "'${GU_STDOUT_YELLOW}source /etc/profile${GU_STDOUT_GREEN}' "
    printf "in any open shell or reboot the system.${GU_STDOUT_RESET}\n\n"
    }
fi
exit 0
