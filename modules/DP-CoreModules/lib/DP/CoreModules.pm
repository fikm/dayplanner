# Day Planner core modules
# A graphical Day Planner written in perl that uses Gtk2
# Copyright (C) Eskild Hustvedt 2006, 2007, 2008
# $Id: dayplanner 1985 2008-02-03 12:48:43Z zero_dogg $
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

our $Version = '0.9';
my $VersionName = 'SVN';

# NOTE:
# THIS DOES NOT DEFINE A PACKAGE, ON PURPOSE!
# Some functions start with P_, this is because the "proper" function is here,
# while other components might have convenience wrappers.

# Purpose: Find out if a command is in PATH or not
# Usage: InPath(COMMAND);
sub InPath {
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and ! -d "$_/@_" ) {   return 1; } } return 0;
}

# Purpose: Detect the user config  directory
# Usage: DetectConfDir(MAEMO?);
sub DetectConfDir {
	my $Maemo = shift;
	# First detect the HOME directory, and set $ENV{HOME} if successfull,
	# if not we just fall back to the value of $ENV{HOME}.
	my $HOME = getpwuid($>);
	if(-d $HOME) {
		$ENV{HOME} = $HOME;
	}
	if(not $Maemo)
	{
		# Compatibility mode, using the old conf dir
		if(-d "$ENV{HOME}/.dayplanner") {
			return("$ENV{HOME}/.dayplanner");
		}
	}
	# Check for XDG_CONFIG_HOME in the env
	my $XDG_CONFIG_HOME;
	if(defined($ENV{XDG_CONFIG_HOME})) {
		$XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
	} else {
		if(defined($ENV{HOME}) and length($ENV{HOME})) {
			# Verify that HOME is set properly
			if(not -d $ENV{HOME}) {
				# FIXME!
#				DP_InitI18n();
#				print($i18n->get_advanced("The home directory of the user %(user) doesn't exist at %(path)! Please verify that the environment variable %(VAR) is properly set. Unable to continue\n", { user => [getpwuid($<)]->[0], path => $ENV{HOME}, VAR => 'HOME'}));
#				Gtk2Init();
#				DPError($i18n->get_advanced("The home directory of the user %(user) doesn't exist at %(path)! Please verify that the environment variable %(VAR) is properly set. Unable to continue\n", { user => [getpwuid($<)]->[0], path => $ENV{HOME}, VAR => 'HOME'}));
				die("\n");
			}
			$XDG_CONFIG_HOME = "$ENV{HOME}/.config";
		} else {
			Gtk2Init();
			# FIXME
#			DPError($i18n->get_advanced("The environment variable %(VAR) is not set! Unable to continue\n", { VAR => 'HOME'}));
#			die($i18n->get_advanced("The environment variable %(VAR) is not set! Unable to continue\n", { VAR => 'HOME'}));
			die();
		}
	}
	if ($Maemo)
	{
		return("$XDG_CONFIG_HOME/dayplanner.maemo");
	}
	else
	{
		return("$XDG_CONFIG_HOME/dayplanner");
	}
}

# Purpose: Parse a date string and return various date fields
# Usage: my ($Year, $Month, $Day) = ParseDateString(STRING);
sub ParseDateString {
	my $String = shift;
	# This function is currently stupid, so it doesn't really support more than
	# one format. It is also very strict about that format.
	# This can easily be improved though.
	my $Year = $String;
	my $Month = $String;
	my $Day = $String;
	$Year =~ s/^\d+\.\d+\.(\d\d\d\d)$/$1/;
	$Month =~ s/^\d+\.(\d+)\.\d\d\d\d$/$1/;
	$Day =~ s/^(\d+).*$/$1/;

	# Drop leading zeros from returning
	$Month =~ s/^0//;
	$Day =~ s/^0//;
	return($Year,$Month,$Day);
}

