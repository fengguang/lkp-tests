# Quick installation
```shell
	git clone https://gitee.com/wu_fengguang/lkp-tests.git
	cd lkp-tests
	make install
	source $HOME/.${SHELL##*/}rc
```
all is ok!

# Step-by-Step installation

system wide setup
=================
## debian
```shell
	sudo apt-get install ruby-git ruby-activesupport
```

## openEuler
```shell
	sudo dnf install ruby rubygems
	gem install git activesupport
```

per-user setup
==============
```shell
	git clone https://gitee.com/wu_fengguang/lkp-tests.git
	cd lkp-tests
	echo "export LKP_SRC=$PWD" >> $HOME/.${SHELL##*/}rc
        echo "PATH=\$PATH:$PWD/sbin:$PWD/bin" >> $HOME/.${SHELL##*/}rc

	cat > hosts/$(hostname) <<-EOF
	nr_cpu: $(nproc)
	memory: $(ruby -e 'puts gets.split[1].to_i >> 20' < /proc/meminfo)G
	hdd_partitions:
	ssd_partitions:
	EOF
```
