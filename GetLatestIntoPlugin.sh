#!/bin/sh

#  UpdateInfoPlist.sh
#  SignatureProfiler
#
#  Created by Scott Little on 9/11/12.
#

#	Ignore if we are cleaning
if [[ -n $ACTION && $ACTION = "clean" ]]; then
	echo "Ignoring during clean"
	exit 0
fi

SRCROOT='.'

#	Set the locations
export MY_UUID_REPO_NAME="MailMessageUUIDs"
export MY_UUID_REPO="$SRCROOT/../$MY_UUID_REPO_NAME"

#	Go into the MailMessagesUUIDs folder and ensure that it is up-to-date
if [ ! -d "$MY_UUID_REPO" ]; then
	echo "UUID Script ERROR - The $MY_UUID_REPO_NAME submodule doesn't exist!!"
	exit 1
fi
cd "$MY_UUID_REPO"
git checkout master
BRANCH=`git status | grep "# On branch" | cut -c 13-`
if [ "$BRANCH" != "master" ]; then
	echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs to be on the master branch - I can't seem to change to it"
	exit 2
fi
IS_CLEAN=`git status | grep "nothing" | cut -c 1-17`
if [[ -z $IS_CLEAN || "$IS_CLEAN" != "nothing to commit" ]]; then
	echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs have a clean status"
	exit 3
fi
git pull origin master


#	Run the script there that generates the UUID list file
echo "Generating UUID list file"
/usr/bin/osascript "ProcessMailMessageInfo.applescript"


#	Run the other script that will update my Info.plist file
echo "Updating Info.plist file"
echo "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
/usr/bin/osascript "UpdateInfoPlist.applescript" "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
