--	Create UUID text file and Definitions for MPM

property outputAsJSON : false
property outputAsDefinitions : false
property outputAsPlist : false
property outputFileName : "CompleteMailInfo"
property outputUUIDListFileName : "SupportableUUIDList"
property outputUUIDDefinitionsFileName : "CompleteUUIDDefinitions.plist"
property startingMailComparator : 50
property startingMessageComparator : 1000
property endingComparator : 999999
property outputComments : true

on run argv
	
	--	Handle parameters
	set startingOS to "10.6" --	default value
	set endingOS to "" --	default value
	if ((count of argv) > 0) then
		repeat with param in argv
			if (param starts with "lt=") then
				set TID to AppleScript's text item delimiters
				set AppleScript's text item delimiters to "="
				set endingOS to text item 2 of param
				set AppleScript's text item delimiters to TID
			end if
			if (param starts with "10.") then
				set startingOS to param
			end if
			if (param contains "nc") then
				set outputComments to false
			end if
			if (param contains "defs") then
				set outputAsDefinitions to true
			end if
			if (param contains "plist") then
				set outputAsPlist to true
			end if
		end repeat
	end if
	
	--	Should get the contents from the current directory
	tell application "Finder"
		set scriptPath to path to me
		set infoFolder to container of scriptPath
		set plistFolder to ((infoFolder as string) & "PlistFolder:" as alias)
	end tell
	
	--	Get the info lists, sort it and filter based on OS requirements
	set infoList to buildInfoListfromFolder(plistFolder)
	set infoList to sortByVersionNumber(infoList)
	set filteredInfoList to filterForOSesWith(infoList, startingOS, endingOS)
	
	--	Create sorted, unique lists of Mail and Message info
	set completeMailInfo to filterMailInfo(filteredInfoList)
	set completeMessageInfo to filterMessageInfo(filteredInfoList)
	
	--	Export a list of all of the UUIDs for both parts as plist file
	if (outputAsPlist and outputUUIDListFileName is not equal to "") then
		--	Write the contents of all uuids as a plist
		if outputComments then
			set mailComment to "<string># All Mail UUIDs</string>" & return
			set messageComment to "<string># All Message UUIDs</string>" & return
		else
			set mailComment to ""
			set messageComment to ""
		end if
		set outputContents to "<array>"
		set outputContents to outputContents & messageComment & convertListToUUIDPList(completeMessageInfo)
		set outputContents to outputContents & mailComment & convertListToUUIDPList(completeMailInfo)
		set outputContents to outputContents & "</array>"
		set outFilePath to (infoFolder as string) & outputUUIDListFileName & ".plist"
		writeFileWithContents(outFilePath, outputContents)

	--	Export a list of all of the UUIDs for both parts as simple file
	else if (outputUUIDListFileName is not equal to "") then
		--	Write the contents of all uuids as a simple list
		if outputComments then
			set mailComment to "# All Mail UUIDs" & return
			set messageComment to "# All Message UUIDs" & return
		else
			set mailComment to ""
			set messageComment to ""
		end if
		set outputContents to messageComment & convertListToUUIDStringList(completeMessageInfo)
		set outputContents to outputContents & mailComment & convertListToUUIDStringList(completeMailInfo)
		set outFilePath to (infoFolder as string) & outputUUIDListFileName & ".txt"
		writeFileWithContents(outFilePath, outputContents)
	end if
	
	--	If we should create the UUID Definitions file
	if (outputAsDefinitions and outputUUIDDefinitionsFileName is not equal to "") then
		--	Then refilter the info without OS filtering
		set completeMailInfo to filterMailInfo(infoList)
		set completeMessageInfo to filterMessageInfo(infoList)
		
		--	Build plist content sections for each
		set mailSection to convertListToPlistSection(completeMailInfo)
		set messageSection to convertListToPlistSection(completeMessageInfo)
		
		--	Then stick them together
		set outputContents to createPlistOutputWithSections({mailSection, messageSection} as list)
		
		-- 	And write them out
		set outFilePath to (infoFolder as string) & outputUUIDDefinitionsFileName
		writeFileWithContents(outFilePath, outputContents)
	end if
	
	--	Do JSON if desired
	if (outputAsJSON) then
		--	Write the contents of the JSON out to the current folder as well
		set outputContents to convertListToJSON(infoList)
		set outFilePath to (infoFolder as string) & outputFileName & ".json"
		writeFileWithContents(outFilePath, outputContents)
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
		
		--	Ensure that we skip any plist files that don't end with "info.plist"
		if (fileName ends with "-info.plist") then
			
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
				--	First see if the file has a PluginCompatibilityID
				set uuid to ""
				try
					set uuid to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " PluginCompatibilityUUID")
				on error errMsg
				end try
				if (uuid is not "") then
					--	Then use defaults to get values out of each file
					set bundleID to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleIdentifier")
					set shortVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleShortVersionString")
					set versionNumber to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " CFBundleVersion")
					
					--	Then branch for the other values based on the type
					set expectedVersion to "n/a"
					if (infoType is "Mail") then
						try
							set expectedVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " ExpectedMessageVersion")
						on error errMsg
						end try
						set minimumOSVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " LSMinimumSystemVersion")
					else
						try
							set expectedVersion to do shell script ("defaults read " & quote & (POSIX path of aFile) & quote & " ExpectedMailVersion")
						on error errorMsg
						end try
						set minimumOSVersion to ""
					end if
					
					--	Add the record to our list
					set end of infoList to ({fileName:fileName, osVersion:osVersion, otherDescription:otherDescription, bundleID:bundleID, shortVersion:shortVersion, versionNumber:versionNumber, uuid:uuid, expectedVersion:expectedVersion} as record)
				end if
				
			end if
			
		end if --	Skipping files that aren't "-Info.plist"
		
	end repeat
	
	return infoList
