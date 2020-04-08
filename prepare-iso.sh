#!/bin/bash
#
# This script will create a bootable ISO image from the installer app for:
#
#   - Yosemite (10.10)
#   - El Capitan (10.11)
#   - Sierra (10.12)
#   - High Sierra (10.13)
#   - Mojave (10.14)

# Prep 
# Step 1: 
# if you have downloaded a stub installer
# Use disk utility to create a temp partition 25 Gb in size and install to that (but don't reboot).
# then in terminal:
# sudo -s
# mkdir /Applications/Install\ macOS\ Mojave.app/Contents/SharedSupport
# cd /Volumes/{name of partition}/macOS\ Install\ Data/
# find . mount | cpio -pvdm /Applications/Install\ macOS\ Mojave.app/Contents/SharedSupport
#
# Ref: https://techsviewer.com/how-to-download-full-macos-catalina-installer-and-mojave/

# Prep 2:
# If there is a file InstallESDDmg.pkg in /Applications/Install\ macOS\ Mojave.app/Contents/SharedSupport
# Rename it to InstallESD.dmg
# nano /Applications/Install\ macOS\ Mojave.app/Contents/SharedSupport/InstallInfo.plist
# take out the 4 lines under Payload Image Info that mention chunklist:
#   <key>chunklistURL</key>
#   <string>InstallESDDmg.chunklist</string>
#   <key>chunklist.id</key>
#   <string>com.apple.chunklist.InstallESDDmg</string>
# Edit the lines above and below that section to correct the name of InstallESD.dmg:
#   <string>InstallESDDmg.pkg</string> --> <string>InstallESD.dmg</string>
#   ...
#   <string>com.apple.pkg.InstallESDDmg</string> --> <string>com.apple.pkg.InstallESD</string>
# Save and exit.
# Now run this script.
#
# Ref: https://www.insanelymac.com/forum/topic/329828-making-a-bootable-high-sierra-usb-installer-entirely-from-scratch-in-windows-or-linux-mint-without-access-to-mac-or-app-store-installerapp/

set -e

#global vars because bash sucks
installerAppName=0
result=0
error=0

