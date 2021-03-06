#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket::INET;
use IO::Handle;
use Getopt::Long;
use Pod::Usage;
use Net::Ping;

BEGIN {
	use constant {
		OK_NAGIOS    => 0,
		WARN_NAGIOS  => 1,
		ERROR_NAGIOS => 2,
		TRUE         => 42,
		FALSE        => 0
	};
	our $VERSION = 1.02;

	# No Buffering on perl I/O to STDOUT and STDERR:
	IO::Handle::autoflush STDERR 1;
	IO::Handle::autoflush STDOUT 1;
}

sub parseOptions {
	our %Options;

	Getopt::Long::GetOptions(
		'h|zkhost=s' => \$Options{'zkhost'},
		'p|zkport=i' => \$Options{'zkport'},
		'help'       => \$Options{'help'},
		'c|flw=s'    => \$Options{'flw'}
	  )
	  or pod2usage(
		-msg     => "[ERROR][" . localtime() . "] Can't parse options.\n",
		-exitval => ERROR_NAGIOS,
		-verbose => 1
	  );

	if ( defined $Options{'help'} ) {
		pod2usage( -verbose => 2, -exitval => WARN_NAGIOS );
	}

	unless ( defined $Options{'zkhost'}
		&& defined $Options{'zkport'}
		&& defined $Options{'flw'} )
	{
		pod2usage(
			-verbose => 1,
			-msg     => "[ERROR]["
			  . localtime()
			  . "] Missing zkport, zkhost or flw.\n",
			-exitval => ERROR_NAGIOS
		);
	}
	return (TRUE);
}

sub checkPing {
	my $host = shift;
	my $p    = Net::Ping->new();

	unless ( $p->ping($host) ) {
		return (FALSE);
	}

	$p->close();

	return (TRUE);
}

sub checkZooHosts {
	our %Options;
	my $nb = 0;

	if ( $Options{'zkhost'} =~ /,/ ) {
		my @ServerList = split( /,/, $Options{'zkhost'} );
		my @tmp = @ServerList;
		foreach my $host (@ServerList) {
			unless ( checkPing($host) ) {
				print STDERR "[ERROR]["
				  . localtime()
				  . "] $host is unreachable and will not be checked.\n";

			 #Removes servers that do not respond ($nb must stay at this value):
				splice( @tmp, $nb, 1 );
			}
			else {
			  # One element is valid so we push nb to the next value to keep it:
				$nb++;
			}
		}
		if ( scalar(@tmp) ) {
			$Options{'zkhost'}       = \@tmp;
			$Options{'zkmultihosts'} = TRUE;
		}
		else {
			print STDERR "[ERROR]["
			  . localtime()
			  . "] No valid host found in $Options{'zkhost'}.\n";
			exit(ERROR_NAGIOS);
		}
	}
	else {
		unless ( checkPing( $Options{'zkhost'} ) ) {
			print STDERR "[ERROR]["
			  . localtime()
			  . "] $Options{'zkhost'} is unreachable.\n";
			exit(ERROR_NAGIOS);
		}
	}
	return (TRUE);
}

sub sendCommand {
	my $host = shift;
	our %Options;
	my $response;

	# create a connecting socket
	my $socket = new IO::Socket::INET(
		PeerHost => $host,
		PeerPort => $Options{'zkport'},
		Proto    => 'tcp',
	);

	unless ($socket) {
		print STDERR "[ERROR]["
		  . localtime()
		  . "] Can't connect to $host on port $Options{'zkport'}.\n";
		return (FALSE);
	}

	# auto-flush on socket
	IO::Handle::autoflush($socket);

	# data to send to a server
	my $size = $socket->send( $Options{'flw'} );

	unless ( $size && $size > 0 ) {
		print STDERR "[ERROR]["
		  . localtime()
		  . "] Can't send information to $host on port $Options{'zkport'}.\n";
		return (FALSE);
	}

	# notify server that request has been sent
	shutdown( $socket, 1 );

	# receive a response of up to 8096 characters from server
	$socket->recv( $response, 8096 );

	unless ($response) {
		print STDERR "[ERROR]["
		  . localtime()
		  . "] Can't receive information from : $host on port : $Options{'zkport'} for command : $Options{'flw'}.\n";
		return (FALSE);
	}

	$socket->close();

	return ($response);
}

sub parseMonitorAction {
	my $mntr_result = shift;

	foreach ( split( /\n/, $mntr_result ) ) {
		if ( /START/ .. /END/ ) {
			next if /START/ || /END/;
			print;
		}
	}
	return (TRUE);
}