end buildInfoListfromFolder


on filterMailInfo(theList)
	return FilterInfo(theList, "com.apple.mail", "mail")
end filterMailInfo


on filterMessageInfo(theList)
	return FilterInfo(theList, "com.apple.MessageFramework", "message")
end filterMessageInfo

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
					--	log {startOS:startOS, endOS:endVersionFromVersions(osVersion of previousRecord, osVersion of aRecord), type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord}
					set end of versionList to ({startOS:startOS, endOS:endVersionFromVersions(osVersion of previousRecord, osVersion of aRecord), type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord, versionNumber:versionNumber of previousRecord, otherDescription:otherDescription of previousRecord} as record)
				end if
				
				--	Establish new values for this group
				set startOS to osVersion of aRecord
			end if
			
			set previousRecord to aRecord
			
		end if
	end repeat
	--	log {startOS:startOS, endOS:osVersion of aRecord, type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord}
	set end of versionList to ({startOS:startOS, endOS:osVersion of aRecord, type:typeKey, displayVersion:(shortVersion of previousRecord), uuid:uuid of previousRecord, versionNumber:versionNumber of previousRecord, otherDescription:otherDescription of previousRecord} as record)
	
	return versionList
end FilterInfo


on endVersionFromVersions(previousVersion, currentVersion)
	
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
	
end endVersionFromVersions


on sortByVersionNumber(theList)
	repeat with i from 1 to (count of theList) - 1
		repeat with j from i + 1 to count of theList
			if versionNumber of item j of theList < versionNumber of item i of theList then
				set temp to item i of theList
				set item i of theList to item j of theList
				set item j of theList to temp
			end if
		end repeat
	end repeat
	return theList
end sortByVersionNumber

on filterForOSesWith(theList, firstOSToSupport, lessThanOSToSupport)
	
	--	Just return the list of there is no criteria
	if ((firstOSToSupport is "") and (lessThanOSToSupport is "")) then
		return theList
	end if
	
	--	Otherwise set starting values
	set resultList to {} as list
	set foundStart to false
	--	Look through list until we find a match and then add all the rest
	repeat with infoItem in theList
		if ((osVersion of infoItem is equal to lessThanOSToSupport) or (osVersion of infoItem begins with lessThanOSToSupport)) then
			exit repeat
		end if
		if (foundStart or (osVersion of infoItem is equal to firstOSToSupport) or (osVersion of infoItem begins with firstOSToSupport)) then
			set foundStart to true
			set end of resultList to infoItem
		end if
	end repeat
	
	return resultList
end filterForOSesWith


