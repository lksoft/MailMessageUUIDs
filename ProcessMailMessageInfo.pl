#!/usr/bin/perl -w

#use diagnostics;
#use Data::Dumper;
use strict;
use feature "switch";
use File::Basename;
use IO::Handle();
use IO::File();
use Mac::PropertyList qw(:all);


# Setup default values
my $startingOS = "10.1";
my $endingOS = "99.99.99";

my $showComments = 1;			# true
my $showHelp = 1;				# true
my $outputAsText = 0;			# false
my $outputAsPlist = 0;			# false
my $outputAsDefinitions = 0;	# false

my $outputSupportableFileName = 'SupportableUUIDList';
my $outputDefinitionsFileName = 'CompleteUUIDDefinitions.plist';

my $scriptDirPath = dirname(__FILE__);
my $plistDirPath = "$scriptDirPath/PlistFolder";

print "\n\n";

# Process command line arguments
foreach my $arg (@ARGV) {
	given ($arg) {
		when (/nc/) {
			$showComments = 0;
		}
		when (/def/) {
			$outputAsDefinitions = 1;
			if ($outputAsPlist || $outputAsText) {
				$showHelp = 1;
			}
			else {
				$showHelp = 0;
			}
		}
		when (/plist/) {
			$outputAsPlist = 1;
			if ($outputAsDefinitions || $outputAsText) {
				$showHelp = 1;
			}
			else {
				$showHelp = 0;
			}
		}
		when (/txt/) {
			$outputAsText = 1;
			if ($outputAsPlist || $outputAsDefinitions) {
				$showHelp = 1;
			}
			else {
				$showHelp = 0;
			}
		}
		when (/lt=([0-9\.]+)/) {
			$arg =~ /lt=([0-9\.]+)/;
			$endingOS = $1;
		}
		when (/10\.([0-9\.]+)/) {
			$startingOS = $arg;
		}
		when (/help/) {
			$showHelp = 1;
		}
	}
}

if ($showHelp) {
	print "ProcessMessageMailInfo.pl - script to create needed UUID lists for plugins and Mail Plugin Manager.\n\n";
	print "Usage: ProcessMessageMailInfo.pl def|plist|txt [nc] [version] [lt=version]\n\n";
	print "  def|plist|txt - One of these is required and they are exclusive.\n\n";
	print "    def   - Exports the CompleteUUIDDefinitions.plist file needed for Mail Plugin Manager.\n";
	print "    plist - Exports the SupportableUUIDList.plist file which can be used to insert into plugin compatibility lists.\n";
	print "    txt   - Exports the SupportableUUIDList.txt file listing compatibility IDs in an easily read list.\n\n";
	print "  nc - Suppresses comments added to the out of the plist or txt files.\n\n";
	print "  version - Indicates the OS version from which to add UUIDs - format is '10.xx.xx' or '10.xx'.\n";
	print "  lt=version - Include only OS versions less than this one - format is '10.xx.xx' or '10.xx'.\n\n";
	print "  help - Shows this text.\n\n";
	exit;
}

print "StartingOS: $startingOS\n";
print "EndingOS: $endingOS\n";
print "ShowComments: $showComments\n";
print "OutputAsText: $outputAsText\n";
print "OutputAsPlist: $outputAsPlist\n";
print "OutputAsDefinitions: $outputAsDefinitions\n";


# Test to see if this combo has been built already and if so, put it in place and return
my $archivedFilePath = "$scriptDirPath/Archived/$startingOS-$endingOS.plist";
if ($outputAsPlist && -e "$archivedFilePath") {
	my $outputFilePath = "$scriptDirPath/$outputSupportableFileName.plist";
	system("cp", $archivedFilePath, $outputFilePath);
	return; 
}


# Get the sorted complete list
my @sortedInfoList = buildSortedInfoListFromFolder($plistDirPath);

my $outputContents = '';
my $outputFilePath = '';
my $versionRangeString = "UUIDs for versions from $startingOS to $endingOS";

