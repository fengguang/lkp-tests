#!/bin/sh

. $LKP_SRC/lib/debug.sh
. $LKP_SRC/lib/tests/phoronix-test-suite.sh

## See 'tests/phoronix-test-suite'.

start_time=$(date +%s.%N)
environment_directory="/var/lib/phoronix-test-suite/installed-tests/"

echo "phoronix-test-suite try to connect to the Internet, if use http proxy, please run 'phoronix-test-suite network-setup'"

mkdir -p $environment_directory
phoronix-test-suite user-config-set EnvironmentDirectory=$environment_directory

test_installed=`phoronix-test-suite info $test | grep "Test Installed" | awk '{print $3}'`
[ "$test_installed" = "Yes" ] || {
	echo "Installing $test ..."
	echo "Please make sure phoronix-test-suite can connect to the Internet."
	fixup_install $test
	phoronix-test-suite install-dependencies $test || die "install $test dependencies failed"
	phoronix-test-suite batch-install $test || die "batch-install $test failed"
}

run_test $test
exit_value=$?

end_time=$(date +%s.%N)
elapsed=$(echo $end_time - $start_time | bc)
echo "${test}.seconds: $elapsed"

exit $exit_value
