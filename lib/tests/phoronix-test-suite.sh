#!/bin/bash

. $LKP_SRC/lib/debug.sh

# ffmpeg only support max 64 threads
fixup_ffmpeg()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/ffmpeg
	if [[ -z $(grep -w 'NUM_CPU_CORES=64' $target) ]]; then
		sed "2a[ \$NUM_CPU_CORES -gt 64 ] && export NUM_CPU_CORES=64" -i "$target"
	fi
}

# add --allow-run-as-root to open-porous-media-1.3.1
fixup_open_porous_media()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/open-porous-media
	sed -i 's/nice mpirun -np/nice mpirun --allow-run-as-root -np/' "$target"
}

# rebuild hpcc and add --allow-run-as-root to hpcc
# the test needs more than 2 hours
fixup_hpcc()
{
	[[ -n "$environment_directory" ]] || return

	local test=$1
	local mpdir="/usr/lib/x86_64-linux-gnu/openmpi"
	# check mpdir in Make file to make sure the test binary is built with right library
	[ -d "$mpdir" ] && [ "$(grep MPdir ${environment_directory}/pts/${test}/hpcc-*/hpl/Make.pts | awk '{print $NF}')" != "$mpdir" ] && {
		export MPI_PATH=$mpdir
		export MPI_INCLUDE=$mpdir/include
		export MPI_LIBS=$mpdir/lib/libmpi.so
		export MPI_CC=/usr/bin/mpicc.openmpi
		export MPI_VERSION=`$MPI_CC -showme:version 2>&1 | grep MPI | cut -d "(" -f1  | cut -d ":" -f2`
		phoronix-test-suite force-install pts/$test
	}

	local target=${environment_directory}/pts/${test}/hpcc
	sed -i 's/mpirun -np/mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to lammps
fixup_lammps()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/lammps
	sed -i 's/mpirun -np/mpirun --allow-run-as-root -np/' "$target"
}

# add --allow-run-as-root to npb
fixup_npb()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/npb
	sed -i 's/mpiexec -np/mpiexec --allow-run-as-root -np/' "$target"
}

# start nginx and disable ipv6
fixup_nginx()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	sed -i 's/^::1/#::1/' /etc/hosts
	${environment_directory}/pts/${test}/nginx_/sbin/nginx
	sleep 5
}

# default to test 1m
fixup_fio()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/fio-run

	# create virtual disk
	local test_disk="/tmp/test_fio.img"
	local test_dir="/media/test_fio"
	fallocate -l 100M $test_disk || return
	mkfs -t ext4 $test_disk || return
	mkdir $test_dir || return
	mount -t auto -o loop $test_disk $test_dir ||return

	sed -i 's,#!/bin/sh,#!/bin/dash,' "$target"
	sed -i "s#\$DIRECTORY_TO_TEST#directory=${test_dir}#" "$target"

	# Choose
	# 1: Sequential Write
	# 2: Libaio
	# 3: Test All Options
	# 4: Test All Options
	# 5: 1MB
	# 6: Default Test Directory
	# 7: Test All Options
	test_opt="\n4\n3\n3\n3\n9\n1\n3\nn"
}

# change to use dash to bullet
fixup_bullet()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/bullet
	sed -i 's,#!/bin/sh,#!/bin/dash,' "$target"
}

# add bookpath option
fixup_crafty()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/crafty
	sed -i 's,crafty $@,crafty bookpath=/usr/share/crafty/ $@,' "$target"
}

fixup_unvanquished()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/${test}/unvanquished-game
	[ -f $target/lib64/librt.so.1 ] && rm $target/lib64/librt.so.1
	[ -f $target/lib64/libdrm.so.2 ] && rm $target/lib64/libdrm.so.2
	[ -f $target/lib64/libstdc++.so.6 ] && rm $target/lib64/libstdc++.so.6
	export DISPLAY=:0
	export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libasound.so.2
}

fixup_gluxmark()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/$test
	export LD_LIBRARY_PATH=${target}/gluxMark2.2_src/libs
	export MESA_GL_VERSION_OVERRIDE=3.0
	export DISPLAY=:0
	# Choose
	# 1: Windowed
	# 2: 800 x 600
	# 3: Fill-Rate
	test_opt="\n2\n1\n1\nn"
}

