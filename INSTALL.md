
# debian packages

```bash
sudo apt-get install ruby-git ruby-activesupport
```

# openEuler packages

```bash
sudo dnf install ruby rubygems
gem install git activesupport
```

# Common setup (per-user)

```bash
git clone https://gitee.com/wu_fengguang/lkp-tests.git
cd lkp-tests
echo "export LKP_SRC=$PWD" >> $HOME/.${SHELL##*/}rc

cat > hosts/$(hostname) <<EOF
nr_cpu: $(nproc)
memory: $(ruby -e 'puts gets.split[1].to_i >> 20' < /proc/meminfo)G
hdd_partitions:
ssd_partitions:
EOF

```
