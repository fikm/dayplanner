#!/usr/bin/perl
# DP::iCalendar::StructHandler
# $Id$
# An iCalendar structure loader
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itthis. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# This module is capable of loading any file conforming to some simple rules.
# BEGIN: denotes a new tree level
# END:   denotes the end of the current level
# KEY:VALUE sets KEY in the current level to VALUE. You may have multiple KEY:VALUE pairs.
# A line beginning with a space (or any whitespace char) denotes a continuation of the previous KEY:VALUE pair

use strict;
use warnings;
package DP::iCalendar::StructHandler;
use constant { true => 1, false => 0 };

our $VERSION;
$VERSION = 0.1;

# Purpose: Initialize a new object
# Usage: object = DP::iCalendar::StructHandler->new();
sub new
{
	my $class = shift;
	my $this = {};
	bless($this,$class);
	# The data structure will be saved here
	$this->{data} = {};

	# WARNING: NEVER SET THIS TO true UNLESS YOU KNOW FOR CERTAIN YOUR PROGRAM WON'T GENERATE INVALID ARRAYS/HASHES
	$this->{ignoreAssertions} = false;
	$this->{assertNeverFatal} = false;
	return $this;
}

# Purpose: Load a new file
# Usage: $object->loadFile(path_to_file);
sub loadFile
{
	my $this = shift;
	my $file = shift;
	if (not -r $file)
	{
		warn("DP::iCalendar::StructHandler: Cowardly refusing to load nonexistant or nonreadable file: $file\n");
		return false;
	}
	my $sLevel = 0;
	my %Struct;
	my @Nest;
	my $CurrRef = $this->{data};
	my $PrevValue;
	open(my $infile, '<',$file);
	while($_ = <$infile>)
	{
		s/[\r\n]+//;
		# If it's only whitespace, ignore it
		next if not /\S/;
		# First parse the contents, that is X:Y
		my $key = $_;
		$key =~ s/^([^:]+):.*$/$1/;
		my $value = $_;
		$value =~ s/^([^:]+):(.*)$/$2/;
		if ($key =~ /\s/ and not $key =~ /^\s/)
		{
			_parseWarn("key ($key:$value) contains whitespace! This is bad, other parsers might get very confused by that");
		}

		if (s/^\s//)
		{
			# Append to PrevValue
			my $prevLen = scalar(@{$PrevValue});
			$prevLen--;
			$PrevValue->[$prevLen] .= $_;
		}
		elsif ($key eq 'BEGIN')
		{
			# Check that it is a hash
			$this->_assertMustBeRef('HASH',$CurrRef,'CurrRef',true);

			if (not defined $CurrRef->{$value})
			{
				$CurrRef->{$value} = [];
			}
			else
			{
				$this->_assertMustBeRef('ARRAY',$CurrRef->{$value},'CurrRef->{value}',true);
			}
			my $pushNo = push(@{$CurrRef->{$value}}, {});
			$pushNo--;
			$CurrRef = $CurrRef->{$value}[$pushNo];
			push(@Nest,$CurrRef);
		}
		elsif ($key eq 'END')
		{
			pop(@Nest);
			my $nestSize = @Nest;
			$nestSize--;
			$CurrRef = $Nest[$nestSize];
		}
		elsif (defined($key) and defined($value))
		{
			if(not defined($CurrRef->{$key}))
			{
				$CurrRef->{$key} = [];
			}
			push(@{$CurrRef->{$key}},$value);
			$PrevValue = $CurrRef->{$key};
		}
		else
		{
			_parseWarn("Line unparseable: $_");
		}
	}
}

# Purpose: Write the file
# Usage: $object->writeFile(file);
sub writeFile
{
	my $this = shift;
	my $file = shift;
	# Checking SHOULD be done by parent
	open($this->{FH},'>',$file)
		or do {
		warn("DP::iCalendar::StructHandler: FATAL: Failed to open $file in _writeFile: $! - returning false\n");
		return(false);
	};
	$this->_HandleWriteHash($this->{data},undef,0);
}

# Purpose: Get the raw source
# Usage: $string = $object->getRaw();
sub getRaw
{
	my $this = shift;
	$this->{rawOutContents} = '';
	$this->_HandleWriteHash($this->{data},undef,0);
	my $rawOut = $this->{rawOutContents};
	delete($this->{rawOutContents});
	return($rawOut);
}


# Purpose: Handle a new hash in writeFile();
# Usage: $this->_HandleWriteHash(hashref, filehandle);
sub _HandleWriteHash
{
	my $this = shift;
	my $hash = shift;
	my $name = shift;
	my $toplevel = shift;
	my %postponed;
	# Make sure it's a hashref
	$this->_assertMustBeRef('HASH',$hash,'hash in _HandleWriteHash',true);
	# If the array is empty, ignore it
	if ($name)
	{
		$this->_write('BEGIN',$name);
	}
	foreach my $name(sort keys(%{$hash}))
	{
		if (defined($toplevel))
		{
			if ($toplevel > 0 && $toplevel < 3)
			{
				# Examine structure and postpone some.
				# 
				# What this does is as follows:
				# Purpose: Ensure that the information in the first few BEGIN: blocks
				# 	that are NOT BEGIN: sections themselves are written out before the BEGIN
				# 	blocks.
				# Method: Keep a $toplevel variable for the first three instances of the _HandleWriteXXXX functions.
				# 	This variable is incremented each run. When the variable is larger than zero and less than three
				# 	_HandleWriteHash checks if the value to be written now is a BEGIN block, if it is, it postpones it and
				# 	writes that last.
				# How it Checks: If the first value of the current hashrefs array is a hash, that means it's a BEGIN block.
				$this->_assertMustBeRef('ARRAY',$hash->{$name},'hash->{$name} in _HandleWriteHash (toplevel processing)',true);
				if (ref($hash->{$name}->[0]) eq 'HASH')
				{
					$toplevel++;
					$postponed{$name} = $hash->{$name};
					next;
				}
			}
			elsif($toplevel > 2)
			{
				$toplevel = undef;
			}
		}
		$this->_HandleWriteArray($hash->{$name},$name,$toplevel);
	}
	if (defined($toplevel) && keys(%postponed))
	{
		$this->_HandleWriteHash(\%postponed,undef,$toplevel);
	}
	if ($name)
	{
		$this->_write('END',$name);
	}
}

# Purpose: Write out a line of data
# Usage: $this->_write(key,value);
sub _write
{
	my $this = shift;
	my $key = shift;
	my $value = shift;
	if (not defined($value) or not length($value))
	{
		return;
	}
	my $line = $key.':'.$value."\r\n";
	my $maxlen = 80;
	if(length($line) > $maxlen)
	{
		$line = '';
		my $currLine = $key.':';
		foreach my $lpart (split(/ /,$value))
		{
			if (length($currLine) > $maxlen or (length($currLine)+length($lpart)) > $maxlen)
			{
				$line .= $currLine."\r\n";
				$currLine = '  '.$lpart;
			}
			else
			{
				$currLine .= ' '.$lpart;
			}
		}
		$line .= $currLine."\r\n";
	}
	$this->_realWrite($line);
}

# Purpose: Actually write out a line of data, or append to internal variable
# Usage: this->_realWrite(LINE);
sub _realWrite
{
	my $this = shift;
	my $line = shift;
	if ($this->{FH})
	{
		print {$this->{FH}} $line;
	}
	else
	{
		$this->{rawOutContents} .= $line;
	}
}

# Purpose: Handle a new array in writeFile();
# Usage: $this->_HandleWriteArray(arrayref, filehandle);
sub _HandleWriteArray
{
	my $this = shift;
	my $array = shift;
	my $name = shift;
	my $toplevel = shift;
	if (defined($toplevel))
	{
		$toplevel++;
		if ($toplevel > 2)
		{
			$toplevel = undef;
		}
	}
	# Make sure it's an arrayref 
	$this->_assertMustBeRef('ARRAY',$array,'array in _HandleWriteHash',true);
	foreach my $value(@{$array})
	{
		if(ref($value) eq 'HASH')
		{
			$this->_HandleWriteHash($value,$name,$toplevel);
		}
		else
		{
			$this->_write($name,$value);
		}
	}
}

# Purpose: Output a parser warning
# Usage: _parseWarn(message);
sub _parseWarn
{
	warn($_[0]);
}

# Purpose: Assert if a variable is what we want it to be and display useful errors if it isn't
# Usage: $this->_assertMustBeRef(refName,ref,varname,fatal);
# 	refName = the reference type expected, ie. HASH or ARRAY
# 	ref		= the variable that should be holding the reference
# 	varname = the name of the variable that is passed as ref, this is used for printing useful messages
# 	fatal	= true if we should die(), false if not
# Returns true if it suceeds, false if not (and fatal=false)
# NOTE that it can be turned completely off with $this->{ignoreAssertions} = true; - so do not
# DEPEND upon its return value.
sub _assertMustBeRef
{
	my $this = shift;
	# Allow this to be disabled
	if ($this->{ignoreAssertions})
	{
		return true;
	}

	my $refName = shift;
	my $ref = shift;
	if(not ref($ref) eq $refName)
	{
		my $varname = shift;
		my $fatal = shift;

		my $errMsg;
		# It wasn't, work hard to get a useful error message
		if(not ref($ref))
		{
			if(defined($ref))
			{
				$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was an unknown var: $ref";
			}
			else
			{
				$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was UNDEF!";
			}
		}
		else
		{
			$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was a: ".ref($ref);
		}
		my ($caller_package, $caller_filename, $caller_line) = caller;
		$errMsg .= " on line $caller_line in $caller_filename";
		if($fatal && $this->{assertNeverFatal})
		{
			$errMsg .= " - SHOULD HAVE BEEN FATAL";
			$fatal = false;
		}
		if ($fatal)
		{
			$errMsg = "FATAL: ".$errMsg;
			die($errMsg."\n");
		}
		else
		{
			warn("WARNING: ".$errMsg." - expect trouble\n");
			return false;
		}
	}
}
#my $foo = DP::iCalendar::StructHandler->new();
#$foo->loadFile('/home/zerodogg/.config/dayplanner/debug/calendar.ics');
#use Data::Dumper;
#print Dumper($foo);
#exit(0);
#$foo->writeFile('./testfile');
