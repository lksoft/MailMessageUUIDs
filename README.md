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

Finally there is a working example script included that you could just call directly from your Build Phases, which is what I do. If you want to limit the versions that you support or remove the comments, you'll need to change the `ProcessMailMessageInfo` line to add that info, but otherwise it should work as is. The script name is `GetLatestIntoPlugin.sh`.

This script will delete and replace the entire `SupportedPluginCompatibilityUUIDs` array in the Info.plist with the values in the UUID text file.

