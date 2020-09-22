ifeq ($(TARGET_DIR_BIN), )
    TARGET_DIR_BIN := /usr/local/bin
endif

ifneq ($(shell whoami), "root")
    TARGET_DIR_BIN := /home/$(shell whoami)/bin
endif

all: subsystem install

subsystem:
	$(MAKE) -C bin/event wakeup

install:
	mkdir -p $(TARGET_DIR_BIN)
	ln -sf $(shell pwd)/bin/lkp $(TARGET_DIR_BIN)/lkp
	bash sbin/install-dependencies.sh
	bash sbin/set-env.sh

.PHONY: doc
doc:
	lkp gen-doc > ./doc/tests.md

tests/%.md: tests/%.yaml
	lkp gen-doc $<
