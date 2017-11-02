install:
	ln -sf $(shell pwd)/bin/lkp /usr/local/bin/lkp

.PHONY: doc
doc:
	lkp gen-doc > ./doc/tests.md

tests/%.md: tests/%.yaml
	lkp gen-doc $<