sub parseResult {
	our %Options;
	our %CommandResult;
	my $error_flag;

	foreach my $key ( sort( keys %CommandResult ) ) {
		if ( exists $CommandResult{$key} && defined $CommandResult{$key} ) {
			if ( $Options{flw} =~ "ruok" && $CommandResult{$key} =~ "imok" ) {
				print STDOUT "[INFO]["
				  . localtime()
				  . "] ZkHost $key is anwsering correctly.\n";
			}
			elsif ( $Options{flw} =~ "mntr" ) {
				print STDOUT "[INFO]["
				  . localtime()
				  . "]\n $CommandResult{$key} \n";
				parseMonitorAction( $CommandResult{$key} );
			}
			else {
				$error_flag = TRUE;
				print STDERR "[ERROR]["
				  . localtime()
				  . "] Wrong result for $Options{'flw'} on host $key. Please have a look.\n";
			}
		}
	}
	if ($error_flag) {
		exit(ERROR_NAGIOS);
	}
	return (TRUE);
}

sub processCommandOnZooHosts {
	our %Options;
	our %CommandResult;

	if ( $Options{'zkmultihosts'} ) {
		foreach my $host ( @{ $Options{'zkhost'} } ) {
			unless ( $CommandResult{$host} = sendCommand($host) ) {
				$CommandResult{$host} = ERROR_NAGIOS;
			}
		}
	}
	else {
		unless ( $CommandResult{ $Options{'zkhost'} } =
			sendCommand( $Options{'zkhost'} ) )
		{
			print STDERR "[ERROR]["
			  . localtime()
			  . "] Can't process command $Options{'flw'}.\n";
			exit(ERROR_NAGIOS);
		}
	}
	return (TRUE);
}

sub Main {
	our %Options;
	our %CommandResult;

	parseOptions();

	checkZooHosts();

	processCommandOnZooHosts();

	parseResult();

	exit(OK_NAGIOS);
}

Main();

__END__

=head1 NAME

	ZooMonitor - Monitor ZooKeeper using 4 letter words as described in ZooKeeper documentation

=head1 VERSION

	This documentation refers to ZooMonitor version 1.02.
	
=head1 USAGE

	ZooMonitor --zkhost=zookeeper-naming-uat01 --zkport=10000 --flw=mntr
	
	ZooMonitor --zkhost=zookeeper-naming-uat01,zookeeper-naming-uat02,zookeeper-naming-uat03 --zkport=10000 --flw=mntr
	
=head1 REQUIRED ARGUMENTS

	--zkhost
	
	--zkport
	
	--flw

=head1 OPTIONS

=over 4

=item B<--help>

	Print a brief help message and exit.
	
=item B<--zkport/-p>

	ZooKeeper remote port. Mandatory.

=item B<--zkhost/-h>
	
	ZooKeeper remote host. Mandatory.

=item B<--flw/-c>

	ZooKeeper Commands: The Four Letter Words. Mandatory.

=over	

conf

	Print details about serving configuration.
cons

	List full connection/session details for all clients connected to this server.
	Includes information on numbers of packets received/sent, session id, operation latencies, last operation performed, etc...
crst

	Reset connection/session statistics for all connections.
dump

	Lists the outstanding sessions and ephemeral nodes. This only works on the leader.
envi

	Print details about serving environment
ruok

	Tests if server is running in a non-error state.
	The server will respond with imok if it is running.
	Otherwise it will not respond at all.

	A response of "imok" does not necessarily indicate that the server has joined the quorum, just that the server process is active and bound to the specified client port.
	Use "stat" for details on state wrt quorum and client connection information.
srst

	Reset server statistics.
srvr

	Lists full details for the server.
stat

	Lists brief details for the server and connected clients.
wchs

	Lists brief information on watches for the server.
wchc

	Lists detailed information on watches for the server, by session.
	This outputs a list of sessions(connections) with associated watches (paths).
	Note, depending on the number of watches this operation may be expensive (ie impact server performance), use it carefully.
wchp

	Lists detailed information on watches for the server, by path. This outputs a list of paths (znodes) with associated sessions.
	Note, depending on the number of watches this operation may be expensive (ie impact server performance), use it carefully.
mntr

	Outputs a list of variables that could be used for monitoring the health of the cluster.
	
=back

=back

=head1 DESCRIPTION
	
	This script will monitor ZooKeeper using The Four Letter Words.
	
=head1 EXIT STATUS

	OK_NAGIOS    => 0
	WARN_NAGIOS  => 1
	ERROR_NAGIOS => 2

=cut
