# Some misc-functions

setup_proxy()
{
	proxy_file=$LKP_SRC/etc/proxy
	[ -f "$proxy_file" ] && . "$proxy_file"
}