#	Export the definitions
if ($outputAsDefinitions) {
	# Get the message and mail lists for everything
	my @completeMailInfo = filterByFramework('com.apple.mail', @sortedInfoList);
	my @completeMessageInfo = filterByFramework('com.apple.MessageFramework', @sortedInfoList);
	
	# Create the two sections and put them together
	my $mailSection = convertListToPlistSection(@completeMailInfo);
	my $messageSection = convertListToPlistSection(@completeMessageInfo);
	$outputContents = concatenatePlistSections($mailSection, $messageSection);
	$outputFilePath = "$scriptDirPath/$outputDefinitionsFileName";

}
if ($outputAsText || $outputAsPlist) {
	# Get the message and mail lists from the filtered list
	my @filteredInfoList = filterForOSesWith($startingOS, $endingOS, @sortedInfoList);
	my @completeMailInfo = filterByFramework('com.apple.mail', @filteredInfoList);
	my @completeMessageInfo = filterByFramework('com.apple.MessageFramework', @filteredInfoList);
	$outputFilePath = "$scriptDirPath/$outputSupportableFileName";

	# Export as plist file
	if ($outputAsPlist) {
		my $mailComment = '';
		my $messageComment = '';
		if ($showComments) {
			$mailComment = "<string># $versionRangeString</string>\n";
			if ($#completeMessageInfo > 0) {
				$messageComment = "<string># All Message UUIDs</string>\n";
			}
		}
		$outputContents = '<array>';
		$outputContents .= $messageComment . convertListToUUIDPlist($showComments, @completeMessageInfo);
		$outputContents .= $mailComment . convertListToUUIDPlist($showComments, @completeMailInfo);
		$outputContents .= '</array>';
		$outputFilePath .= ".plist";
	}
	# Export as text file
	else {
		my $mailComment = '';
		my $messageComment = '';
		if ($showComments) {
			$mailComment = "# $versionRangeString\n";
			if ($#completeMessageInfo > 0) {
				$messageComment = "# All Message UUIDs\n";
			}
		}
		$outputContents = $messageComment . convertListToUUIDString($showComments, @completeMessageInfo);
		$outputContents .= $mailComment . convertListToUUIDString($showComments, @completeMailInfo);
		$outputFilePath .= ".txt";
	}
}

if (($outputContents ne '') && ($outputFilePath ne '')) {
	writeFileWithContents($outputFilePath, $outputContents);
	writeFileWithContents($archivedFilePath, $outputContents);
}


### END OF MAIN FUNCTION


sub buildSortedInfoListFromFolder { 

	my ($folder) = @_;
	my @list = ();
	if (opendir(DIR, $folder)) {
		while (defined(my $aFile = readdir(DIR))) {
			if ($aFile =~ m/-info.plist$/i) {
				my $versionInfo = {};
				$aFile =~ /([^-]+)-([^-]+)-([^-]+)/;
				my ($osVersion, $frameworkType, $osDescription) = ($1, $2, $3);
				my $filePath = "$folder/$aFile";
				my $data  = Mac::PropertyList::parse_plist_file($filePath)->as_perl;
				
				if (lc($osDescription) eq 'info.plist') {
					$osDescription = '';
				}
				
				$frameworkType = lc($frameworkType);
				
				$versionInfo->{'uuid'} = $data->{'PluginCompatibilityUUID'};
				$versionInfo->{'bundleID'} = $data->{'CFBundleIdentifier'};
				$versionInfo->{'osVersion'} = $osVersion;
				$versionInfo->{'infoType'} = $frameworkType;
				$versionInfo->{'otherDescription'} = $osDescription;
				$versionInfo->{'shortVersion'} = $data->{'CFBundleShortVersionString'};
				$versionInfo->{'versionNumber'} = $data->{'CFBundleVersion'};
				$versionInfo->{'expectedVersion'} = 'n/a';
				if ($frameworkType eq 'mail') {
					if (exists($data->{'ExpectedMessageVersion'})) {
						$versionInfo->{'expectedVersion'} = $data->{'ExpectedMessageVersion'};
					}
					$versionInfo->{'minimumOSVersion'} = $data->{'LSMinimumSystemVersion'};
				}
				else {
					if (exists($data->{'ExpectedMailVersion'})) {
						$versionInfo->{'expectedVersion'} = $data->{'ExpectedMailVersion'};
					}
				}

				push(@list, $versionInfo);
			}
		}
		closedir(DIR);
	}

	return sort { $a->{'versionNumber'} <=> $b->{'versionNumber'} } @list;
};

