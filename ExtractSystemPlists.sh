#!/bin/bash

OS_BUILD_VERSION=`sw_vers | grep BuildVersion | cut -f2 -s`
OS_VERSION=`sw_vers | grep ProductVersion | cut -f2 -s`

if [[ "$1" == "-d" ]]; then
	BUILD_SECTION="DevRelease-$OS_BUILD_VERSION"
else
	BUILD_SECTION="$OS_BUILD_VERSION"
fi

MAJOR_VERSION=`echo "$OS_VERSION" | cut -f 2 -d .`

MESSAGE_PATH="/System/Library/Frameworks/Message.framework/Resources/Info.plist"
MAIL_PATH="/Applications/Mail.app/Contents/Info.plist"

if [[ -f $MESSAGE_PATH ]]; then
	if [[ $MAJOR_VERSION < 9 ]]; then
		echo "Extracting Message plist"
		cp "$MESSAGE_PATH" "$OS_VERSION-message-$BUILD_SECTION-info.plist"
	fi
fi

if [[ -f $MAIL_PATH ]]; then
	echo "Extracting Mail plist"
	cp "$MAIL_PATH" "$OS_VERSION-mail-$BUILD_SECTION-info.plist"
fi
