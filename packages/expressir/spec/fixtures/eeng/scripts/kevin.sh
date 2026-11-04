#!/bin/bash

#
# Script to run Qualification
#

# This script produces the following files:
# arm_lf.flat, mim_lf.flat
# ap210_elec*_arm-interfaces.dot, ap210_elec*_mim-interfaces.dot
# arm_lf-pretty.exp, mim_lf-pretty.exp
# EXPRESS_*.txt
# arm_concatenated.exp, mim_concatenated.exp
# mim_lf-smrl-index.xml, mim_concatenated-smrl-index.xml

# for each line of qualify-mod.txt
# ${line}_arm.xml, ${line}_mim.xml

# for each line of qualify-res.txt
# ${line}.xml

# export EENG=cl64sbcl
export EENG=cl64ccl
# export EENG=eengine-5.0.13-sbcl

# export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
export STEPMOD=/src/boost/stepmod
export MODULE=${STEPMOD}/data/modules
export RESOURCE=${STEPMOD}/data/resources

# [0 00:00:01.733] PASS2: While reading the file /src/sfdev/expeng/testcases/smrlv7/data/resources/domain_schema/domain_schema.exp,
#      the error Subtype References don't match:
#   #<P11:ENTITY [   a    ] DOMAIN_SCHEMA.model_property_distribution <<#<P11:ENTITY [   a    ] ANALYSIS_SCHEMA.model_property_distribution {10059B43B3}>>> {10059B58B3}>
#   #<P11:ENTITY [   a    ] ANALYSIS_SCHEMA.model_property_distribution {10059B43B3}> occurred.
# Error: Subtype References don't match: #<P11:ENTITY [   a    ] DOMAIN_SCHEMA.model_property_distribution <<#<P11:ENTITY [   a    ] ANALYSIS_SCHEMA.model_property_distribution {10059B43B3}>>> {10059B58B3}>
#                                        #<P11:ENTITY [   a    ] ANALYSIS_SCHEMA.model_property_distribution {10059B43B3}>


## Test Kevin's issues
${EENG} --xml -mode resource \
   -schema ${RESOURCE}/domain_schema/domain_schema.exp \
   -stepmod ${STEPMOD}/ \
   -out-dir ./ |& tee kevin-domain_schema.log
if [ domain_schema.xml ]; then mv domain_schema.xml kevin-domain_schema.xml; fi
${EENG} --xml -mode resource \
   -schema ${RESOURCE}/mesh_topology_schema/mesh_topology_schema.exp \
   -stepmod ${STEPMOD}/ -out-dir ./ |& tee kevin-mesh_topology_schema.log
if [ mesh_topology_schema.xml ]; then mv mesh_topology_schema.xml kevin-mesh_topology_schema.xml; fi
