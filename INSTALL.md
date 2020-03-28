
# debian packages

```bash
sudo apt-get install ruby-git ruby-activesupport
```

# openEuler packages

```bash
sudo dnf install ruby rubygems
gem install git activesupport
```

# Common setup

```bash
# after running "sudo make install" in README.md
LKP_SRC=$(dirname $(dirname $(realpath /usr/local/bin/lkp)))
cat > $LKP_SRC/lkp-env <<EOF
export LKP_SRC=$LKP_SRC
EOF
echo "source $LKP_SRC/lkp-env" >> $HOME/.${SHELL##*/}rc

cat > $LKP_SRC/hosts/$(hostname) <<EOF
nr_cpu: $(nproc)
memory: $(ruby -e 'puts gets.split[1].to_i >> 20' < /proc/meminfo)G
hdd_partitions:
ssd_partitions:
EOF

```
