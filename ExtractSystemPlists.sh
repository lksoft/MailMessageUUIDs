#!/bin/bash

OS_BUILD_VERSION=`sw_vers | grep BuildVersion | cut -f2 -s`
OS_VERSION=`sw_vers | grep ProductVersion | cut -f2 -s`

if [[ "$1" == "-d" ]]; then
	BUILD_SECTION="DevRelease-$OS_BUILD_VERSION"
else
	BUILD_SECTION="$OS_BUILD_VERSION"
fi

MAJOR_VERSION=`echo "$OS_VERSION" | cut -f 2 -d .`

MAIL_PATH="/Applications/Mail.app/Contents/Info.plist"

if [[ -f $MAIL_PATH ]]; then
	echo "Extracting Mail plist"
	cp "$MAIL_PATH" "PListFolder/$OS_VERSION-mail-$BUILD_SECTION-info.plist"
fi
