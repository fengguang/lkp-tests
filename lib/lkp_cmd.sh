#!/bin/bash

create_lkp_user() {
	grep -q ^lkp: /etc/passwd && return

	echo -n "Do you agree to create lkp users for testing? [N/y]"
	read input
	case $input in
		Y|y)
			useradd -m -s /bin/bash lkp
			if [ $? -eq 0 ]; then
				echo "Create lkp user successfully."
			else
				echo "Create lkp user failed."
				exit 1
			fi
		;;
		*)
			echo "Skip to create user steps."
		;;
	esac
}
