#!/bin/bash

export LOG=sbcl
# export LOG=ccl

export EENG=../eengine-*64${LOG}

# export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
export STEPMOD=/src/boost/stepmod
export MODULE=${STEPMOD}/data/modules
export RESOURCE=${STEPMOD}/data/resources
export SAXON=${STEPMOD}/etc/saxon6-5-5

ress=../qualify-res.txt

## process a set of Resources
## For each Resource
##   --xml

## To be done:
##   --pretty
##   --dot -graph interface
##   --list
##   --list --xml-output

export schemata=systems_engineering_representation_schema

### while IFS= read -r line; do
for line in ${schemata}; do
    printf ';; #### [%s]\n' "$line"

if [ -a ${RESOURCE}/${line}/${line}.exp ]; then
    cp ${RESOURCE}/${line}/${line}.exp resource-${line}.exp
fi

## XML File
${EENG} --xml -mode resource -stepmod ${STEPMOD}/ \
    -schema ${RESOURCE}/${line}/${line}.exp \
    -out-dir ${RESOURCE}/${line}/ |& tee resource-${line}-XML.${LOG}
if [ -a ${RESOURCE}/${line}/${line}.xml ]; then rm resource-${line}-XML.${LOG}; fi

## XML ==> HTM
java -Xmx1024M -jar ${SAXON}/saxon.jar -a -o ${RESOURCE}/${line}/${line}.htm ${RESOURCE}/${line}/${line}.xml \
    output_type="HTM" output_rcs="NO" |& tee resource-${line}-HTM.${LOG}
if [ -a ${RESOURCE}/${line}/${line}.htm ]; then
    cp ${RESOURCE}/${line}/${line}.xml resource-${line}.xml
    rm resource-${line}-HTM.${LOG}
fi

w3m -dump -cols 1000 ${RESOURCE}/${line}/${line}.htm > resource-${line}-res-0.txt |& tee resource-${line}-res-htm.w3m
sed '/^Schema: /d' resource-${line}-res-0.txt > resource-${line}-res-1.txt
sed '/^Source :/d' resource-${line}-res-1.txt > resource-${line}-res-2.txt
sed '/\[warning:\]Error IF-3/d' resource-${line}-res-2.txt > resource-${line}-res-xml.exp
if [ -a resource-${line}-res-xml.exp ]; then
    mv ${RESOURCE}/${line}/${line}.htm resource-${line}-res-xml.htm
fi

## compare with original EXPRESS file
${EENG} --compare -mode resource -stepmod ${STEPMOD}/ -stepmod_vcs off \
    -reference_schema resource-${line}.exp -trial_schema resource-${line}-res-xml.exp \
    -out-dir ./ |& tee resource-${line}-res-xml-compare.${LOG}
if [ -a EXPRESS_resource_shortform_comparison_results.txt ]; then
    mv EXPRESS_resource_shortform_comparison_results.txt resource-${line}-res-xml-comparison.txt
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
