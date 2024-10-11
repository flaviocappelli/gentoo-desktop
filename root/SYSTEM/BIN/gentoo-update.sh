#!/bin/bash
#
# Released under MIT License
# Copyright (c) 2024 Flavio Cappelli
# Version 1.0
#
# Automate (as much as possible) the upgrade of a Gentoo system.
# This script can also be invoked in "pretend mode", that can be
# useful to check for updates in cron or through a systemd timer.


# Location of Gentoo & other repos (see /etc/portage/repos.conf). Note
# that the related paths must not contain spaces. To create a personal
# repo see https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository
REPOS_ROOT=/var/db/repos
GENTOO_REPO=${REPOS_ROOT}/gentoo
PERSONAL_REPO=${REPOS_ROOT}/local

# Path to the script that defines the Gentoo bash function 'ver_test'
# (version comparison). Many eclasses (files in $GENTOO_REPO/eclass/)
# and ebuilds depend on 'ver_test', so I'm sure it will be kept for a
# long time (note that 'ver_test' was previously defined in the eclass
# 'eapi7-ver'; if moved again, we just need to update VER_TEST_SCRIPT).
VER_TEST_SCRIPT=${GENTOO_REPO}/eclass/tests/version-funcs.sh

# Perform some safety checks.
if [ ! -d ${GENTOO_REPO} ]; then
    echo -e "\nError: \"${GENTOO_REPO}\" not found!\n"
    exit 1
fi
if [ ! -d ${PERSONAL_REPO} ]; then
    echo -e "\nError: \"${PERSONAL_REPO}\" not found!\n"
    exit 1
fi
if [ ! -e ${VER_TEST_SCRIPT} ]; then
    echo -e "\nError: \"${VER_TEST_SCRIPT}\" not found!\n"
    exit 1
fi

# Import the 'ver_test' function.
source ${VER_TEST_SCRIPT} || exit

# This does not need an explanation!
show_usage_and_exit()
{
    echo ""
    echo "Usage:  $(basename $0) [options]"
    echo ""
    echo "Options:"
    echo "  -h  display this usage summary"
    echo "  -1  emerge packages with --jobs=1"
    echo "  -f  fetch all packages before emerge"
    echo "  -k  skip sync of gentoo and other repos"
    echo "  -p  pretend mode (do not emerge packages)"
    echo "  -r  resume from depclean (skip sync/emerge)"
    echo "  -l  just check the local repository for updates"
    echo ""
    exit 1
}

# If allowed, sync Gentoo and other enabled repos
# (note: in "pretend mode" perform a silent sync).
sync_gentoo_and_other_repos()
{
    if [ ${SYNC_REPOS} -ne 0 ]; then
        if [ ${PRETEND_MODE} -ne 0 ]; then
            emerge --sync >/dev/null 2>&1 || exit 1
        else
            echo -e "\nSYNCING REPOS\n-------------\n"
            emerge --sync || exit 1
        fi

        # Update the list of installed packages. See:
        # https://forums.gentoo.org/viewtopic-t-1089544-start-0.html
        # https://wiki.gentoo.org/wiki/Gentoo_Cheat_Sheet
        # https://wiki.gentoo.org/wiki/Eix
        #eix-update
    fi
}

# If requested, download the required packages (before performing the emerge).
download_distfiles_before_emerge()
{
    if [ ${FETCH_BEFORE_EMERGE} -ne 0 ]; then
        echo -e "\nDOWNLOADING PACKAGES\n--------------------\n"
        emerge -uf --jobs=1 @world || exit 1
        echo -e "\n"
    fi
}

# Just pretend the @world updates (i.e. do not
# emerge packages). Note: colors are disabled.
pretend_world_updates_nocolor()
{
    echo -e "\nAVAILABLE UPDATES\n-----------------\n"
    emerge -pvuDN --quiet --color=n @world
    echo -e "\n"
}