sub filterForOSesWith { 
	
	my ($startingOSToSupport, $endingOSToSupport, @infoList) = @_;
	
	if ($startingOSToSupport eq '') {
		return @infoList;
	}
	
	$startingOSToSupport = normalizedVersionString($startingOSToSupport);
	$endingOSToSupport = normalizedVersionString($endingOSToSupport);
	my @filteredList = ();
	my $foundStart = 0;
	foreach my $aDict (@infoList) {
		my $osVersion = normalizedVersionString($aDict->{'osVersion'});
		if ($osVersion ge $endingOSToSupport) {
			last;
		}
		if ($foundStart || ($osVersion ge $startingOSToSupport)) {
			$foundStart = 1;
			push(@filteredList, $aDict);
		}
	}
	
	return @filteredList;
};

sub filterByFramework {
	my ($bundleID, @list) = @_;
	my $infoTypeKey = 'mail';
	if ($bundleID ne 'com.apple.mail') {
		$infoTypeKey = 'message';
	}
	
	my @versionList = ();
	
	my $startOS = '';
	my $endOS = '';
	my $previousRecord = {'uuid' => '', 'osVersion' => '', 'shortVersion' => '9.0'};
	
	foreach my $aDict (@list) {
		if ($bundleID eq $aDict->{'bundleID'}) {
			# Establish base version string
			if ($startOS eq '') {
				$startOS = $aDict->{'osVersion'};
			}
			
			# Check to see if the uuid or version of the framework has changed
			if (($aDict->{'uuid'} ne $previousRecord->{'uuid'}) || 
				(normalizedVersionString($aDict->{'shortVersion'}) ne normalizedVersionString($previousRecord->{'shortVersion'}))) {
				
				# If we have got a previous and end version then add the info
				if ($previousRecord->{'uuid'} ne '') {
					my $newInfo = {
						'startOS' => $startOS,
						'endOS' => $endOS,
						'type' => $infoTypeKey,
						'displayVersion' => $previousRecord->{'shortVersion'},
						'uuid' => $previousRecord->{'uuid'},
						'versionNumber' => $previousRecord->{'versionNumber'},
						'otherDescription' => $previousRecord->{'otherDescription'}
					};
					
					push(@versionList, $newInfo);
				}
				
				$startOS = $aDict->{'osVersion'};
			}
			$previousRecord = $aDict;
			$endOS = $previousRecord->{'osVersion'};
		}
	}
	
	if ($startOS ne '') {
		push(@versionList, {
			'startOS' => $startOS,
			'endOS' => $previousRecord->{'osVersion'},
			'type' => $infoTypeKey,
			'displayVersion' => $previousRecord->{'shortVersion'},
			'uuid' => $previousRecord->{'uuid'},
			'versionNumber' => $previousRecord->{'versionNumber'},
			'otherDescription' => $previousRecord->{'otherDescription'}
		});
	}
	
	return @versionList;
}

sub convertListUsingDelimiters {
	my ($addComments, $openDelim, $closeDelim, @list) = @_;
	my $output = '';
	my %uuidList = ();
		
	foreach my $aRecord (@list) {
		if (!exists($uuidList{$aRecord->{'uuid'}})) {
			
			if ($addComments) {
				my $buildInfo = '';
				if ($aRecord->{'otherDescription'} ne '') {
					$buildInfo .= " (build $aRecord->{'otherDescription'})";
				}
				$output .= "$openDelim# For $aRecord->{'type'} version $aRecord->{'displayVersion'} ($aRecord->{'versionNumber'}) on OS X Version $aRecord->{'startOS'}$buildInfo$closeDelim\n";
			}
			$output .= "$openDelim$aRecord->{'uuid'}$closeDelim\n";
			
			$uuidList{$aRecord->{'uuid'}} = 1;
		}
	}
	return $output;
	
}

