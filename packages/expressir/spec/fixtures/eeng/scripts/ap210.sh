#!/bin/bash

#
# Script to run ap210 schemata
#
# Pretty Print AP210 ARM Longform
# Pretty Print AP210 ARM Shortform
# Pretty Print AP210 MIM Longform
# Pretty Print AP210 MIM Shortform

export LOG=sbcl
# export LOG=ccl

export EENG=cl64${LOG}

export STEPMOD=$1
# export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
# export STEPMOD=/src/boost/stepmod

export AP210=${STEPMOD}/data/modules/ap210_electronic_assembly_interconnect_and_packaging_design
# export RESOURCE=${STEPMOD}/data/resources

## Test AP210 arm_lf
${EENG} --pretty -mode arm_longform -schema ${AP210}/arm_lf.exp -out-dir ./ |& tee ap210-arm_lf-pretty.${LOG}
if [ -a arm_lf-pretty.exp ]; then mv arm_lf-pretty.exp ap210-arm_lf-pretty.exp; rm ap210-arm_lf-pretty.${LOG}; fi

## Test AP210 arm
${EENG} --pretty -mode arm_shortform -schema ${AP210}/arm.exp -stepmod ${STEPMOD}/ -out-dir ./ |& tee ap210-arm-pretty.${LOG}
if [ -a arm-pretty.exp ]; then mv arm-pretty.exp ap210-arm-pretty.exp; rm ap210-arm-pretty.${LOG}; fi

## Test AP210 mim_lf
${EENG} --pretty -mode mim_longform -schema ${AP210}/mim_lf.exp -out-dir ./ |& tee ap210-mim_lf-pretty.${LOG}
if [ -a mim_lf-pretty.exp ]; then mv mim_lf-pretty.exp ap210-mim_lf-pretty.exp; rm ap210-mim_lf-pretty.${LOG}; fi

## Test AP210 mim
${EENG} --pretty -mode mim_shortform -schema ${AP210}/mim.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap210-mim-pretty.${LOG}
if [ -a mim-pretty.exp ]; then mv mim-pretty.exp ap210-mim-pretty.exp; rm ap210-mim-pretty.${LOG}; fi