# Get the latest version of the atom '$1' (from $PERSONAL_REPO) and
# checks whether the same version exists in $GENTOO_REPO or whether
# a new version exists in any repository (excluding $PERSONAL_REPO).
search_updated_ebuild()
{
    # Get category and package name.
    local pkg=$(basename $1)
    local ctg=$(basename $(dirname $1))
    if [ $ctg != "metadata" -a $ctg != "profiles" ]; then

        # Get latest version in local repo.
        local lver=0
        local array=($(ls $1/*.ebuild | sed 's/.*-\([0-9].*\).ebuild/\1/'))
        for i in "${array[@]}"; do
            if ver_test "$lver" "-lt" "$i" ; then
                    lver="$i"
            fi
        done

        # Scan other repos for the same package.
        for repo in ${REPOS_ROOT}/*; do
            if [ "$repo" != "${PERSONAL_REPO}" ]; then
                 if [ -d "$repo/$ctg/$pkg" ]; then
                     local rver=0
                     local array=($(ls $repo/$ctg/$pkg/*.ebuild | sed 's/.*-\([0-9].*\).ebuild/\1/'))

                     # Get latest version (excluding -9999*) in scanned repo.
                     for i in "${array[@]}"; do
                         if [[ "$i" != 9999* ]]; then
                             if ver_test "$rver" "-lt" "$i" ; then
                                 rver="$i"
                             fi
                         fi
                     done

                     # Compare latest version in local repo with latest version in scanned repo.
                     if ver_test "$rver" "-gt" "$lver" ; then
                         echo -e "\n  $ctg/$pkg-$lver"
                         echo "    version $rver in '$(basename $repo)'"
                     elif [ "$repo" == "${GENTOO_REPO}" ]; then
                         if ver_test "$rver" "-eq" "$lver" ; then
                             echo -e "\n  $ctg/$pkg-$lver"
                             echo "    same version in 'gentoo'"
                         fi
                     fi
                 fi
            fi
        done
    fi
}

# Scans all atoms (i.e. packages) from $PERSONAL_REPO (see above):
# selects the latest version of the parsed atom and checks whether
# the same version exists in $GENTOO_REPO or whether a new version
# exists in any repository (excluding $PERSONAL_REPO of course).
check_personal_repo_updates()
{
    echo -e "\nPOSSIBLE UPDATES FOR 'local' EBUILDS\n------------------------------------"
    for i in ${PERSONAL_REPO}/*/*; do
        if [ -d "$i" ]; then
            search_updated_ebuild "$i"
        fi
    done
    echo ""
}

# Get the number of packages to emerge and perform the required actions
# if the user allow it. Note: PIPESTATUS is a bash array with the status
# of each command in the pipe, and PIPESTATUS[0] (return value of emerge)
# must be returned as return value of the subshell used to get the number
# of packages to emerge (see https://superuser.com/questions/425774).
perform_colorful_emerge()
{
    local npkg
    echo -e "\nEMERGING PACKAGES\n-----------------"
    npkg=$(emerge -avuDN --color=y ${EMERGE_OPTIONS} @world | tee /dev/stderr \
    | grep -E 'Total: [0-9]+ package.*' | awk '{ print $2 }'; exit ${PIPESTATUS[0]})

    # Check emerge status and the number of packages to emerge or emerged.
    [[ $? -ne 0 ]] && exit 1
    if [ $npkg -eq 0 ]; then
        # With no packages to emerge, scan for possible
        # packages' updates in personal repo, then quit.
        echo ""
        check_personal_repo_updates
        exit 0
    fi
    echo -e "\n"
}

# Process options (if any).
SYNC_REPOS=1
PRETEND_MODE=0
EMERGE_OPTIONS=""
CHECK_LOCAL_ONLY=0
FETCH_BEFORE_EMERGE=0
RESUME_FROM_DEPCLEAN=0
while getopts ":1fhklpr" opt; do
    case ${opt} in
        1) EMERGE_OPTIONS="--jobs=1"
           ;;
        f) FETCH_BEFORE_EMERGE=1
           ;;
        h) show_usage_and_exit
           ;;
        k) SYNC_REPOS=0
           ;;
        l) CHECK_LOCAL_ONLY=1
           ;;
        p) PRETEND_MODE=1
           ;;
        r) RESUME_FROM_DEPCLEAN=1
           ;;
        ?) echo -e "\nError: invalid option -${OPTARG}  (use -h for help)\n"
           exit 1
           ;;
    esac
done

# Check conflicting options.
if [ ${PRETEND_MODE} -ne 0 -a ${CHECK_LOCAL_ONLY} -ne 0 ] \
|| [ ${RESUME_FROM_DEPCLEAN} -ne 0 -a ${PRETEND_MODE} -ne 0 ] \
|| [ ${RESUME_FROM_DEPCLEAN} -ne 0 -a ${CHECK_LOCAL_ONLY} -ne 0 ]; then
    echo -e "\nError: options -l -p -r cannot be used at the same time\n"
    exit 1
fi

# Pretend mode / check local only.
if [ ${PRETEND_MODE} -ne 0 -o ${CHECK_LOCAL_ONLY} -ne 0 ]; then
    sync_gentoo_and_other_repos
    if [ ${PRETEND_MODE} -ne 0 ]; then
        pretend_world_updates_nocolor
    fi
    check_personal_repo_updates
    exit 0
fi

# Sync repos, download distfiles, perform emerge (if allowed).
if [ ${RESUME_FROM_DEPCLEAN} -eq 0 ]; then
    sync_gentoo_and_other_repos
    download_distfiles_before_emerge
    perform_colorful_emerge
fi

# If allowed, remove unused and superceded packages (if any).
echo -e "\nPERFORMING DEPCLEAN\n-------------------"
emerge -a --depclean
echo -e "\n"

# Rebuild broken packages (if any).
echo -e "\nREBUILDING BROKEN PACKAGES\n--------------------------\n"
emerge @preserved-rebuild
echo ""
revdep-rebuild
echo -e "\n"

# Remove sources of unused and superceded packages.
echo -e "\nREMOVING OUTDATED DISTFILES\n---------------------------\n"
eclean -d distfiles
echo -e "\n"

# Update configuration files and /etc/profile.
echo -e "\nUPDATING CONFIGURATION\n----------------------\n"
etc-update
env-update
echo -e "\n"

# Patch menu desktop files.
if [ -x /root/SYSTEM/BIN/patch_menu.sh ]; then
    echo -e "\nPATCHING DESKTOPFILES\n---------------------"
    /root/SYSTEM/BIN/patch_menu.sh
    echo ""
fi

# Scan for possible updates of packages in personal repo.
check_personal_repo_updates

# Tell user to source '/etc/profile' (it cannot be done inside
# the script). Note: ANSI escape codes are used to colorize the
# strings (see https://stackoverflow.com/questions/5947742).
echo -e "\n\e[1;32mDone\e[0m"
echo -e "\n\e[1;32mPlease, type '\e[1;33msource /etc/profile\e[1;32m' in any open shell or reboot the system\e[0m\n"
exit 0
