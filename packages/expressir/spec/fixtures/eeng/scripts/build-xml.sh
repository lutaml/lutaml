#!/bin/bash

# This is expected to be run within the "qualify/" directory.
# It will use the eengine instance in the directory above.

# It goes through each Resource and Module in the specified STEPmod
# Instance creating an XML file for the appropriate Shortform schemata.

export EENG=../eengine-*64sbcl
export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
export RESOURCES=${STEPMOD}/data/resources
export MODULES=${STEPMOD}/data/modules

mods=../modules.lst
ress=../resources.lst

## Process Resources in ${STEPMOD}/data/resources/
while IFS= read -r line; do

    ${EENG} --xml -mode resource -stepmod ${STEPMOD}/ -schema ${RESOURCES}/${line}/${line}.exp \
        -out-dir ${RESOURCES}/${line}/ |& tee ${RESOURCES}/${line}/${line}-xml.eeng

done < ${ress}


## Process Modules in ${STEPMOD}/data/modules/
while IFS= read -r line; do

    # generate XML for ARM
    ${EENG} --xml -mode arm_shortform -stepmod ${STEPMOD}/ -schema ${MODULES}/${line}/arm.exp \
        -out-dir ${MODULES}/${line}/ |& tee ${MODULES}/${line}/arm-${line}-xml.eeng

    # Generate XML for MIM
    ${EENG} --xml -mode mim_shortform -stepmod ${STEPMOD}/ -schema ${MODULES}/${line}/mim.exp \
        -out-dir ${MODULES}/${line}/ |& tee ${MODULES}/${line}/mim-${line}-xml.eeng

done < ${mods}
