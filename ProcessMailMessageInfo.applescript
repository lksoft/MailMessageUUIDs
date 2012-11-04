--	Create a CSV file for import into a database

property outputAsJSON : false
property outputFileName : "CompleteMailInfo"
property outputUUIDListFileName : "SupportableUUIDList.txt"
property outputUUIDDefinitionsFileName : "CompleteUUIDDefinitions.plist"

on run
	
	--	Should get the contents from the current directory
	tell application "Finder"
		set scriptPath to path to me
		set infoFolder to container of scriptPath
	end tell
	
	--	Get the info lists
	set infoList to buildInfoListfromFolder(infoFolder)
	
	--	Create sorted, unique lists of Mail and Message info
	set completeMailInfo to FilterMailInfo(infoList)
	set completeMessageInfo to FilterMessageInfo(infoList)
	
	--	Export a list of all of the UUIDs for both parts as simple file
	if (outputUUIDListFileName is not equal to "") then
		
		--	Write the contents of all uuids as a simple list
		set outputContents to "# All Mail UUIDs" & return & convertListToUUIDStringList(completeMailInfo)
		set outputContents to outputContents & "# All Message UUIDs" & return & convertListToUUIDStringList(completeMessageInfo)
		set outFilePath to (infoFolder as string) & outputUUIDListFileName
		WriteFileWithContents(outFilePath, outputContents)
	end if
	
	
	--	Do JSON if desired
	if (outputAsJSON) then
		
		--	Write the contents of the JSON out to the current folder as well
		set outputContents to convertListtoJSON(infoList)
		set outFilePath to (infoFolder as string) & outputFileName & ".json"
		if my checkExistence(outFilePath) then --Attempt to delete existing file
			my deleteFile(outFilePath)
		end if
		try
			set theFile to open for access outFilePath with write permission
			write outputContents to theFile
			close access theFile
		on error
			try
				close access theFile
			end try
		end try
	end if
	
end run

on buildInfoListfromFolder(theInfoFolder)
	
	--	Get the list of info files
	tell application "Finder"
		set infoFiles to (files of theInfoFolder whose name extension is "plist") as alias list
	end tell
	
	set TID to AppleScript's text item delimiters
	
	--	Our list	
	set infoList to {} as list
	repeat with aFile in infoFiles
		
		--	Get the file's name
		tell application "Finder"
			set fileName to name of aFile
		end tell
		
		--	Break that into the keys we need...
		set AppleScript's text item delimiters to "-"
		set osVersion to text item 1 of fileName
		set infoType to text item 2 of fileName
		if (count of text items of fileName) > 3 then
			set otherDescription to text item 3 of fileName
		else
			set otherDescription to ""
		end if
		set AppleScript's text item delimiters to TID
		
		--	Ensure that this file is the correct type		
		set executableName to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleExecutable")
		if (executableName is not equal to infoType) then
			log "Mismatched type ['" & infoType & "'] for executable ['" & executableName & "']"
		else
			--	Then use defaults to get values out of each file
			set bundleID to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleIdentifier")
			set shortVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleShortVersionString")
			set versionNumber to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleVersion")
			set uuid to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " PluginCompatibilityUUID")
			
			--	Then branch for the other values based on the type
			if (infoType is "Mail") then
				set expectedVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " ExpectedMessageVersion")
				set minimumOSVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " LSMinimumSystemVersion")
			else
				set expectedVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " ExpectedMailVersion")
				set minimumOSVersion to ""
			end if
			
			--	Add the record to our list
			set end of infoList to ({fileName:fileName, osVersion:osVersion, otherDescription:otherDescription, bundleID:bundleID, shortVersion:shortVersion, versionNumber:versionNumber, uuid:uuid, expectedVersion:expectedVersion} as record)
			
		end if
		
	end repeat
	
	return infoList
end buildInfoListfromFolder


on FilterMailInfo(theList)
	return FilterInfo(theList, "com.apple.mail", "mail")
end FilterMailInfo


on FilterMessageInfo(theList)
	return FilterInfo(theList, "com.apple.MessageFramework", "message")
end FilterMessageInfo

