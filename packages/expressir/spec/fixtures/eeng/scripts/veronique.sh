#!/bin/bash

export STEPMOD=/src/boost/stepmod
export saxon=${STEPMOD}/etc/saxon6-5-5
# export java=java -Xmx1024M

export AP210=${STEPMOD}/data/modules/ap210_electonic_assembly_interconnect_and_packaging_design
#export AP209=${STEPMOD}/data/modules/ap209_multidisciplinary_analysis_and_design
#export AP242=${STEPMOD}/data/modules/ap242_managed_model_based_3d_engineering


# These last three are not in my script.  If I could get a concise
# > > description of how to do (4) and (5) I could add them.
# > > > 4-generate html
# > > > java ....
# > For arm

java -Xmx1024M -jar ${saxon}/saxon.jar -a -o ./ap210-arm.htm ${AP210}/sys/4_info_reqs.xml output_type="HTM" output_rcs="NO"
# ${STEPMOD}/utils/part1000/CR_DiffExpHtml.sh -m

# > java -Xmx1024m -jar  c:/apps/saxon6-5-5/saxon.jar -a -o
# > ../data/modules/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.htm
# > ../data/modules/ap210_electronic_assembly_interconnect_and_packaging_design/sys/4_info_reqs.xml
# > output_type="HTM" output_rcs="NO"
# > 
# > That is for the arm.
# > mim is 5_mim.xml.

java -Xmx1024M -jar ${saxon}/saxon.jar -a -o ./ap210-mim.htm ${AP210}/sys/5_mim.xml output_type="HTM" output_rcs="NO"

# > For resource parts it is a little trickier as the schemas are
# > numbered positionally in the sys directory.
# > java -Xmx1024m -jar  c:/apps/saxon6-5-5/saxon.jar -a -o
# > ../data/resource_docs/geometric_and_topological_representation/sys/c_
# > schema_<n>.htm
# > ../data/resource_docs/geometric_and_topological_representation/sys/c_
# > schema_<n>.xml output_type="HTM" output_rcs="NO"

# ${java} -jar ${saxon}/saxon.jar -a \
#     -o ${STEPMOD}/data/resource_docs/geometric_and_topological_representation/sys/c_schema_<n>.htm \
#     ${STEPMOD}/data/resource_docs/geometric_and_topological_representation/sys/c_schema_<n>.xml \
#     output_type="HTM" output_rcs="NO"

# > There is a copy of saxon.jar on stepmod/etc/saxon6-5-5.
# > 
# > > > 5-extract EXPRESS from xml
# > > > veronique_script.sh ...
# > stepmod/utils/part1000/CR_DiffExpHtml.sh

# ${STEPMOD}/utils/part1000/CR_DiffExpHtml.sh -m 

# > Apparently this script does a brute-force attack, and includes a
# > compare of its own.
# > See if it is useful.
# > > > 6-compare extracted EXPRESS with source schema
# > > > eengine --compare

# ${EENG} --compare \
#     -reference_schema <> \
#     -trial_schema <>
 
