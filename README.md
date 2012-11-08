# Mail and MessageFramework UUID Manangement

This repository just helps facilitate maintaining and updating all of the UUIDs when Apple changes them in Mail and MessageFramework.

##	What Does it Contain?

I have extracted all of the `Mail` and `MessageFramework` `Info.plist` files from all of the Systems that Apple has shipped since 10.6. They are included in the repository. There is an applescript as well that you run to build out a text file containing all of the UUIDs that you would need to populate your `SupportedUUIDList` with.

When Apple comes out with a new system version, I only have to add the two `plist` files into the `PlistFolder` and when the script is rerun, it will reconstruct the output for you. This way it can be used easily in a build script to add the UUIDs to your plugin.

##	How do I call the Script?

Simply call it as any applescript. It can take 2 parameters, both of which are optional. One is for the OS version you want to start with (formatted as `10.x` or `10.x.y`) and the second is a parameter to suppress comments added to the output text file describing each UUID value (`-nc` or `-nocomment`).

Examples:

Output all UUIDs with comments

	osascript ProcessMailMessageInfo.applescript

Output all UUIDs since (and including) 10.7.0 with comments
	
	osascript ProcessMailMessageInfo.applescript 10.7
	
Output all UUIDs since (and including) 10.6.5 without comments

	osascript ProcessMailMessageInfo.applescript 10.6.5 -nc