# Purpose: Parse the contents of a text entry field containing various dates
# 		and return an arrayref of dates in the format DD.MM.YYYY
# Usage: my $Ref = ParseEntryField(TEXT ENTRY OBJECT);
sub ParseEntryField {
	my $Field = shift;
	# First get the text
	my $FieldText = $Field->get_text();
	# If it is empty then return an empty array
	if(not $FieldText =~ /\S/) {
		return([]);
	}
	my @ReturnArray;
	# Parse the entry field
	foreach my $Text (split(/[,|\s]+/, $FieldText)) {
		$Text =~ s/\s+//g;
		if($Text =~ /^\d+\.\d+.\d\d\d\d$/) {
			push(@ReturnArray, $Text);
		} else {
			DPIntWarn("Unrecognized date string (should be DD.MM.YYYY): $Text");
		}
	}
	return(\@ReturnArray);
}
# Purpose: Return better errors than IO::Socket::SSL does.
# Usage: my $ERROR = IO_Socket_INET_Errors($@);
#	Errors:
#		OFFLINE = Network is unreachable
#		REFUSED = Connection refused
#		BADHOST = Bad hostname (should often be handled as OFFLINE)
#		TIMEOUT = The connection timed out
#		* = Anything else simply returns $@
sub IO_Socket_INET_Errors {
	my $Error = shift;
	if($Error =~ /Network is unreachable/i) {
		return('OFFLINE');
	} elsif ($Error =~ /Bad hostname/i) {
		return('BADHOST');
	} elsif ($Error =~ /Connection refused/i) {
		return('REFUSED');
	} elsif ($Error =~ /timeout/i) {
		return('TIMEOUT');
	} else {
		DPIntWarn("Unknown IO::Socket::SSL error: $Error");
		return($Error);
	}
}

# Purpose: Report a bug
# Usage: ReportBug();
sub ReportBug
{
	my $BugUrl = 'http://www.day-planner.org/index.php/development/bugs/?b_version='.$Version;
	if ($VersionName eq 'SVN')
	{
		$BugUrl .= '&b_issvn=1';
	}
	else
	{
		$BugUrl .= '&b_issvn=0';
	}
	LaunchWebBrowser($BugUrl);
}

# Purpose: Get OS/distro version information
# Usage: print "OS: ",GetDistVer(),"\n";
sub GetDistVer {
	# Try LSB first
	my %LSB;
	if (-e '/etc/lsb-release')
	{
		LoadConfigFile('/etc/lsb-release',\%LSB);
		if(defined($LSB{DISTRIB_ID}) and $LSB{DISTRIB_ID} =~ /\S/ and defined($LSB{DISTRIB_RELEASE}) and $LSB{DISTRIB_RELEASE} =~ /\S/)
		{
			my $ret = '/etc/lsb-release: '.$LSB{DISTRIB_ID}.' '.$LSB{DISTRIB_RELEASE};
			if(defined($LSB{DISTRIB_CODENAME}))
			{
				$ret .= ' ('.$LSB{DISTRIB_CODENAME}.')';
			}
			return($ret);
		}
	}
	# GNU/Linux and BSD
	foreach(qw/mandriva mandrakelinux mandrake fedora redhat red-hat ubuntu debian gentoo suse distro dist slackware freebsd openbsd netbsd dragonflybsd NULL/)
	{
		if (-e "/etc/$_-release" or -e "/etc/$_-version" or -e "/etc/${_}_version" or $_ eq "NULL") {
			my ($DistVer, $File, $VERSION_FILE);
			if(-e "/etc/$_-release") {
				$File = "$_-release";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/$_-version") {
				$File = "$_-version";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/${_}_version") {
				$File = "${_}_version";
				open($VERSION_FILE, '<', "/etc/${_}_version");
				$DistVer = <$VERSION_FILE>;
			} elsif ($_ eq 'NULL') {
				last unless -e '/etc/version';
				$File = 'version';
				open($VERSION_FILE, '<', '/etc/version');
				$DistVer = <$VERSION_FILE>;
			}
			close($VERSION_FILE);
			chomp($DistVer);
			return("/etc/$File: $DistVer");
		}
	}
	# Didn't find anything yet. Get uname info
	my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
	if ($sysname =~ /darwin/i) {
		my $DarwinName;
		my $DarwinOSVer;
		# Darwin kernel, try to get OS X info.
		if(InPath('sw_vers')) {
			if(eval('use IPC::Open2;1')) {
				if(open2(my $SW_VERS, my $NULL_IN, 'sw_vers')) {
					while(<$SW_VERS>) {
						chomp;
						if (s/^ProductName:\s+//gi) {
							$DarwinName = $_;
						} elsif(s/^ProductVersion:\s+//) {
							$DarwinOSVer = $_;
						}
					}
					close($SW_VERS);
				}
			}
		}
		if(defined($DarwinOSVer) and defined($DarwinName)) {
			return("$DarwinName $DarwinOSVer ($machine)");
		}
	}
	# Detect additional release/version files
	my $RelFile;
	foreach(glob('/etc/*'))
	{
		next if not /(release|version)/i;
		next if m/\/(subversion|lsb-release)$/;
		if ($RelFile)
		{
			$RelFile .= ', '.$_;
		}
		else
		{
			$RelFile = ' ('.$_;
		}
	}
	if ($RelFile)
	{
		$RelFile .= ')';
	}
	else
	{
		$RelFile = '';
	}
	# Some distros set a LSB DISTRIB_ID but no version, try DISTRIB_ID
	# along with the kernel info.
	if ($LSB{DISTRIB_ID})
	{
		return($LSB{DISTRIB_ID}."/Unknown$RelFile ($sysname $release $version $machine)");
	}
	return("Unknown$RelFile ($sysname $release $version $machine)");
}

