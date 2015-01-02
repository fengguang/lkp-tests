#!/bin/bash

role()
{
	# $host_roles will be determined at job schedule time and
	# set accordingly in each scheduled job
	[[ " $host_roles " =~ " $1 " ]]
}

