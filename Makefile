ifeq ($(TARGET_DIR_BIN), )
    TARGET_DIR_BIN := /usr/local/bin
endif

all: subsystem install

subsystem:
	$(MAKE) -C bin/event wakeup

install:
	mkdir -p $(TARGET_DIR_BIN)
	ln -sf $(shell pwd)/bin/lkp $(TARGET_DIR_BIN)/lkp

.PHONY: doc
doc:
	lkp gen-doc > ./doc/tests.md

tests/%.md: tests/%.yaml
	lkp gen-doc $<
