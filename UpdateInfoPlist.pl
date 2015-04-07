#!/usr/bin/perl -w

#  UpdateInfoPList.pl
#  MailMessageUUIDs
#
#  Created by Scott Little on 4/6/13.
#  Copyright (c) 2013 Little Known Software. All rights reserved.

use strict;

die "$0: Must be run from Xcode" unless $ENV{"BUILT_PRODUCTS_DIR"};

# Get the current git branch and sha hash
# 	to use them to set the CFBundleVersion value
my $INFO = "$ENV{BUILT_PRODUCTS_DIR}/$ENV{INFOPLIST_PATH}";

my $baseDir = ".";
if ($ENV{"SRCROOT"}) {
	$baseDir = $ENV{"SRCROOT"};
}
my $NEW_UUIDS = `cat "$ARGV[0]"`;

die "$0: No UUID content found" unless $NEW_UUIDS;

# Get the contents as an XML format
my $info = `plutil -convert xml1 -o - "$INFO"`;

# replace both the branch name and the hash value
$info =~ s/<string>\[UUIDS_HERE\]<\/string>/$NEW_UUIDS/;

# Rewrite the contents to the file
open(FH, ">$INFO") or die "$0: $INFO: $!";
print FH $info;
close(FH);

# Rest the contents of the file to the binary version
`plutil -convert binary1 "$INFO"`;