#!/bin/bash

OS_BUILD_VERSION=`defaults read /System/Library/CoreServices/SystemVersion.plist ProductBuildVersion`
OS_VERSION=`defaults read /System/Library/CoreServices/SystemVersion.plist ProductVersion`

if [[ "$1" == "-d" ]]; then
	INFO_SECTION="DevRelease$OS_BUILD_VERSION-Info"
else
	INFO_SECTION="Info"
fi

MESSAGE_PATH="/System/Library/Frameworks/Message.framework/Resources/Info.plist"
MAIL_PATH="/Applications/Mail.app/Contents/Info.plist"

if [[ -f $MESSAGE_PATH ]]; then
	echo "Extracting Message plist"
#	echo "Extraction path is: '$OS_VERSION-Message-$INFO_SECTION.plist'"
	cp "$MESSAGE_PATH" "$OS_VERSION-Message-$INFO_SECTION.plist"
fi

if [[ -f $MAIL_PATH ]]; then
	echo "Extracting Mail plist"
#	echo "Extraction path is: '$OS_VERSION-Mail-$INFO_SECTION.plist'"
	cp "$MAIL_PATH" "$OS_VERSION-Mail-$INFO_SECTION.plist"
fi
