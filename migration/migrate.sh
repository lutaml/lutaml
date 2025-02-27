#!/bin/bash

set -euxo pipefail # Abort on error

# Eg: https://github.com/lutaml
PREFIX=$1

rm -rf lutaml lutaml-express lutaml-uml lutaml-xmi lutaml-sysml merged

git clone $PREFIX/lutaml
git clone $PREFIX/lutaml-express
git clone $PREFIX/lutaml-uml
git clone $PREFIX/lutaml-xmi
git clone $PREFIX/lutaml-sysml

# Create merged versions of some files:
mkdir -p merged
cat */.gitignore | sort | uniq > merged/.gitignore

# For the leaf repos, let's remove the files that will be
# duplicated into new repository, so that we will be able to
# have a clean merge.

for i in lutaml-express lutaml-uml lutaml-xmi lutaml-sysml; do
  pushd $i
    git rm Rakefile Gemfile .gitignore bin/console
    git rm .github/workflows/* spec/spec_helper.rb
    git rm lib/lutaml/layout/graph_viz_engine.rb || :
    git rm *.gemspec
    git mv README.* lib/$(echo $i | tr - /)/

    git commit -m "Merger: Prepare $i for merge"
  popd
done

# Merge all leaf repos to the master repo.

pushd lutaml
  git mv spec/fixtures/ea-xmi-2.4.2{,-generic}.xmi
  sed -i s/ea-xmi-2.4.2/ea-xmi-2.4.2-generic/ spec/lutaml/parser_spec.rb
  git mv spec/fixtures/test{,-generic}.exp
  sed -i s/test.exp/test-generic.exp/ spec/lutaml/express/lutaml_path/document_wrapper_spec.rb spec/lutaml/parser_spec.rb
  git add spec/lutaml/express/lutaml_path/document_wrapper_spec.rb spec/lutaml/parser_spec.rb
  git commit -m "Merger: Prepare lutaml for merge"

  for i in lutaml-express lutaml-uml lutaml-xmi lutaml-sysml; do
    git pull ../$i --no-rebase --allow-unrelated-histories --no-edit
    git commit --amend -m "Merger: Merge $i into lutaml"
  done

  cp ../merged/.gitignore ./.gitignore
  cp ../manually-merged/console ./bin/console
  cp ../manually-merged/lutaml.gemspec ./lutaml.gemspec
  cp ../manually-merged/spec_helper.rb ./spec/spec_helper.rb

  # One gem depends on output being binary, one doesn't. Let's keep it binary.
  sed -i 's/"\\x89PNG"/"\\x89PNG".b/' ./spec/lutaml/layout/graph_viz_engine_spec.rb

  git add .gitignore bin/console lutaml.gemspec spec/spec_helper.rb spec/lutaml/layout/graph_viz_engine_spec.rb
  git commit -m "Merger: Post-merge adjustments for lutaml"
popd

# Rebuild all leaf repos to become stub (empty) gems
for i in lutaml-express lutaml-uml lutaml-xmi lutaml-sysml; do
  pushd $i
    git reset --hard origin/main
    git rm -rf .

    find ../empty-leaf -type f | sed -r 's|.*/empty-leaf/||g' | while read REPLY; do
      mkdir -p $(dirname $REPLY)
      FN=$(echo $REPLY | sed s/gem-name/$i/)
      erb gem_name=$i ../empty-leaf/$REPLY > $FN
    done
    git add .
    git commit -m "Merger: Replace with stub gem"
  popd
done
