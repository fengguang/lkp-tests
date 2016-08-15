# ~/.bash_profile: executed by bash(1) for login shells.

# the default umask is set in /etc/login.defs
umask 002

export PATH=/sbin:/usr/sbin:"${PATH}"

# set PATH so it includes user's private bin if it exists
if [ -d ~/bin ] ; then
    export PATH=~/bin:"${PATH}"
fi

# include .bashrc if it exists
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi


