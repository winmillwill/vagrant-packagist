#!/bin/bash
set -e
# because there's actually no good way to share vagrant config
vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'
vagrant plugin install vagrant-omnibus
