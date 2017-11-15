#!/bin/bash

. $LKP_SRC/lib/debug.sh

# ffmpeg only support max 64 threads
fixup_ffmpeg()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/ffmpeg-2.5.0/ffmpeg
	if [[ -z $(grep -w 'NUM_CPU_CORES=64' $target) ]]; then
		sed "2a[ \$NUM_CPU_CORES -gt 64 ] && export NUM_CPU_CORES=64" -i "$target"
	fi
}

# add --allow-run-as-root to open-porous-media-1.3.1
fixup_open_porous_media()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/open-porous-media-1.3.1/open-porous-media
	sed -i 's/nice mpirun -np/nice mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to lammps
fixup_lammps()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/lammps-1.0.1/lammps
	sed -i 's/mpirun -np/mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to npb
fixup_npb()
{
	[[ -n "$environment_directory" ]] || return
	local target=${environment_directory}/pts/npb-1.2.4/npb
	sed -i 's/mpiexec -np/mpiexec --allow-run-as-root -np/' "$target"
}

# start nginx and disable ipv6
fixup_nginx()
{
	[[ -n "$environment_directory" ]] || return
	sed -i 's/^::1/#::1/' /etc/hosts
	${environment_directory}/pts/nginx-1.1.0/nginx_/sbin/nginx
	sleep 5
}

# change to use dash to bullet
fixup_bullet()
{
	[[ -n "$environment_directory" ]] || return
	phoronix-test-suite force-install pts/bullet-1.2.2
	local target=${environment_directory}/pts/bullet-1.2.2/bullet
	sed -i 's,#!/bin/sh,#!/bin/dash,' "$target"
}

run_test()
{
	local test=$1
	case $test in
		systester-[0-9]*)
			# Choose
			# 1: Gauss-Legendre algorithm [Recommended.]
			# 2: 16 Million Digits [This Test could take a while to finish.]
			# 3: 4 threads [2+ Cores Recommended]
			# todo: select different test according to testbox's hardware
			test_opt="\n1\n2\n3\nn"
			;;
		nginx-1.1.0)
			fixup_nginx
                        ;;
		ffmpeg-2.5.0)
			fixup_ffmpeg
			;;
		lammps-1.0.1)
			fixup_lammps
			;;
		npb-1.2.4)
			fixup_npb
			;;
		bullet-1.2.2)
			fixup_bullet
			;;
		open-porous-media-1.3.1)
			fixup_open_porous_media
			;;
	esac

	export PTS_SILENT_MODE=1
	echo PTS_SILENT_MODE=$PTS_SILENT_MODE

	## this is to avoid to write the tmp "test-results" to disk
	mount -t tmpfs tmpfs /var/lib/phoronix-test-suite/test-results || die "failed to mount tmpfs"

	if [ "$test_opt" ]; then
		echo -e "$test_opt" | log_cmd phoronix-test-suite run $test
	else
		echo n | log_cmd phoronix-test-suite default-run $test
	fi
}
