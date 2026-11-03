#!/bin/bash

export LOG=sbcl
# export LOG=ccl

export EENG=../eengine-*64${LOG}

export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
# export STEPMOD=/src/boost/stepmod
export MODULE=${STEPMOD}/data/modules
export RESOURCE=${STEPMOD}/data/resources
export SAXON=${STEPMOD}/etc/saxon6-5-5

# ress=../qualify-res.txt

## process a set of Resources
## For each Resource
##   --xml

## To be done:
##   --pretty
##   --dot -graph interface
##   --list
##   --list --xml-output

export schemata='specification_control'

### while IFS= read -r line; do
for line in ${schemata}; do
    printf ';; #### [%s]\n' "$line"

cp ${MODULE}/${line}/arm.exp module-${line}-arm.exp

## XML File
${EENG} --xml -mode arm_shortform -stepmod ${STEPMOD}/ \
    -schema ${MODULE}/${line}/arm.exp \
    -out-dir ${MODULE}/${line}/ |& tee module-${line}-arm-XML.${LOG}
if [ -a ${MODULE}/${line}/arm.xml ]; then rm module-${line}-arm-XML.${LOG}; fi

## XML ==> HTM
java -Xmx1024M -jar ${SAXON}/saxon.jar -a -o ${MODULE}/${line}/arm.htm ${MODULE}/${line}/arm.xml \
    output_type="HTM" output_rcs="NO" |& tee module-${line}-arm-HTM.java
if [ -a ${MODULE}/${line}/arm.htm ]; then
    cp ${MODULE}/${line}/arm.xml module-${line}-arm.xml
#    rm module-${line}-arm-HTM.java
fi

w3m -dump -cols 1000 ${MODULE}/${line}/arm.htm > module-${line}-arm-0.txt |& tee module-${line}-arm-htm.w3m
sed '/^Schema: /d' module-${line}-arm-0.txt > module-${line}-arm-1.txt
sed '/^Source :/d' module-${line}-arm-1.txt > module-${line}-arm-xml.exp
if [ -a module-${line}-arm-xml.exp ]; then
    mv ${MODULE}/${line}/arm.htm module-${line}-arm-xml.htm
fi

## compare with original EXPRESS file
${EENG} --compare -mode arm_shortform -stepmod ${STEPMOD}/ -stepmod_vcs off \
    -reference_schema module-${line}-arm.exp -trial_schema module-${line}-arm-xml.exp \
    -out-dir ./ |& tee module-${line}-arm-xml-compare.${LOG}
if [ -a EXPRESS_arm_shortform_comparison_results.txt ]; then
    mv EXPRESS_arm_shortform_comparison_results.txt module-${line}-arm-xml-comparison.txt
fi
# if [ -a resource-${line}-res-xml-comparison.txt ]; then rm resource-${line}-res-xml-compare.${LOG}; fi

## Pretty Print
# ${EENG} --pretty -mode resource -stepmod ${STEPMOD}/ \
#    -schema ${RESOURCE}/${line}/${line}.exp \
#    -out-dir ./ |& tee resource-${line}-pretty.${LOG}
# if [ -a ${line}-pretty.exp ]; then
#    mv ${line}-pretty.exp resource-${line}-pretty.exp
#    rm -f resource-${line}-pretty.${LOG}
# fi

# ${EENG} --compare -mode resource \
#   -stepmod ${STEPMOD}/ \
#   -reference_schema ${RESOURCE}/${line}/${line}.exp \
#   -trial_schema resource-${line}-pretty.exp \
#   -out-dir ./ |& tee resource-${line}-pretty-compare.${LOG}
# if [ -a EXPRESS_resource_shortform_comparison_results.txt ]; then
#    mv EXPRESS_resource_shortform_comparison_results.txt resource-${line}-compare.txt
# fi
# if [ -a resource-${line}-compare.txt ]; then rm resource-${line}-pretty-compare.${LOG}; fi

## Dot Graph Interface
# ${EENG} --dot -graph interface -stepmod ${STEPMOD}/ -schema ${RESOURCE}/${line}/${line}.exp \
#    -out-dir ./ |& tee resource-${line}-dot_interface.${LOG}
# if [ -a ${line}-interface.dot ]; then mv ${line}-interface.dot resource-${line}-dot_interface.dot; fi
# if [ -a resource-${line}-dot_interface.dot ]; then rm resource-${line}-dot_interface.${LOG}; fi

### done < ${ress}
done
