#!/bin/sh

reboot_tbox()
{
	if [ "${os}" = "archlinux" ]; then
		systemctl reboot
	else
		reboot
	fi
}