sub convertListToUUIDString {
	my ($addComments, @list) = @_;
	convertListUsingDelimiters($addComments, '', '', @list);
}

sub convertListToUUIDPlist {
	my ($addComments, @list) = @_;
	convertListUsingDelimiters($addComments, "<string>", "</string>", @list);
}

sub convertListToPlistSection {
	my @list = @_;
	
	my $startRecord = {'uuid' => 'empty'};
	my @distinctList = ();
	foreach my $infoRecord (@list) {
		
		# First item alwasy sets start record
		if ($startRecord->{'uuid'} eq 'empty') {
			$startRecord = $infoRecord;
		}
		
		# Add the record to our list if the uuid has changed
		if ($infoRecord->{'uuid'} ne $startRecord->{'uuid'}) {
			push(@distinctList, $startRecord);
			$startRecord = $infoRecord;
		}
		else {
			# Set the endOS and displayVersion on the start info to the current one
			$startRecord->{'endOS'} = $infoRecord->{'endOS'};
			$startRecord->{'displayVersion'} = $infoRecord->{'displayVersion'};
		}
	}
	# Append the last record to the list as well
	push(@distinctList, $startRecord);
	
	# Establish the comparators
	my $testRecord = $distinctList[0];
	my $comparator = 50;
	if ($testRecord->{'type'} ne 'mail') {
		$comparator = 1000;
	}
	
	# Write the list to the output
	my %uuidList = ();
	my $sectionOutput = '';
	foreach my $outRecord (@distinctList) {
		if (!exists($uuidList{$outRecord->{'uuid'}})) {
			
			# Increment the comparator
			$comparator++;
			
			# Construct the string
			$sectionOutput .= '';
			$sectionOutput .= "<key>$outRecord->{'uuid'}</key><dict>";
			$sectionOutput .= "<key>earliest-os-version-display</key><string>$outRecord->{'startOS'}</string>";
			$sectionOutput .= "<key>latest-os-version-display</key><string>$outRecord->{'endOS'}</string>";
			$sectionOutput .= "<key>latest-version-comparator</key><integer>$comparator</integer>";
			$sectionOutput .= "<key>type</key><string>$outRecord->{'type'}</string>";
			$sectionOutput .= "<key>type-version-display</key><string>$outRecord->{'displayVersion'}</string>";
			$sectionOutput .= "<key>type-version</key><real>$outRecord->{'versionNumber'}</real>";
			$sectionOutput .= "</dict>";
			
			# Then add the uuid to the hash
			$uuidList{$outRecord->{'uuid'}} = 1;
		}
	}
	
	return $sectionOutput;
}

sub concatenatePlistSections {
	my @sections = @_;
	my $output = '<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>contents</key><dict>';
	
	foreach my $aSection (@sections) {
		$output .= $aSection;
	}
	
	$output .= '</dict><key>date</key><date-placeholder>[(REPLACE THIS DATE AND SURROUNDING MARKUP USING date INSTEAD OF string)]</date-placeholder></dict></plist>';
	
	return $output;
}

sub writeFileWithContents {
	my ($filePath, $contents) = @_;
	# Write the contents to the file
	open(FH, ">$filePath") or die "$0: $filePath: $!";
	print FH $contents;
	close(FH);
}

sub normalizedVersionString {
	my ($version) = @_;
	$version =~ /([0-9]+)\.([0-9]+)[\.]{0,1}([0-9]{0,2})/;
	my ($major, $minor, $bug) = ($1, $2, $3);
	return sprintf "%02s.%02s.%02s", $major, $minor, $bug;
}
