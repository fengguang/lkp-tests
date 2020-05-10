#!/bin/sh

sed -i -e '1s/ruby/crystal/' -e 's/exist?/exists?/' -e 's/$PROGRAM_NAME/PROGRAM_NAME/'  "$@"