# Purpose: Launch a web browser with the supplied URL
# Usage: LaunchWebBrowser(URL);
sub LaunchWebBrowser {
	my $URL = shift;
	# Check if URL is a ref. If it is that means we're being used in a gtk2 callback
	# and the first arg is the object we're called from, so shift again to the second
	# arg we recieved which is the real url.
	if(ref($URL)) {
		$URL = shift;
	}
	my $Browser;
	# First check for the BROWSER env var
	if(defined($ENV{BROWSER}) and length($ENV{BROWSER})) {
		# Allow it to be a :-seperated variable - this doesn't slow us down
		# and is future-proof(tm)
		foreach my $Part (split(/:/,$ENV{BROWSER}))
		{
			if(InPath($Part) or -x $Part) {
				$Browser = $Part;
			}
		}
	}
	# Then check for various known file launchers and web browsers
	if(not $Browser) {
		foreach(qw/xdg-open gnome-open exo-open mozffremote mozilla-firefox firefox iceweasel epiphany galeon midori mozilla seamonkey konqueror dillo opera www-browser/) {
			if(InPath($_)) {
				$Browser = $_;
				last;
			}
		}
	}
	# Then launch if found, or output an error if not found
	if($Browser) {
		my $PID = fork();
		if(not $PID) {
			exec($Browser,$URL);
		}
	} else {
		# This should very rarely happen
		DPIntWarn("Failed to detect any browser to launch for the URL $URL");
	}
}

