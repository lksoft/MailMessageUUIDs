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
if [[ "$CONFIGURATION" == Release* ]]; then
	IS_RELEASE=1
fi
#"SupportableUUIDList.txt"
FILE_NAME=SupportableUUIDList.plist
if [[ -f "$FILE_NAME" && ($IS_RELEASE == 0) ]]; then

	# check if there are commits missing from the remote git repository
	NUM_BEHIND=`git rev-list HEAD...origin/master --count`
	if [ $NUM_BEHIND == 0 ]; then

		#	If the latest supported file is newer than any local commits, go ahead and indicate that a build isn't needed
		DATE_FORMAT="%a %b %d %T %Y"
		LAST_PLIST_COMMIT_DATE=`git log -1 --format=%cd PlistFolder/*`
		SUPPORTABLE_FILE_DATE=`/usr/bin/python -c "import os,time; print time.ctime(os.path.getmtime('$FILE_NAME'))"`
		COMMIT_DATE=`date -j -f "%a %b %d %T %Y" "$LAST_PLIST_COMMIT_DATE" +%s`
		FILE_DATE=`date -j -f "%a %b %d %T %Y" "$SUPPORTABLE_FILE_DATE" +%s`
		if [[ $FILE_DATE > $COMMIT_DATE ]]; then
			NEEDS_BUILD=0
		fi
	fi
	
fi

if [[ ! -d Archived ]]; then
	mkdir Archived
fi

PREV_HASH=`git rev-parse HEAD`;
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


fi	# End of if we should rebuild

UPDATED_HASH=`git rev-parse HEAD`;
if [[ $PREV_HASH != $UPDATED_HASH ]]; then
	# delete the contents of the Archive folder
	rm Archived/*
fi

#	Run the script there that generates the UUID list file
echo "Generating UUID list file"
./ProcessMailMessageInfo.pl plist "$@"

#	Set the default info plist path
export PLIST_PATH="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
if [[ -n "$UPDATE_INFO_PLIST_PATH" ]]; then
	export PLIST_PATH="$UPDATE_INFO_PLIST_PATH"
fi

UUID_KEY=''
for i in {1..10}
do
	if [[ "$1" == uu=* ]]; then
		UUID_KEY=`echo $1 | cut -b 4-`
		break
	fi
	shift
done
echo "The UUID KEY is: $UUID_KEY"

#	Run the other script that will update my Info.plist file
echo "Updating Info.plist file"
echo "PList Path: $PLIST_PATH"
perl -w UpdateInfoPlist.pl "$MY_UUID_REPO/$FILE_NAME" "$PLIST_PATH" "$UUID_KEY"
