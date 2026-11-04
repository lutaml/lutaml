#!/bin/bash

# create arm.htm
# java -Xmx1024m -jar ${SAXON}/saxon.jar -a -o schema.htm schema.xml output_type="HTM" output_rcs="NO"

# java -Xmx1024m -jar  ${SAXON}/saxon.jar -a \
#     -o ${MODULE}/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.htm \
#     ${MODULE}/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.xml \
#     output_type="HTM" output_rcs="NO"

export LOG=sbcl
export line=kinematic_motion_representation_schema

# activity activity_as_realized activity_method activity_method_assignment

export EENG=../eengine-*64${LOG}

export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
# export STEPMOD=/src/boost/stepmod

# export STEPMOD=/src/boost/stepmod
export MODULE=${STEPMOD}/data/modules
export RESOURCE=${STEPMOD}/data/resources
export SAXON=${STEPMOD}/etc/saxon6-5-5

# Create XML ($RESOURCE/$line/$line.xml)
${EENG} --xml -mode resource -stepmod ${STEPMOD}/ -schema ${RESOURCE}/${line}/${line}.exp -stepmod_vcs off \
    -out-dir ${RESOURCE}/${line}/ |& tee ${RESOURCE}/${line}/${line}-xml.sbcl

# Convert to HTM ($RESOURCE/$line/$line.htm)
if [ -a ${RESOURCE}/${line}/${line}.xml ]; then
    java -Xmx1024M -jar ${SAXON}/saxon.jar -a -o ${RESOURCE}/${line}/${line}.htm ${RESOURCE}/${line}/${line}.xml \
        output_type="HTM" output_rcs="NO" |& tee ${RESOURCE}/${line}/${line}-xml.java
fi

# Convert to EXP
if [ -a ${RESOURCE}/${line}/${line}.htm ]; then
    w3m -dump -cols 1000 ${RESOURCE}/${line}/${line}.htm > resource-${line}-res-0.txt
fi
if [ -a resource-${line}-res-0.txt ]; then
    sed '/^Schema: /d' resource-${line}-res-0.txt > resource-${line}-res-1.txt
fi
if [ -a resource-${line}-res-1.txt ]; then
    sed '/^Source : /d' resource-${line}-res-1.txt > resource-${line}-res-xml.exp
fi

# cp ${MODULE}/${line}/mim.exp module-${line}-mim.exp

## Create <module>.xml
# ${EENG} --xml -mode mim_shortform -stepmod ${STEPMOD}/ -schema ${MODULE}/${line}/mim.exp -stepmod_vcs off \
#    -out-dir ${MODULE}/${line}/ |& tee module-${line}-mim-XML.sbcl

## Convert module.xml to module.htm
# if [ -a ${MODULE}/${line}/mim.xml ]; then
#    java -Xmx1024M -jar ${SAXON}/saxon.jar -a -o ${MODULE}/${line}/mim-xml.htm ${MODULE}/${line}/mim.xml \
#        output_type="HTM" output_rcs="NO" |& tee module-${line}-mim-xml.java
#    if [ -a ${MODULE}/${line}/mim-xml.htm ]; then
#        mv ${MODULE}/${line}/mim.xml module-${line}-mim.xml
#    fi
# fi

## convert module.htm ==> module-arm-xml.exp
# if [ -a ${MODULE}/${line}/mim-xml.htm ]; then
#    w3m -dump -cols 1000 ${MODULE}/${line}/mim-xml.htm > /tmp/mim-0.txt
#    sed '/^Schema: /d' /tmp/mim-0.txt > /tmp/mim-1.txt
#    sed '/^Source :$/d' /tmp/mim-1.txt > ${MODULE}/${line}/mim-xml.exp
#    if [ -a ${MODULE}/${line}/mim-xml.exp ]; then
#        rm /tmp/mim-?.txt
#        mv ${MODULE}/${line}/mim-xml.htm module-${line}-mim-xml.htm
#        mv ${MODULE}/${line}/mim-xml.exp module-${line}-mim-xml.exp
#    fi
# fi

## Compare mod-xml.exp with arm.exp
#if [ -a module-${line}-mim-xml.exp ]; then
#    ${EENG} --compare -mode mim_shortform -stepmod ${STEPMOD}/ \
#        -reference_schema module-${line}-mim.exp \
#        -trial_schema module-${line}-mim-xml.exp \
#        -out-dir ./ |& tee module-${line}-mim-compare.${LOG}
# fi
