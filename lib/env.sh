#!/bin/bash

server_role()
{
	[[ $server_hosts == 'localhost' ]] && return 0
	[[ " $server_hosts " =~ " $HOSTNAME " ]] && return 0
	return 1
}

client_role()
{
	[[ $client_hosts == 'localhost' ]] && return 0
	[[ " $client_hosts " =~ " $HOSTNAME " ]] && return 0
	return 1
}

