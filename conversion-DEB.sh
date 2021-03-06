#!/bin/bash

# Checking if the plugin is correct
function plugin_is_correct()
{
    if [[ $# -eq 1 ]]
    then 
        for plugin in qt python gtk ncurses gstreamer
        do 
            if [[ "$1" = "$plugin" ]]
                then echo 1; exit;
            fi
        done
        echo 0; exit;
    else echo 0; exit;
    fi
}

# Declaration of parameters
PACKAGE_FILE=""
PACKAGE=""

DESKTOP_FILE=""
PACKAGE_NAME=""
PACKAGE_TITLE=""
ICON_NAME=""
EXECUTABLE=""
ICON=""

# Close programm without arguments
if [ $# -eq 0 ]
then
    echo "There is no parameters"
    help
    exit 1
fi

while [ "$1" != "" ]
do
    case "$1" in 
    --package-file) if [ -n "$2" ]
                    then PACKAGE_FILE="$2";

                    else printf "\tPlease, specify the package\n"; exit 1;
                fi;
                shift;shift;;

    --mount-directory) if [ -n "$2" ]
                    then MOUNT_DIRECTORY="$2";

                    else printf "\tPlease, specify the mount directory\n"; exit 1;
                fi;
                shift;shift;;    

    --package) if [ -n "$2" ]
                    then PACKAGE="$2";

                    else printf "\tPlease, specify the package\n"; exit 1;
                fi;
                shift;shift;;

    --plugin)  if [ -n "$2" ] && [[ $(plugin_is_correct "$2") = "1" ]]
                    then PLUGINS[PLUGINS_COUNT]="$2";
                        PLUGINS_COUNT=$((PLUGINS_COUNT + 1));

                    else printf "\tPlease, specify the plugin. $2 is not correct plugin\n";exit 1;
                fi;            
                shift;shift;;

    *) printf "$1 is not an option\n"; exit 1;;
    esac
done

# Adding plugins with argument, like --plugin qt
plugins_with_arguments=""
for plugin in ${PLUGINS[*]}
    do plugins_with_arguments+=" --plugin "
       plugins_with_arguments+="${plugin}"
done

# Unpacking archive
dpkg --extract /mnt/"$PACKAGE_FILE" /tmp/AppDir

# Getting desktop file of package
DESKTOP_FILE+="/tmp/AppDir"
DESKTOP_FILE+=$(dpkg -L "$PACKAGE" | grep -e "application" | grep -e ".desktop" -m 1)

echo "DESKTOP_FILE=$DESKTOP_FILE"

# Parsing it for executable, icon and name
PACKAGE_NAME=$(cat "$DESKTOP_FILE" | grep -e ^Exec= -m 1 | sed 's/Exec=//g' | cut -d' ' -f1 | sed 's/ /_/g')
echo "PACKAGE_NAME=$PACKAGE_NAME"

PACKAGE_TITLE=$(cat "$DESKTOP_FILE" | grep -e ^Name= -m 1 | sed 's/Name=//g')
echo "PACKAGE_TITLE=$PACKAGE_TITLE"

ICON_NAME=$(cat "$DESKTOP_FILE" | grep -e ^Icon= -m 1 | sed 's/Icon=//g')
echo "ICON_NAME=$ICON_NAME"

ICON+="/tmp/AppDir"
ICON+=$(rpmquery --list "$PACKAGE" | grep -e "icon" | grep -v "1024x1024" | grep -e "$ICON_NAME".png -m 1)
echo "ICON=$ICON"

# WARNING, IT IS A KLUDGE
if [ -f "$ICON_NAME" ]                                                                                              # If icon name is a file
then                                                                                                                # For case like "/usr/share/icons/breeze/applets/16/car.svg"
    echo "updating icon..."
    ICON=/tmp/AppDir$(echo "$ICON_NAME" | sed 's/\/[^/]*$//')/"$PACKAGE".$(echo "$ICON_NAME" | sed 's/^.*\.//')     # New icon file should have be in same dir with older one, and have same extension, but different name
    mv /tmp/AppDir"$ICON_NAME" "$ICON"                                                                              # Move icon with same name as package. Required for auto-generated .desktop file
    ICON_NAME=$PACKAGE                                                                                              # Turn "/usr/share/icons/breeze/applets/16/car.svg" into "car"
    DESKTOP_FILE="/tmp/AppDir"                                                                                      # Clean desktop file, instead of the existing one create a new one
    echo "ICON=$ICON"
fi
# END OF WARNING                                                  

# Finding executable and icon files
EXECUTABLE+="/tmp/AppDir"
EXECUTABLE+=$(dpkg -L "$PACKAGE" | grep -e /bin/ | grep -e "$PACKAGE_NAME$" -m 1)
echo "EXECUTABLE=$EXECUTABLE"

if [ "$EXECUTABLE" = "/tmp/AppDir" ]
    then
    echo "Executable not found, searching in games..."
    EXECUTABLE+=$(dpkg -L "$PACKAGE" | grep -e /games/ | grep -e "$PACKAGE_NAME$" -m 1)
    echo "EXECUTABLE=$EXECUTABLE"

    if [ "$EXECUTABLE" = "/tmp/AppDir" ]
        then
        echo "Executable not found, appimage creation aborted..."
        exit 1
    fi
fi

# If icon is not found
if [ "$ICON" = "/tmp/AppDir" ]
    then
    echo "Icon not found"

    # Set adwaita icon as default
    # If there are no Icon name
    if [ "$ICON_NAME" = "" ]
        then
        # Set same name like package
        ICON_NAME="$PACKAGE"
    fi
    mkdir /tmp/AppDir/usr/share/icons
    cp /usr/share/icons/Adwaita/256x256/legacy/user-info.png /tmp/AppDir/usr/share/icons/"$ICON_NAME".png
    ICON="/tmp/AppDir/usr/share/icons/$ICON_NAME.png"
fi

# If there are no desktop file
if [ "$DESKTOP_FILE" = "/tmp/AppDir" ]
    then
    # Use --create-desktop-file option
    echo "/tmp/linuxdeploy/AppRun --appdir /tmp/AppDir --executable $EXECUTABLE --create-desktop-file --icon-file $ICON $plugins_with_arguments --output appimage"
    cd /tmp && /tmp/linuxdeploy/AppRun --appdir /tmp/AppDir/ --executable "$EXECUTABLE" --create-desktop-file --icon-file "$ICON" $plugins_with_arguments --output appimage
    else
    # Use .desktop file if it exists
    echo "/tmp/linuxdeploy/AppRun --appdir /tmp/AppDir --executable $EXECUTABLE --desktop-file $DESKTOP_FILE --icon-file $ICON $plugins_with_arguments --output appimage"
    cd /tmp && /tmp/linuxdeploy/AppRun --appdir /tmp/AppDir/ --executable "$EXECUTABLE" --desktop-file "$DESKTOP_FILE" --icon-file "$ICON" $plugins_with_arguments --output appimage
fi

# Copy AppImage file to host directory
cp /tmp/*.AppImage /mnt/

printf "\n\nNow you can find your AppImage $MOUNT_DIRECTORY/$(ls /mnt/ | grep -e "$PACKAGE_TITLE" -m 1)\n"