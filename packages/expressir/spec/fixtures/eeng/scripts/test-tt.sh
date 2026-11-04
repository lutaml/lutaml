#!/bin/bash

# create arm.htm
# java -Xmx1024m -jar "${SAXON}"/saxon.jar -a \
#     -o "${MODULE}"/"${line}"/arm.htm "${MODULE}"/"${line}"/arm.xml \
#     output_type="HTM" output_rcs="NO"

# java -Xmx1024m -jar  "${SAXON}"/saxon.jar -a \
#     -o "${MODULE}"/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.htm \
#     "${MODULE}"/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.xml \
#     output_type="HTM" output_rcs="NO"

# This script produces the following files:
# arm_lf.flat, mim_lf.flat
# ap210_elec*_arm-interfaces.dot, ap210_elec*_mim-interfaces.dot
# arm_lf-pretty.exp, mim_lf-pretty.exp
# EXPRESS_*.txt
# arm_concatenated.exp, mim_concatenated.exp
# mim_lf-smrl-index.xml, mim_concatenated-smrl-index.xml

# for each line of qualify-mod.txt
# "${line}"_arm.xml, "${line}"_mim.xml

# for each line of qualify-res.txt
# "${line}".xml
export LOG=sbcl
export line=ap210_electronic_assembly_interconnect_and_packaging_design

export EENG=../eengine-*64"${LOG}"

# export STEPMOD=/src/sfdev/expeng/testcases/smrlv7
export STEPMOD=/src/boost/stepmod
export MODULE="${STEPMOD}"/data/modules
export RESOURCE="${STEPMOD}"/data/resources
export SAXON="${STEPMOD}"/etc/saxon6-5-5

# Create arm.xml
${EENG} --xml -mode arm_shortform -stepmod "${STEPMOD}"/ -schema "${MODULE}"/"${line}"/arm.exp -stepmod_vcs off -out-dir "${MODULE}"/"${line}"/ |& tee "output-${line}-arm.sbcl"
# Create mim.xml
${EENG} --xml -mode mim_shortform -stepmod "${STEPMOD}"/ -schema "${MODULE}"/"${line}"/mim.exp -stepmod_vcs off -out-dir "${MODULE}"/"${line}"/ |& tee "output-${line}-mim.sbcl"

# Convert arm.xml -> arm.htm
java -Xmx1025M -jar "${SAXON}"/saxon.jar -a -o "${MODULE}"/"${line}"/arm.htm "${MODULE}"/"${line}"/arm.xml output_type="HTM" output_rcs="NO"
# convert arm.htm -> arm.txt (EXPRESS)
w3m -dump -cols 1000 "${MODULE}"/"${line}"/arm.htm > /tmp/arm-0.txt
sed '/^Schema: /d' /tmp/arm-0.txt > /tmp/arm-1.txt
sed '/^Source :$/d' /tmp/arm-1.txt > "${MODULE}"/"${line}"/arm-xml.exp
${EENG} --compare -mode arm_shortform -stepmod "${STEPMOD}"/ -stepmod_vcs off -reference_schema "${MODULE}"/"${line}"/arm.exp -trial_schema "${MODULE}"/"${line}"/arm-xml.exp --xml-output -out-dir ./ |& tee arm-compare."${LOG}"

# Convert mim.xml -> mim.htm
java -Xmx1025M -jar "${SAXON}"/saxon.jar -a -o "${MODULE}"/"${line}"/mim.htm "${MODULE}"/"${line}"/mim.xml output_type="HTM" output_rcs="NO"
# convert mim.htm -> mim.txt (EXPRESS)
w3m -dump -cols 1000 "${MODULE}"/"${line}"/mim.htm > /tmp/mim-0.txt
sed '/^Schema: /d' /tmp/mim-0.txt > /tmp/mim-1.txt
sed '/^Source :$/d' /tmp/mim-1.txt > "${MODULE}"/"${line}"/mim-xml.exp
${EENG} --compare -mode mim_shortform -stepmod "${STEPMOD}"/ -stepmod_vcs off -reference_schema "${MODULE}"/"${line}"/mim.exp -trial_schema "${MODULE}"/"${line}"/mim-xml.exp --xml-output -out-dir ./ |& tee mim-compare."${LOG}"
