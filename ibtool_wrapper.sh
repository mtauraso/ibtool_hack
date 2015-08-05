#!/bin/bash

# Switch back to system ruby if we're on something else.
if [ `type rvm 2>&1 > /dev/null` ]; then
  rvm use system
fi


# Remove any env set up by bundler. This avoids gem loading problems
# during ruby interpreter startup
export BUNDLE_BIN_PATH=
export BUNDLE_GEMFILE=
export RUBYOPT=

# Execute the actual wrapper with the rest of the environment passed-through.
# Replace the bash process with ruby.
WRAPPER_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
exec $WRAPPER_DIR/ibtool_wrapper.rb "$@"

