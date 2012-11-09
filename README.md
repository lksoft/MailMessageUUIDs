# Mail and MessageFramework UUID Management

This repository just helps facilitate maintaining and updating all of the UUIDs when Apple changes them in Mail and MessageFramework.

##	What Does it Contain?

I have extracted all of the `Mail` and `MessageFramework` `Info.plist` files from all of the Systems that Apple has shipped since 10.6. They are included in the repository. There is an applescript as well that you run to build out a text file containing all of the UUIDs that you would need to populate your `SupportedUUIDList` with. Another script can be used to update your Info.plist file.

When Apple comes out with a new system version, I only have to add the two `plist` files into the `PlistFolder` and when the script is rerun, it will reconstruct the output for you. This way it can be used easily in a build script to add the UUIDs to your plugin.

##	How do I call the Scripts?

Both of the scripts assume that this project is a submodule at the top level of your project. **This is important**, because it will be doing a `git pull` in order to ensure that the plist files are up-to-date.

### The ProcessMailMessageInfo Script

Simply call it as any applescript. It can take 2 parameters, both of which are optional. One is for the OS version you want to start with (formatted as `10.x` or `10.x.y`) and the second is a parameter to suppress comments added to the output text file describing each UUID value (`-nc`).

Examples:

Output all UUIDs with comments

	osascript ProcessMailMessageInfo.applescript

Output all UUIDs since (and including) 10.7.0 with comments
	
	osascript ProcessMailMessageInfo.applescript 10.7
	
Output all UUIDs since (and including) 10.6.5 without comments

	osascript ProcessMailMessageInfo.applescript 10.6.5 -nc
	

### The UpdatePlistInfo script

This applescript takes a single required argument, which is the path to your project's `Info.plist` file. I recommend running this script just after the plugin is built.

### Putting it all together

Here is an example script that could be used to do this:

	#	Ignore if we are cleaning
	if [[ -n $ACTION && $ACTION = "clean" ]]; then
		echo "Ignoring during clean"
		exit 0
	fi
	
	#	Set the locations
	export MY_UUID_REPO_NAME="MailMessageUUIDs"
	export MY_UUID_REPO="$SRCROOT/../$MY_UUID_REPO_NAME"
	
	#	Go into the MailMessagesUUIDs folder and ensure that it is up-to-date
	if [ ! -d "$MY_UUID_REPO" ]; then
		echo "UUID Script ERROR - The $MY_UUID_REPO_NAME submodule doesn't exist!!"
		exit 1
	fi
	cd "$MY_UUID_REPO"
	BRANCH=`git status | grep "branch" | cut -c 13-`
	IS_CLEAN=`git status | grep "nothing" | cut -c 1-17`
	if [ $BRANCH != "master" ]; then
		echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs to be on the master branch"
		exit 2
	fi
	if [[ -z $IS_CLEAN || $IS_CLEAN != "nothing to commit" ]]; then
		echo "UUID Script ERROR - $MY_UUID_REPO_NAME needs have a clean status"
		exit 3
	fi
	git pull
	
	
	#	Run the script there that generates the UUID list file
	echo "Generating UUID list file"
	/usr/bin/osascript "ProcessMailMessageInfo.applescript"
	
	
	#	Run the other script that will update my Info.plist file
	echo "Updating Info.plist file"
	/usr/bin/osascript "UpdateInfoPlist.applescript" "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"

This will delete and replace the entire `SupportedPluginCompatibilityUUIDs` array in the Info.plist with the values in the UUID text file.