on convertListToUUIDStringList(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to ""
	set uuidList to {} as list
	
	repeat with mailInfo in theList
		
		if (uuidList does not contain (uuid of mailInfo)) then
			--	Build out the string contents
			if (outputComments) then
				set buildInfo to ""
				if ((otherDescription of mailInfo) is not "") then
					set buildInfo to " (build " & (otherDescription of mailInfo) & ")"
				end if
				set infoData to infoData & "'# For " & (type of mailInfo) & " version " & (displayVersion of mailInfo) & " (" & (versionNumber of mailInfo) & ") on OS X Version " & (startOS of mailInfo) & buildInfo & "'" & return
			end if
			set infoData to infoData & (uuid of mailInfo) & return
			
			set end of uuidList to (uuid of mailInfo)
		end if
		
	end repeat
	
	return infoData
	
end convertListToUUIDStringList

on convertListToUUIDPList(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to ""
	set uuidList to {} as list
	
	repeat with mailInfo in theList
		
		if (uuidList does not contain (uuid of mailInfo)) then
			--	Build out the plist contents
			if (outputComments) then
				set buildInfo to ""
				if ((otherDescription of mailInfo) is not "") then
					set buildInfo to " (build " & (otherDescription of mailInfo) & ")"
				end if
				set infoData to infoData & "<string># For " & (type of mailInfo) & " version " & (displayVersion of mailInfo) & " (" & (versionNumber of mailInfo) & ") on OS X Version " & (startOS of mailInfo) & buildInfo & "</string>" & return
			end if
			set infoData to infoData & "<string>" & (uuid of mailInfo) & "</string>" & return
			
			set end of uuidList to (uuid of mailInfo)
		end if
		
	end repeat
	
	return infoData
	
end convertListToUUIDPList

on convertListToPlistSection(theList)
	
	-- use a repeat loop to loop over a list of something
	set infoData to ""
	set uuidList to {} as list
	set mailComparator to startingMailComparator
	set messageComparator to startingMessageComparator
	
	--	Rebuild the list consolidating any duplicate records	
	set startInfo to {uuid:"empty"} as record
	set newList to {} as list
	repeat with anInfo in theList
		
		--	For the first time, just assign the current record to the startInfo
		if (uuid of startInfo is equal to "empty") then
			set startInfo to anInfo
		end if
		
		--	If we have a change of UUIDs, then write the last one
		if (uuid of startInfo is not equal to uuid of anInfo) then
			--	Add the record to the list
			set end of newList to startInfo
			--	log startInfo
			--	Reset the start to the current one
			set startInfo to anInfo
		else
			--	Else set the endOS from the start to that of the current
			set the endOS of startInfo to endOS of anInfo
			set the displayVersion of startInfo to displayVersion of anInfo
		end if
	end repeat
	--	Add the last record to the list
	--	log startInfo
	set end of newList to startInfo
	
	--	Then write out the new list
	repeat with mailInfo in newList
		
		if (uuidList does not contain (uuid of mailInfo)) then
			
			set comparator to 0
			if (type of mailInfo is "mail") then
				set mailComparator to mailComparator + 1
				set comparator to mailComparator
			else
				set messageComparator to messageComparator + 1
				set comparator to messageComparator
			end if
			
			--	Build out the string contents
			set infoData to infoData & "<key>" & uuid of mailInfo & "</key><dict>"
			set infoData to infoData & "<key>earliest-os-version-display</key><string>" & startOS of mailInfo & "</string>"
			set infoData to infoData & "<key>latest-os-version-display</key><string>" & endOS of mailInfo & "</string>"
			set infoData to infoData & "<key>latest-version-comparator</key><integer>" & comparator & "</integer>"
			set infoData to infoData & "<key>type</key><string>" & type of mailInfo & "</string>"
			set infoData to infoData & "<key>type-version-display</key><string>" & displayVersion of mailInfo & "</string>"
			set infoData to infoData & "<key>type-version</key><real>" & versionNumber of mailInfo & "</real>"
			set infoData to infoData & "</dict>"
			
			set end of uuidList to (uuid of mailInfo)
		end if
		
	end repeat
	
	return infoData
	
end convertListToPlistSection

on convertListToJSON(theList)
	
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
	
end convertListToJSON


on createPlistOutputWithSections(sectionList)
	set infoData to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>contents</key>
	<dict>"
	
	repeat with aSection in sectionList
		set infoData to infoData & aSection
	end repeat
	
	set infoData to infoData & return & "	</dict>
	<key>date</key>
	<string>[(REPLACE THIS DATE AND SURROUNDING MARKUP USING date INSTEAD OF string)]</string>
</dict>
</plist>"
	--	Date Format => 2012-11-02T16:00:00Z
	
	return infoData
	
end createPlistOutputWithSections



on writeFileWithContents(fileName, theContents)
	if my checkExistence(fileName) then --Attempt to delete existing file
		my deleteFile(fileName)
	end if
	try
		set theFile to open for access fileName with write permission
		write theContents to theFile as text
		close access theFile
	on error
		try
			close access theFile
		end try
	end try
end writeFileWithContents

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
