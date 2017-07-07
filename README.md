# ZooMonitor
ZooMonitor - Monitor ZooKeeper using 4 letter words as described in ZooKeeper documentation.

ZooMonitor will exit with according Nagios Status if any issue is encountered.

NAME

	ZooMonitor - Monitor ZooKeeper using 4 letter words as described in ZooKeeper documentation

VERSION

	This documentation refers to ZooMonitor version 1.02.
	
USAGE

	ZooMonitor --zkhost=zookeeper-naming-uat01 --zkport=10000 --flw=mntr
	
REQUIRED ARGUMENTS

	--zkhost
	
	--zkport
	
	--flw

OPTIONS

<--help>

	Print a brief help message and exit.
	
<--zkport/-p>

	ZooKeeper remote port. Mandatory.

<--zkhost/-h>
	
	ZooKeeper remote host. Mandatory.

<--flw/-c>

	ZooKeeper Commands: The Four Letter Words. Mandatory.	

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
    A response of "imok" does not necessarily indicate that the server has joined the quorum, just that the server process is   active and bound to the specified client port.
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


DESCRIPTION
	
	This script will monitor ZooKeeper using The Four Letter Words.
	
EXIT STATUS

	OK_NAGIOS    => 0
	WARN_NAGIOS  => 1
	ERROR_NAGIOS => 2
