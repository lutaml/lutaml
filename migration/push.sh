#!/bin/bash

set -euxo pipefail # Abort on error

ORIGIN=$1

for i in lutaml lutaml-express lutaml-sysml lutaml-uml lutaml-xmi; do
  pushd $i
    git remote add upstream $ORIGIN/$i
    git branch merger
    git checkout merger
    git push -u upstream --force
  popd
done