#
# createISO
#
# This function creates the ISO image for the user.
# Inputs:  $1 = The name of the installer - located in your Applications folder or in your local folder/PATH.
#          $2 = The Name of the ISO you want created.
function createISO()
{
  if [ $# -eq 2 ] ; then
    installerAppName=${1}
    local isoName=${2}
    error=0

    # echo Debug: installerAppName = ${installerAppName} , isoName = ${isoName}

    echo
    echo Mount the installer image
    echo -----------------------------------------------------------

    if [ -e "${installerAppName}" ] ; then
      echo $ hdiutil attach "${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      hdiutil attach "${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      error=$?
    elif [ -e /Applications/"${installerAppName}" ] ; then
      echo $ hdiutil attach /Applications/"${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      hdiutil attach /Applications/"${installerAppName}"/Contents/SharedSupport/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/install_app
      error=$?
      installerAppName="/Applications/${installerAppName}"
    else
      echo Installer Not found!
      error=1
    fi

    if [ ${error} -ne 0 ] ; then
      echo "Failed to mount the InstallESD.dmg from the instaler at ${installerAppName}.  Exiting. (${error})"
      exit $error
    fi

    echo
    echo Create ${isoName} blank ISO image with a Single Partition - Apple Partition Map
    echo --------------------------------------------------------------------------
    echo $ hdiutil create -o /tmp/${isoName} -size 8g -layout SPUD -fs HFS+J -type SPARSE
    hdiutil create -o /tmp/${isoName} -size 8g -layout SPUD -fs HFS+J -type SPARSE

    echo
    echo Mount the sparse bundle for package addition
    echo --------------------------------------------------------------------------
    echo $ hdiutil attach /tmp/${isoName}.sparseimage -noverify -nobrowse -mountpoint /Volumes/install_build
    hdiutil attach /tmp/${isoName}.sparseimage -noverify -nobrowse -mountpoint /Volumes/install_build

    echo
    echo Restore the Base System into the ${isoName} ISO image
    echo --------------------------------------------------------------------------
    if [ "${isoName}" == "HighSierra" ] || [ "${isoName}" == "Mojave" ] ; then
      echo $ asr restore -source "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase
      asr restore -source "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase
    else
      echo $ asr restore -source /Volumes/install_app/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase
      asr restore -source /Volumes/install_app/BaseSystem.dmg -target /Volumes/install_build -noprompt -noverify -erase
    fi

    echo
    echo Remove Package link and replace with actual files
    echo --------------------------------------------------------------------------
    if [ "${isoName}" == "HighSierra" ] ; then
      echo $ ditto -V /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
      ditto -V /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
    elif [ "${isoName}" == "Mojave" ] ; then
      echo $ ditto -V /Volumes/install_app/Packages /Volumes/macOS\ Base\ System/System/Installation/
      ditto -V /Volumes/install_app/Packages /Volumes/macOS\ Base\ System/System/Installation/
    else
      echo $ rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages
      rm /Volumes/OS\ X\ Base\ System/System/Installation/Packages
      echo $ cp -rp /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
      cp -rp /Volumes/install_app/Packages /Volumes/OS\ X\ Base\ System/System/Installation/
    fi

    echo
    echo Copy macOS ${isoName} installer dependencies
    echo --------------------------------------------------------------------------
    if [ "${isoName}" == "HighSierra" ] ; then
      echo $ ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
      ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
      echo $ ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg
      ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg
    elif [ "${isoName}" == "Mojave" ] ; then
      echo $ ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.chunklist /Volumes/macOS\ Base\ System/BaseSystem.chunklist
      ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.chunklist /Volumes/macOS\ Base\ System/BaseSystem.chunklist
      echo $ ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg /Volumes/macOS\ Base\ System/BaseSystem.dmg
      ditto -V "${installerAppName}"/Contents/SharedSupport/BaseSystem.dmg /Volumes/macOS\ Base\ System/BaseSystem.dmg
    else
      echo $ cp -rp /Volumes/install_app/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
      cp -rp /Volumes/install_app/BaseSystem.chunklist /Volumes/OS\ X\ Base\ System/BaseSystem.chunklist
      echo $ cp -rp /Volumes/install_app/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg
      cp -rp /Volumes/install_app/BaseSystem.dmg /Volumes/OS\ X\ Base\ System/BaseSystem.dmg
    fi

    echo
    echo Unmount the installer image
    echo --------------------------------------------------------------------------
    echo $ hdiutil detach /Volumes/install_app
    hdiutil detach /Volumes/install_app

    echo
    echo Unmount the sparse bundle
    echo --------------------------------------------------------------------------
    if [ "${isoName}" == "Mojave" ] ; then
      echo $ hdiutil detach /Volumes/macOS\ Base\ System/
      hdiutil detach /Volumes/macOS\ Base\ System/
    else
      echo $ hdiutil detach /Volumes/OS\ X\ Base\ System/
      hdiutil detach /Volumes/OS\ X\ Base\ System/
    fi

    echo
    echo Resize the partition in the sparse bundle to remove any free space
    echo --------------------------------------------------------------------------
    echo $ hdiutil resize -size `hdiutil resize -limits /tmp/${isoName}.sparseimage | tail -n 1 | awk '{ print $1 }'`b /tmp/${isoName}.sparseimage
    hdiutil resize -size `hdiutil resize -limits /tmp/${isoName}.sparseimage | tail -n 1 | awk '{ print $1 }'`b /tmp/${isoName}.sparseimage

    echo
    echo Convert the ${isoName} sparse bundle to ISO/CD master
    echo --------------------------------------------------------------------------
    echo $ hdiutil convert /tmp/${isoName}.sparseimage -format UDTO -o /tmp/${isoName}
    hdiutil convert /tmp/${isoName}.sparseimage -format UDTO -o /tmp/${isoName}

    echo
    echo Remove the sparse bundle
    echo --------------------------------------------------------------------------
    echo $ rm /tmp/${isoName}.sparseimage
    rm /tmp/${isoName}.sparseimage

    echo
    echo Rename the ISO and move it to the desktop
    echo --------------------------------------------------------------------------
    echo $ mv /tmp/${isoName}.cdr ~/Desktop/${isoName}.iso
    mv /tmp/${isoName}.cdr ~/Desktop/${isoName}.iso
  fi
}

#
# installerExists
#
# Returns 0 if the installer was found either locally or in the /Applications directory.  1 if not.
#
function installerExists()
{
  installerAppName=$1
  result=1
  if [ -e "${installerAppName}" ] ; then
    result=0
  elif [ -e /Applications/"${installerAppName}" ] ; then
    result=0
  fi
  #return ${result}
}

#
# Main script code
#
# Eject installer disk in case it was opened after download from App Store
for disk in $(hdiutil info | grep /dev/disk | grep partition | cut -f 1); do
  hdiutil detach -force ${disk}
done

# See if we can find an eligible installer.
# If successful, then create the iso file from the installer.
installerExists "Install macOS Mojave.app"
# result=$?
if [[ ${result} -eq 0 ]]; then
  echo ">>> Creating ISO for Mojave"
  createISO "Install macOS Mojave.app" "Mojave"
else
  echo ">>> No Mojave image found, trying High Sierra"
  installerExists "Install macOS High Sierra.app"
  # result=$?
  if [[ ${result} -eq 0 ]]; then
    echo "Creating ISO for High Sierra"
    createISO "Install macOS High Sierra.app" "HighSierra"
  else
    echo ">>> No High Sierra image found, trying Sierra"
    installerExists "Install macOS Sierra.app"
    # result=$?
    if [[ ${result} -eq 0 ]]; then
      createISO "Install macOS Sierra.app" "Sierra"
    else
      installerExists "Install OS X El Capitan.app"
      # result=$?
      if [[ ${result} -eq 0 ]]; then
        createISO "Install OS X El Capitan.app" "ElCapitan"
      else
        installerExists "Install OS X Yosemite.app"
        # result=$?
        if [[ ${result} -eq 0 ]]; then
          createISO "Install OS X Yosemite.app" "Yosemite"
        else
          echo "Could not find installer for Yosemite (10.10), El Capitan (10.11), Sierra (10.12), High Sierra (10.13) or Mojave (10.14)."
        fi
      fi
    fi
  fi
fi