on FilterInfo(theList, bundleMatch, typeKey)
	
	set versionList to {}
	
	set startOS to ""
	set previousRecord to {osVersion:"", uuid:""} as record
	
	repeat with aRecord in theList
		if (bundleID of aRecord is equal to bundleMatch) then
			
			--	log "osVersion=" & osVersion of aRecord & "  -- version=" & shortVersion of aRecord & "  --  uuid=" & uuid of aRecord
			
			--	Ensure a basic start OS
			if startOS is "" then
				set startOS to osVersion of aRecord
			end if
			
			--	If the UUID has changed then also set the startOS
			if ((uuid of aRecord) is not equal to (uuid of previousRecord)) or ((shortVersion of aRecord) is not equal to (shortVersion of previousRecord)) then
				
				--	Write out previous grouping
				if (uuid of previousRecord is not "") then
					set end of versionList to ({startOS:startOS, endOS:EndVersionFromVersions(osVersion of previousRecord, osVersion of aRecord), type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord} as record)
				end if
				
				--	Establish new values for this group
				set startOS to osVersion of aRecord
			end if
			
			set previousRecord to aRecord
			
		end if
	end repeat
	set end of versionList to ({startOS:startOS, endOS:osVersion of aRecord, type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord} as record)
	
	return versionList
end FilterInfo


on EndVersionFromVersions(previousVersion, currentVersion)
	
	if (currentVersion is equal to previousVersion) then
		return currentVersion
	end if
	
	if (currentVersion ends with ".0") then
		if (previousVersion is equal to "") then
			return currentVersion
		else
			return previousVersion
		end if
	end if
	
	set TID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "."
	set versionParts to text items of currentVersion
	set the last item of versionParts to ((last item of versionParts) - 1)
	set myVersion to versionParts as string
	set AppleScript's text item delimiters to TID
	
	return myVersion
	
end EndVersionFromVersions


on sortByVersionNumber(theList)
	repeat with i from 1 to (count of theList) - 1
		repeat with j from i + 1 to count of theList
			if versionNumber of item j of myList < versionNumber of item i of theList then
				set temp to item i of theList
				set item i of theList to item j of theList
				set item j of theList to temp
			end if
			log theList
		end repeat
	end repeat
	return theList
end sortByVersionNumber


on convertListToUUIDStringList(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to ""
	set uuidList to {} as list
	
	repeat with mailInfo in theList
		
		if (uuidList does not contain (uuid of mailInfo)) then
			--	Build out the string contents
			set infoData to infoData & "# For version " & (displayVersion of mailInfo) & "[" & (startOS of mailInfo) & "]" & " of " & (type of mailInfo) & return & (uuid of mailInfo) & return
			
			set end of uuidList to (uuid of mailInfo)
		end if
		
	end repeat
	
	return infoData
	
end convertListToUUIDStringList

on convertListtoJSON(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to "{"
	set counter to 0
	
	repeat with mailInfo in theList
		
		--	Build out the json contents
		set comma to ","
		if counter is 0 then
			set comma to ""
		end if
		set infoData to infoData & comma & return & quote & (fileName of mailInfo) & quote & ": {" & return & "\"osVersion\": \"" & (osVersion of mailInfo) & "\"," & return & "\"otherDescription\": \"" & (otherDescription of mailInfo) & "\"," & return & "\"bundleID\": \"" & (bundleID of mailInfo) & "\"," & return & "\"shortVersion\": \"" & (shortVersion of mailInfo) & "\"," & return & "\"version\": " & (versionNumber of mailInfo) & "," & return & "\"uuid\": \"" & (uuid of mailInfo) & "\"," & return & "\"otherExpectedVersion\": " & (expectedVersion of mailInfo) & return & "}"
		
		--	Increment our counter
		set counter to counter + 1
	end repeat
	
	set infoData to infoData & return & "}"
	
	return infoData
	
end convertListtoJSON

on WriteFileWithContents(fileName, theContents)
	if my checkExistence(fileName) then --Attempt to delete existing file
		my deleteFile(fileName)
	end if
	try
		set theFile to open for access fileName with write permission
		write theContents to theFile
		close access theFile
	on error
		try
			close access theFile
		end try
	end try
end WriteFileWithContents

on checkExistence(fileOrFolderToCheck)
	try
		alias fileOrFolderToCheck
		return true
	on error
		return false
	end try
end checkExistence

on deleteFile(theFilePath)
	try
		set p to POSIX path of file theFilePath
		do shell script "rm " & quoted form of p
	end try
end deleteFile