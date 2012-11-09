--	Use this script to insert the UUID list into an Info.pist file

property uuidListFileName : "SupportableUUIDList.txt"
property isTesting : true

on run argv
	
	--	Ensure that we actually have the uuid text input file
	tell application "Finder"
		set scriptPath to path to me
		set scriptFolder to container of scriptPath
	end tell
	set uuidInputFilePath to (scriptFolder as string) & uuidListFileName
	if (not checkExistence(uuidInputFilePath)) then
		log "The " & uuidListFileName & " file does not exist, so I cannot continue"
		return 2
	end if
	
	--	Get the proper output file to use	
	if (isTesting) then
		set infoPlistFilePath to (scriptFolder as string) & "testInfo.plist"
	else
		--	Get the info plist file path from the arguments
		if ((count of argv) > 0) then
			set infoPlistFilePath to item 1 of argv
		else
			log "No Info.plist file path was given"
			return 1
		end if
	end if
	
	--	Try to remove all of the existing values, if there are any
	try
		do shell script "defaults delete " & quote & (POSIX path of (infoPlistFilePath as alias)) & quote & " SupportedPluginCompatibilityUUIDs"
	on error
		--	Don't do anything
	end try
	
	--	Open the uuidList file
	set theFile to open for access uuidInputFilePath
	set theText to read theFile
	close access theFile
	set uuidValues to paragraphs of theText
	
	--	Read in each line
	repeat with aUUID in uuidValues
		
		--	For each line that is not empty, add that to the array of the SupportedUUIDList in the InfoPlist file
		if (length of aUUID is not 0) then
			do shell script "defaults write " & quote & (POSIX path of (infoPlistFilePath as alias)) & quote & " SupportedPluginCompatibilityUUIDs -array-add '" & aUUID & "'"
		end if
		
	end repeat
	
end run

on checkExistence(fileOrFolderToCheck)
	try
		alias fileOrFolderToCheck
		return true
	on error
		return false
	end try
end checkExistence

