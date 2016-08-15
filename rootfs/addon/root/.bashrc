#!/bin/bash
# ~/.bashrc

shopt -s cdspell
shopt -s cmdhist
shopt -s histappend
shopt -s histreedit
shopt -s histverify

if test -z "$BASH_COMPLETION" -a -f /etc/bash_completion; then
    . /etc/bash_completion
fi

SHELL_DIR=$HOME/.shell

. $SHELL_DIR/shared_env
. $SHELL_DIR/shared_func
. $SHELL_DIR/shared_alias
. $SHELL_DIR/shared_rc
. $SHELL_DIR/bash_prompt
