#!/usr/bin/env python3
#
# Released under MIT License
# Copyright (c) 2008-2024 Flavio Cappelli
# Version 1.2
#
# Process .desktop files in /usr/share/applications/:
#
#  - remove lines with unused locales (see below);
#  - remove lines not required for KDE/PLASMA (5 & 6);
#  - reorder remaining lines in the .desktop file;
#  - sort items in the MimeTypes entry.
#
# Note: .desktop files can have several sections, so we must
# consider that (to not mix lines from different sections).
#
# This script has been tested with Python 3.11 and 3.12. It
# is launched by patch_menu.sh but can also be run manually:
#
#   - without arguments: in this case all .desktop files
#     in /usr/share/applications/ are parsed and simplified;
#   - with the path of one or more .desktop files as argument:
#     in this case only the specified .desktop files (that
#     must exist) are parsed and simplified.


# Set the allowed locales in the .desktop files (locales that do
# not match the following list are removed from the .desktop files).
# Should match /etc/locale.gen (more or less). Note that the 'en'
# locale is unnecessary (default keys are always included).
allowed_locales = ['it', 'it_IT']



# NOTHING TO MODIFY BELOW THIS LINE.
# ==========================================================================

import os
import sys
import pathlib
import shutil
import errno

backup_folder = '/tmp/_desktopfile_backup'


# Display help.
# --------------------------------------------------------------------------
def show_usage():
    print('\nThis script must can be called:')
    print('   - without arguments: in this case all .desktop files')
    print('     in /usr/share/applications are parsed and simplified;')
    print('   - with the path of one or more .desktop files as argument:')
    print('     in this case only the specified .desktop files (that')
    print('     must exist) are parsed and simplified.')
    sys.exit(1)


# Return the line if the locale is allowed else return an empty string.
# --------------------------------------------------------------------------
def check_match(string, startlist):
    for startstr in startlist:
        if (string.startswith(startstr + '=')):
            return string
        else:
            for locale in allowed_locales:
                if (string.startswith(startstr + '[' + locale + ']=')):
                    return string
    return ''


# Sort lines in each section of a desktop file.
# See https://docs.fileformat.com/settings/desktop/
# --------------------------------------------------------------------------
def sort_function(line):

    # The section header ([...]) must be at the beginning...
    if (line.startswith('[')):
        return 5

   # ...then the 'Hidden' or 'NoDisplay' entries (if exist)...
    elif (line.startswith('Hidden') or line.startswith('NoDisplay')):
        return 10

   # ...then the 'OnlyShowIn' or 'NotShowIn' entries (if exist)...
    elif (line.startswith('OnlyShowIn') or line.startswith('NotShowIn')):
        return 15

    # ...then the 'Name=' entry...
    elif (line.startswith('Name=')):
        return 20

    # ...then all 'Name[]=' entries...
    elif (line.startswith('Name[')):
        return 25

    # ...then the 'GenericName=' entry...
    elif (line.startswith('GenericName=')):
        return 30

    # ...then all 'GenericName[]=' entries...
    elif (line.startswith('GenericName[')):
        return 35

    # ...then the 'TryExec' entry (if exists)...
    elif (line.startswith('TryExec')):
        return 40

    # ...then the 'Exec' entry...
    elif (line.startswith('Exec')):
        return 45

    # ...then the 'Icon' entry...
    elif (line.startswith('Icon')):
        return 50

    # ...then the 'Terminal' entry (if exists)...
    elif (line.startswith('Terminal')):
        return 55

    # ...then the 'Type' entry...
    elif (line.startswith('Type')):
        return 60

    # ...then the 'MimeType' entry (if exists)...
    elif (line.startswith('MimeType')):
        return 65

    # ...then the 'Categories' entry...
    elif (line.startswith('Categories')):
        return 70

    # ...then the 'Keywords=' entry...
    elif (line.startswith('Keywords=')):
        return 75

    # ...then all 'Keywords[]=' entries...
    elif (line.startswith('Keywords[')):
        return 80

    # ...then the 'InitialPreference' entry (if exists)...
    elif (line.startswith('InitialPreference')):
        return 85

    # ...then the 'StartupWMClass' entry (if exists)...
    elif (line.startswith('StartupWMClass')):
        return 90

    # ...then the 'StartupNotify' entry...
    elif (line.startswith('StartupNotify')):
        return 95

    # ...then all 'X-' entries (if exist), ordered by first char after 'X-' ...
    elif (line.startswith('X-')):
        return 500 + ord(line[2]) - ord('A')

    # ...then the 'Actions' entry as last position (if exists)...
    elif (line.startswith('Actions')):
        return 995

    # All other lines are inserted from 'StartupNotify' to 'X-'.
    else:
        return 495


# Process the .desktop file line by line.
# --------------------------------------------------------------------------
def process_desktopfile(filename):
    section_idx = -1
    output_sections = []

    # Save a copy of the .desktop file (the destination path must exist).
    shutil.copy(filename, backup_folder)

    # Open the .desktop file.
    file = open(filename, 'r')
    input_lines = file.read().splitlines()

    # Process line by line, escluding:
    #  - lines starting with "Version"
    #  - lines starting with "Comment"
    #  - lines starting with "X-Ayatana"
    #  - lines starting with "X-GNOME-Bugzilla"
    #  - lines starting with "X-GNOME-FullName"
    #  - lines starting with "X-Desktop-File-Install-Version"
    #  - lines starting with "Encoding=UTF-8" (default)
    #  - lines starting with "Icon[" (Icon= is enough)
    #  - lines starting with "#" (i.e. comments)
    for line in input_lines:
        line = line.strip()
        if not (len(line) == 0 or
                line.startswith('Version') or
                line.startswith('Comment') or
                line.startswith('X-Ayatana') or
                line.startswith('X-GNOME-Bugzilla') or
                line.startswith('X-GNOME-FullName') or
                line.startswith('X-Desktop-File-Install-Version') or
                line.startswith('Encoding=UTF-8') or
                line.startswith('Icon[') or
                line.startswith('#')):
            if (line.startswith('[')):                  # Start a new section.
                list = []
                list.append(line)
                output_sections.append(list)
                section_idx = section_idx + 1
            else:                                       # Append to the last section.
                assert section_idx >= 0

                # Transform the old 'X-KDE-Keywords' entries in modern 'Keywords' entries (see
                # https://tsdgeos.blogspot.com/2014/11/keywords-vs-x-kde-keywords-on-desktop.html)
                if (line.startswith('X-KDE-Keywords')):
                    line = line.replace("X-KDE-Keywords", "Keywords").replace(",",";") + ";"

                # Remove the unwanted locales and sort the MimeType items.
                if (line.startswith('Name') or line.startswith('GenericName') or line.startswith('Keywords')):
                    processed_line = check_match(line, ['Name', 'GenericName', 'Keywords'])
                elif (line.startswith('MimeType') and line.endswith(';')):
                    processed_line = 'MimeType=' + ';'.join(sorted(set(line[9:-1].split(';')))) + ';'
                else:
                    processed_line = line

                # Save the processed line if not empty.
                if (len(processed_line.strip()) > 0):
                    output_sections[section_idx].append(processed_line)

    # Close the .desktop file.
    file.close()

    # Open the .desktop file for writing, but only if there is at least
    # one section to save (the .desktop file might be empty or contains
    # only comments). Root permissions are required from now on.
    if (section_idx >= 0):
        file = open(filename, 'w')

        # Sort lines (inside each section) and save them.
        last_section = output_sections[-1]
        for section in output_sections:
            section.sort(key=sort_function)
            for line in section:
                file.write(line + '\n')
            if section != last_section:
                file.write('\n')

        # Close the modified .desktop file.
        file.close()


# Process all .desktop files in /usr/share/applications.
# --------------------------------------------------------------------------

# Must be run by root (or with sudo), see:
#  - https://stackoverflow.com/questions/2806897
#  - https://stackoverflow.com/questions/27674602
# --------------------------------------------------------------------------
if not os.environ.get('SUDO_UID') and os.geteuid() != 0:
    print('\nYou need to be root (or use sudo) to run this script!')
    sys.exit(1)

# Check if the directories backup_folder exists, otherwise creates it.
if not os.path.exists(backup_folder):
    os.makedirs(backup_folder)

# If deskopfiles are specified as arguments, save a copy and process them.
if len(sys.argv) > 1:
    for arg in sys.argv[1:]:
        if not arg.endswith('.desktop'):
            print('\nInvalid argument(s), aborting!')
            show_usage()
        elif not os.path.isfile(arg):
            print('\nFile', arg, 'not found, aborting!')
            sys.exit(1)
        process_desktopfile(arg)
else:
    # Get all .desktop files of installed packages and process them (saving a copy).
    desktopfilepath = pathlib.Path('/usr/share/applications')
    desktopfilelist=list(desktopfilepath.rglob('*.desktop'))
    for posixfilename in desktopfilelist:
        process_desktopfile(str(posixfilename))

# End, automatically return exit code 0 if all ok.