# Purpose: Write the configuration file
# Usage: P_WriteConfig(DIRECTORY, FILENAME,HASH);
sub P_WriteConfig {
	# The parameters
	my $Dir = shift;
	my $File = shift;
	my %UserConfig = @_;
	# Verify the options first
	unless(defined($UserConfig{Events_NotifyPre}) and length($UserConfig{Events_NotifyPre})) {
		$UserConfig{Events_NotifyPre} = '30min';
	}
	unless(defined($UserConfig{Events_DayNotify}) and length($UserConfig{Events_DayNotify})) {
		$UserConfig{Events_DayNotify} = 0;
	}
	if(not defined($UserConfig{DPS_enable}) or not length($UserConfig{DPS_enable})) {
		$UserConfig{DPS_enable} = 0;
	}
	if(not defined($UserConfig{HTTP_Calendars}) or not length($UserConfig{HTTP_Calendars}))
	{
		$UserConfig{HTTP_Calendars} = ' ';
	}
	if(defined($UserConfig{DPS_pass}) and length($UserConfig{DPS_pass})) {
		$UserConfig{DPS_pass} = encode_base64(encode_base64($UserConfig{DPS_pass}));
		chomp($UserConfig{DPS_pass});
	}

	my %Explanations = (
		Events_NotifyPre => "If Day Planner should notify about an event ahead of time.\n#  0 = Don't notify\n# Other valid values: 10min, 20min, 30min, 45min, 1hr, 2hrs, 4hrs, 6hrs",
		Events_DayNotify => "If Day Planner should notify about an event one day before it occurs.\n#  0 - Don't notify one day in advance\n#  1 - Do notify one day in advance",
		HTTP_Calendars => 'The space-seperated list of http calendar subscriptions',
		DPS_host => 'The DPS host to connect to',
		DPS_pass => 'The password',
		DPS_port => 'The port to connect to on the DPS server',
		DPS_user => 'The username',
		DPS_enable => 'If DPS (Day Planner services) is enabled or not (1/0)',
		HEADER => "Day Planner $Version configuration file",
	);
	
	# Write the actual file
	WriteConfigFile("$Dir/$File", \%UserConfig, \%Explanations);

	# Tell the daemon to reload the config file
	# FIXME: Need some generic method to check.
#	if($DaemonInitialized) {
#		Daemon_SendData('RELOAD_CONFIG');
#	}
	# Reset DPS_pass
	if(defined($UserConfig{DPS_pass}) and length($UserConfig{DPS_pass})) {
		$UserConfig{DPS_pass} = decode_base64(decode_base64($UserConfig{DPS_pass}));
	}
	# Enforce perms
	chmod(oct(600),"$Dir/$File");
	return(%UserConfig);
}

# Purpose: Load the configuration file
# Usage: P_LoadConfig(DIR,FILE,HASH);
sub P_LoadConfig {
	# The parameters
	my $Dir = shift;
	my $File = shift;
	my %UserConfig;
	# If it doesn't exist then we just let WriteConfig handle it
	unless (-e "$Dir/$File") {
		WriteConfig($Dir, $File);
		return(1);
	}
	
	my %OptionRegexHash = (
			Events_NotifyPre => '^(\d+(min|hrs?){1}|0){1}$',
			Events_DayNotify => '^\d+$',
			DPS_enable => '^(1|0)$',
			DPS_port => '^\d+$',
			DPS_user => '^.+$',
			DPS_host => '^.+$',
			DPS_pass => '^.+$',
			HTTP_Calendars => '.?',
		);

	LoadConfigFile("$Dir/$File", \%UserConfig, \%OptionRegexHash,1);
	if(defined($UserConfig{DPS_pass}) and length($UserConfig{DPS_pass})) {
		$UserConfig{DPS_pass} = decode_base64(decode_base64($UserConfig{DPS_pass}));
	}
	return(%UserConfig);
}

# Purpose: Create the directory in $SaveToDir if it doesn't exist and display a error if it fails
# Usage: CreateSaveDir();
sub P_CreateSaveDir {
	my $SaveToDir = shift;
	if(not -e $SaveToDir)
	{
		runtime_use('File::Path');
		File::Path::mkpath($SaveToDir) or do {
			# FIXME: I18n
#				DPError($i18n->get_advanced("Unable to create the directory %(directory): %(error)\nManually create this directory before closing this dialog.", { directory => $SaveToDir, error => $!}));
				unless(-d $SaveToDir) {
					die("$SaveToDir does not exist, I was unable to create it and the user didn't create it\n");
				}
		};
		chmod(oct(700),$SaveToDir);
	}
}
1;
