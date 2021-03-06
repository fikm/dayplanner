# DP::GeneralHelpers::IPC
# Copyright (C) Eskild Hustvedt 2007, 2008
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should have received a copy of the GNU General Public License
# along with this program in a file named COPYING.gpl. 
# If not, see <http://www.gnu.org/licenses/>.
package DP::GeneralHelpers::IPC;
use strict;
use warnings;
use IO::Socket::UNIX;
use Glib;
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# -- PUBLIC IPC HANDLER FUNCTIONS --

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_client(path, handler = undef);
sub new_client {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'client';
	$self->{Socket} = IO::Socket::UNIX->new(
		Peer    => $self->{FileName},
		Type	=> SOCK_STREAM,) or do {
			       if(wantarray()) {
			       	       return(FALSE,$@);
			       } else {
				       return(FALSE);
			       } };
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN_EVENT($self->{Socket});})) {
			return(FALSE);
		}
	return($self);
}

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_server(PATH,HANDLER);
# 	PATH is the path to the socket to create
# 	HANDLER is a coderef to the code to handle the socket
sub new_server {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'server';
	$self->{ClientSockets} = [];
	if(not $self->_CheckOrUnlink) {
		return(FALSE);
	}
	$self->{Socket} = IO::Socket::UNIX->new(
					Local	=> $self->{FileName},
					Type	=> SOCK_STREAM,
					Listen	=> TRUE,
			) or do {
			       if(wantarray()) {
			       	       return(FALSE,$@);
			       } else {
				       return(FALSE);
			       } };
	chmod(oct(600), $self->{FileName});
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN(@_);})) {
			$self->destroy();
			return(FALSE);
		}
	return($self);
}

# Purpose: Destory the object
# Usage: obj->destroy
sub destroy {
	my $self = shift;
	if($self->{Type} eq 'server') {
		close($self->{Socket});
		unlink($self->{FileName});
		foreach(@{$self->{ClientSockets}}) {
			if($_) {
				close($_);
			}
		}
	} else {
		close($self->{Socket});
	}
	return(TRUE);
}

# Purpose: Send data to the server
# Usage: obj->client_send(DATA);
sub client_send {
	my $self = shift;

	my $data = shift;
	my $Socket = $self->{Socket};
	print $Socket $data,"\n";
}

# Purpose: Send data to the server and wait for a reply (blocking version of client_send that bypasses handler)
# Usage: ret = obj->client_send_blocking(DATA);
#	TODO: Need to set a very short timeout here
sub client_send_blocking
{
	my $self = shift;
	$self->client_send(@_);

	my $sock = $self->{Socket};
	my $ret = <$sock>;
	chomp($ret);
	return $ret;
}

# -- INTERNAL IPC HANDLER FUNCTIONS --

# Purpose: Handle incoming IO connections
# Usage: $self->_IO_IN();
sub _IO_IN {
	my $self = shift;
	# Accept the client
	my $Client = $self->{Socket}->accept();
	# Install a new Glib::IO watch handler for it
	Glib::IO->add_watch(fileno($Client), 'in', sub { $self->_IO_IN_EVENT($Client);});
	# Push it onto our list of client sockets
	push(@{$self->{ClientSockets}}, $Client);
	# Handled it, so return
	return(TRUE);
}

# Purpose: Handle an open IO connection with events
# Usage: $self->_IO_IN_EVENT();
sub _IO_IN_EVENT {
	my $self = shift;
	my $Client = shift;
	my $Data = <$Client>;
	# If we could read from it, then there's data to be processed!
	if($Data) {
		my $Return = $self->{Handler}->($Data);
		if($Return) {
			print $Client $Return,"\n";
		}
		return(TRUE);
	} else { # If we couldn't then it's dead, so just close it
		close($Client);
		return(FALSE);
	}
}

# TODO: Clean and document
# Purpose: Check for a socket and unlink it, as long as it is safe
# Usage: self->_CheckOrUnlink();
#
# It is considered safe when all of the following is met:
# File exists
# File is a socket
# Socket can not be connected to.
sub _CheckOrUnlink {
	my $self = shift;
	if(-e $self->{FileName}) {
		# Don't try to connect to nor unlink if it isn't a socket
		if(not -S $self->{FileName}) {
			return(FALSE);
		} else {
			# Try to connect to the socket.
			# If we can connect we simply assume that the app in the other end
			# is alive, so we return false.
			my $Client = DP::GeneralHelpers::IPC->new_client($self->{FileName}, sub { return });
			if($Client) {
				$Client->destroy();
				return(FALSE);
			} else {
				unlink($self->{FileName});
				return(TRUE);
			}
		}
	}
	return(TRUE);
}

1;
