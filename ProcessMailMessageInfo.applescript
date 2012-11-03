--	Create a CSV file for import into a database

property outputAsJSON : false
property outputAsCSV : false
property outputFileName : "ImportMailInfo"

on run
	
	--	Should get the contents from the current directory
	tell application "Finder"
		set scriptPath to path to me
		set infoFolder to container of scriptPath
	end tell
	
	--	Get the info lists
	set infoList to buildInfoListfromFolder(infoFolder)
	
	--	Create sorted, unique lists of Mail and Message info
	set uniqueMailInfo to FilterUniqueMailInfo(infoList)
	set uniqueMessageInfo to FilterUniqueMessageInfo(infoList)
	
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
	
	--	Do CSV if desired
	if (outputAsCSV) then
		
		--	Write the contents of the CSV out to the current folder as well
		set outputContents to convertListtoCSV(infoList)
		set outFilePath to (infoFolder as string) & outputFileName & ".csv"
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


on FilterUniqueMailInfo(theList)
	
	log "START MAIL"
	set versionList to {}
	
	set startOS to ""
	set previousRecord to {uuid:""} as record
	set previousOS to ""
	set previousShortVersion to ""
	set previousUUID to ""
	
	repeat with aRecord in theList
		if (bundleID of aRecord is equal to "com.apple.mail") then
			
			log "osVersion=" & osVersion of aRecord & "  -- version=" & shortVersion of aRecord & "  --  uuid=" & uuid of aRecord
			
			--	Ensure a basic start OS
			if startOS is "" then
				set startOS to osVersion of aRecord
			end if
			
			--	If the UUID has changed then also set the startOS
			if ((uuid of aRecord) is not equal to uuid of previousRecord) then
				
				--	Write out previous grouping
				if (uuid of previousRecord is not "") then
					if (previousOS is "") then
						set previousOS to (osVersion of aRecord)
					end if
					set newRecord to {startOS:startOS, endOS:(osVersion of previousRecord), type:"mail", displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord}
					log return
					log newRecord
					log return
				end if
				
				--	Establish new values for this group
				set startOS to osVersion of aRecord
			end if
			
			set previousRecord to aRecord
			set previousOS to osVersion of aRecord
			set previousUUID to uuid of aRecord
			set previousShortVersion to shortVersion of aRecord
			
		end if
	end repeat
	set lastRecord to {startOS:startOS, endOS:(osVersion of previousRecord), type:"mail", displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord}
	log return
	log lastRecord
	log return
	log "END MAIL"
	
end FilterUniqueMailInfo


on FilterUniqueMessageInfo(theList)
	
end FilterUniqueMessageInfo


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


on convertListtoCSV(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to quote & "filename" & quote & ", " & quote & "os_version" & quote & ", " & quote & "other_desc" & quote & ", " & quote & "bundle_id" & quote & ", " & quote & "short_version" & quote & ", " & quote & "version" & quote & ", " & quote & "uuid" & quote & ", " & quote & "other_expected_version" & quote & ", " & quote & "min_os_version" & quote
	
	repeat with mailInfo in theList
		
		--	Build out the csv contents
		set infoData to infoData & return & quote & (fileName of mailInfo) & quote & ", " & quote & (osVersion of mailInfo) & quote & ", " & quote & (otherDescription of mailInfo) & quote & ", " & quote & (bundleID of mailInfo) & quote & ", " & quote & (shortVersion of mailInfo) & quote & ", " & (versionNumber of mailInfo) & ", " & quote & (uuid of mailInfo) & quote & ", " & (expectedVersion of mailInfo)
		
	end repeat
	
	return infoData
	
end convertListtoCSV

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