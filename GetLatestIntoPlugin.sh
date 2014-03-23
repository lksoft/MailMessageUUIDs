#!/bin/sh

#  UpdateInfoPlist.sh
#  SignatureProfiler
#
#  Created by Scott Little on 9/11/12.
#

#	Ignore if we are cleaning
if [[ -n $ACTION && "$ACTION" = "clean" ]]; then
	echo "Ignoring during clean"
	exit 0
fi

SRCROOT='.'

# if script is called with absolute path, take repo path from it
BASEDIR=$(dirname $0)

#	Set the locations
export MY_UUID_REPO_NAME="MailMessageUUIDs"
if [[ -d "$BASEDIR" ]]; then
    export MY_UUID_REPO="$BASEDIR"
else
    export MY_UUID_REPO="$SRCROOT/../$MY_UUID_REPO_NAME"
fi

#	Go into the MailMessagesUUIDs folder and ensure that it is up-to-date
if [ ! -d "$MY_UUID_REPO" ]; then
	echo "UUID Script ERROR - The $MY_UUID_REPO_NAME submodule doesn't exist!!"
	exit 1
fi
cd "$MY_UUID_REPO"

NEEDS_BUILD=1
IS_RELEASE=0
if [[ "$CONFIGURATION" == "Release" ]]; then
	IS_RELEASE=1
fi
if [[ -f "SupportableUUIDList.txt" && ($IS_RELEASE == 0) ]]; then
	
	#	If the latest supported file is newer than any local commits, go ahead and indicate that a build isn't needed
	DATE_FORMAT="%a %b %d %T %Y"
	LAST_PLIST_COMMIT_DATE=`git log -1 --format=%cd PlistFolder/*`
	SUPPORTABLE_FILE_DATE=`python -c "import os,time; print time.ctime(os.path.getmtime('SupportableUUIDList.txt'))"`
	COMMIT_DATE=`date -j -f "%a %b %d %T %Y" "$LAST_PLIST_COMMIT_DATE" +%s`
	FILE_DATE=`date -j -f "%a %b %d %T %Y" "$SUPPORTABLE_FILE_DATE" +%s`
	if [[ $FILE_DATE > $COMMIT_DATE ]]; then
		NEEDS_BUILD=0
	fi
	
fi

# If we actually do need to rebuild the files
if [[ $NEEDS_BUILD == 1 ]]; then
	
	echo "Ensuring that the files are up-to-date."

	git checkout -q master
	BRANCH=`git rev-parse --abbrev-ref HEAD`
	if [ "$BRANCH" != "master" ]; then
		echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs to be on the master branch - I can't seem to change to it"
		exit 2
	fi
	if [ -n "$(git status --porcelain)" ]; then
		echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs have a clean status"
		exit 3
	fi
	git pull origin master


	#	Run the script there that generates the UUID list file
	echo "Generating UUID list file"
	/usr/bin/osascript "ProcessMailMessageInfo.applescript" $@

fi	# End of if we should rebuild


#	Run the other script that will update my Info.plist file
echo "Updating Info.plist file"
echo "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
/usr/bin/osascript "UpdateInfoPlist.applescript" "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
