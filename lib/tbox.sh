#!/bin/sh

tbox_cant_kexec()
{
	is_virt && return 0

	has_cmd kexec || return 0
	has_cmd cpio || return 0

	return 1
}