fixup_jgfxbat()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/pts/$test

	# fix the result format
	sed -i s/PASS/" Result: 1"/ $target/jgfxbat
	sed -i s/FAIL/" Result: 0"/ $target/jgfxbat
	local results_definition=${environment_directory}/../test-profiles/pts/${test}/results-definition.xml
	[[ -f "$results_definition" ]] || return
	sed -i s/"#_RESULT_#"/"Result: #_RESULT_#"/ $results_definition

	# disable the Jaca2Demo test due to unstable
	sed -i 's/^run_Java2Demo$/#run_Java2Demo/' $target/runbat.sh

	# select the java version
	# drop debug message to avoid unexpected stderr
	update-java-alternatives -s java-1.6.0-openjdk-amd64 &>/dev/null || {
		echo "failed to update-java-alternatives -s java-1.6.0-openjdk-amd64"
		return 1
	}

	export DISPLAY=:0
}

fixup_systester()
{
	[[ -n "$environment_directory" ]] || return
	local test=$1
	local target=${environment_directory}/../test-profiles/pts/${test}/results-definition.xml
	[ -f $target.bak ] || cp $target $target.bak
	sed -i '/LineBeforeHint/d' $target
	export TOTAL_LOOP_TIME=1
	export TOTAL_LOOP_COUNT=1
}

run_test()
{
	local test=$1
	case $test in
		systester-[0-9]*)
			# Choose
			# 1: Gauss-Legendre algorithm [Recommended.]
			# 1: 4 Million Digits [This Test could take a while to finish.]
			# 3: 4 threads [2+ Cores Recommended]
			# todo: select different test according to testbox's hardware
			fixup_systester $test || die "failed to fixup test systester"
			test_opt="\n1\n1\n3\nn"
			;;
		iozone-*)
			# Choose
			# 1: 1MB
			# 2: 2GB
			# 3: Test All Options
			test_opt="\n3\n2\n3\nn"
			;;
		ut2004-demo-*)
			# Choose
			# 1: ONS-Torlan Botmatch
			# 2: 800 x 600
			test_opt="\n6\n1\nn"
			export DISPLAY=:0
			;;
		urbanterror-*)
			# Choose
			# 1: 800 x 600
			test_opt="\n1\nn"
			export DISPLAY=:0
			;;
		nexuiz-*)
			# Choose
			# 1: 800 x 600
			# 2: Test All Options
			# 3: Test All Options
			test_opt="\n1\n3\n3\nn"
			export DISPLAY=:0
			;;
		video-cpu-usage-*)
			# Choose
			# 1: OS X CoreVideo
			test_opt="\n5\na\nb\nc\nn"
			export DISPLAY=:0
			;;
		nginx-*)
			fixup_nginx $test || die "failed to fixup test nginx"
                        ;;
		ffmpeg-*)
			fixup_ffmpeg $test || die "failed to fixup test ffmpeg"
			;;
		lammps-*)
			fixup_lammps $test || die "failed to fixup test lammps"
			;;
		npb-*)
			fixup_npb $test || die "failed to fixup test npb"
			;;
		bullet-*)
			fixup_bullet $test || die "failed to fixup test bullet"
			;;
		fio-*)
			fixup_fio $test || die "failed to fixup test fio"
			;;
		hpcc-*)
			fixup_hpcc $test || die "failed to fixup test hpcc"
			;;
		open-porous-media-*)
			fixup_open_porous_media $test || die "failed to fixup test open-porous-media"
			;;
		crafty-*)
			fixup_crafty $test || die "failed to fixup crafty"
			;;
		unvanquished-*)
			fixup_unvanquished $test || die "failed to fixup unvanquished"
			;;
		gluxmark-*)
			fixup_gluxmark $test || die "failed to fixup gluxmark"
			;;
		jgfxbat-*)
			fixup_jgfxbat $test || die "failed to fixup jgfxbat"
			;;
		unigine-heaven-*|unigine-valley-*)
			export DISPLAY=:0
			# resolutino: 800X600
			# full screen
			test_opt="\n1\n1\nn"
			;;
		glmark2-*|openarena-*|gputest-*|supertuxkart-*|tesseract-*)
			export DISPLAY=:0
			;;
	esac

	export PTS_SILENT_MODE=1
	echo PTS_SILENT_MODE=$PTS_SILENT_MODE

	root_access="/usr/share/phoronix-test-suite/pts-core/static/root-access.sh"
	[ -f "$root_access" ] || die "$root_access not exist"
	sed -i 's,#!/bin/sh,#!/bin/dash,' $root_access

	## this is to avoid to write the tmp "test-results" to disk
	mount -t tmpfs tmpfs /var/lib/phoronix-test-suite/test-results || die "failed to mount tmpfs"

	if [ "$test_opt" ]; then
		echo -e "$test_opt" | log_cmd phoronix-test-suite run $test
	else
		/usr/bin/expect <<-EOF
			spawn phoronix-test-suite default-run $test
			expect {
				"Would you like to save these test results" { send "n\r"; exp_continue }
				eof { }
				default { exp_continue }
			}
	EOF
	fi
}
