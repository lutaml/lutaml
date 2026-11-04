#!/bin/bash

export HEAD_STEPMOD=/src/boost/stepmod
export TEST_STEPMOD=/src/sfdev/expeng/testcases/smrlv7

export HEAD_MODULES=${HEAD_STEPMOD}/data/modules
export TEST_MODULES=${TEST_STEPMOD}/data/modules

mods=./qualify-mod.txt

while IFS= read -r line; do

if [ -a ${HEAD_MODULES}/${line}/module.xml ]; then
    echo Copying ${HEAD_MODULES}/${line}/module.xml to ${TEST_MODULES}/${line}/
    cp ${HEAD_MODULES}/${line}/module.xml ${TEST_MODULES}/${line}/
fi

done < ${mods}
