#!/bin/sh

apache_debian_style()
{
 	[ "${APACHE_DEBIAN_STYLE:-0}" -eq 1 ] && return 0
	[ "${APACHE_DEBIAN_STYLE:-1}" -eq 0 ] && return 1

	if which a2enmod > /dev/null 2>&1; then
		APACHE_DEBIAN_STYLE=1
		return 0
	else
		APACHE_DEBIAN_STYLE=0
		return 1
	fi
}

set_apache_name()
{
	if [ -z "$APACHE_NAME" ]; then
		if apache_debian_style; then
			APACHE_NAME=apache2
		else
			APACHE_NAME=httpd
		fi
	fi
}

set_apache_path()
{
	if [ -z "$APACHE_MODDIR" ]; then
		if apache_debian_style; then
			APACHE_MODDIR='/etc/apache2/mods-enabled'
		else
			APACHE_MODDIR='/etc/httpd/conf.modules.d'
		fi
	fi

	if [ -z "$APACHE_CONF" ]; then
		if apache_debian_style; then
			APACHE_CONF='/etc/apache2/apache2.conf'
		else
			APACHE_CONF='/etc/httpd/conf/httpd.conf'
		fi
	fi
}

enable_httpd_mod()
{
	set_apache_path

	for mod in "$@"
	do
		sed -i -r "s/#LoadModule\s+${mod}_module/LoadModule ${mod}_module/" "$APACHE_MODDIR"/*conf
	done
}

disable_httpd_mod()
{
	set_apache_path

	for mod in "$@"
	do
		sed -i -r "s/LoadModule\s+${mod}_module/#LoadModule ${mod}_module/" "$APACHE_MODDIR"/*conf
	done
}

restore_apache_mod()
{
	set_apache_path

	if [ -d "$APACHE_MODDIR"/backup ]; then
		rm -f "$APACHE_MODDIR"/*conf "$APACHE_MODDIR"/*load
		cp -d "$APACHE_MODDIR"/backup/* "$APACHE_MODDIR"
		rm -rf "$APACHE_MODDIR"/backup
	fi
}

backup_apache_mod()
{
	set_apache_path

	if apache_debian_style; then
		MODFILE="$APACHE_MODDIR/*conf $APACHE_MODDIR/*load"
	else
		MODFILE="$APACHE_MODDIR/*conf"
	fi

	mkdir -p "$APACHE_MODDIR"/backup
	rm -rf "$APACHE_MODDIR"/backup/*
	cp -d $MODFILE "$APACHE_MODDIR"/backup/
}

enable_apache_mod()
{
	if apache_debian_style; then
		a2enmod "$@"
	else
		enable_httpd_mod "$@"
	fi
}

disable_apache_mod()
{
	if apache_debian_style; then
		a2dismod "$@"
	else
		disable_httpd_mod "$@"
	fi
}

systemctl_apache()
{
	if apache_debian_style; then
		systemctl "$@" apache2
	else
		systemctl "$@" httpd
	fi
}

