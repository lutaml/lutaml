#!/bin/bash

export EENG=cl64sbcl
export STEPMOD=/src/boost/stepmod/

export AP209=${STEPMOD}/data/modules/ap209_multidisciplinary_analysis_and_design
export AP210=${STEPMOD}/data/modules/ap210_electronic_assembly_interconnect_and_packaging_design
export AP242=${STEPMOD}/data/modules/ap242_managed_model_based_3d_engineering

#
# pretty print several major schemata
#

# ap209
${EENG} --pretty -mode arm_shortform -schema ${AP209}/arm.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap209-arm-pretty-sf.sbcl
if test arm-pretty.exp; then  mv arm-pretty.exp ap209-arm-pretty.exp; fi
${EENG} --pretty -mode arm_longform  -schema ${AP209}/arm_lf.exp -out-dir ./ |& tee ap209-arm-pretty-lf.sbcl
if test arm_lf-pretty.exp; then mv arm_lf-pretty.exp ap209-arm_lf-pretty.exp; fi
${EENG} --pretty -mode mim_shortform -schema ${AP209}/mim.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap209-mim-pretty-sf.sbcl
if test mim-pretty.exp; then mv mim-pretty.exp ap209-mim-pretty.exp; fi
${EENG} --pretty -mode mim_longform  -schema ${AP209}/mim_lf.exp -out-dir ./ |& tee ap209-mim-pretty-lf.sbcl
if test mim_lf-pretty.exp; then mv mim_lf-pretty.exp ap209-mim_lf-pretty.exp; fi

# ap210
${EENG} --pretty -mode arm_shortform -schema ${AP210}/arm.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap210-arm-pretty-sf.sbcl
if test arm-pretty.exp; then mv arm-pretty.exp ap210-arm-pretty.exp; fi
${EENG} --pretty -mode arm_longform  -schema ${AP210}/arm_lf.exp -out-dir ./ |& ap210-arm-pretty-lf.sbcl
if test arm_lf-pretty.exp; then mv arm_lf-pretty.exp ap210-arm_lf-pretty.exp; fi
${EENG} --pretty -mode mim_shortform -schema ${AP210}/mim.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap210-mim-pretty-sf.sbcl
if test mim-pretty.exp; then mv mim-pretty.exp ap210-mim-pretty.exp; fi
${EENG} --pretty -mode mim_longform  -schema ${AP210}/mim_lf.exp -out-dir ./ |& tee ap210-mim-pretty-lf.sbcl
if test mim_lf-pretty.exp; then mv mim_lf-pretty.exp ap210-mim_lf-pretty.exp; fi

# ap242
${EENG} --pretty -mode arm_shortform -schema ${AP242}/arm.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap242-arm-pretty-sf.sbcl
if test arm-pretty.exp; then mv arm-pretty.exp ap242-arm-pretty.exp; fi
${EENG} --pretty -mode arm_longform  -schema ${AP242}/arm_lf.exp -out-dir ./ |& tee ap242-arm-pretty-lf.sbcl
if test arm_lf-pretty.exp; then mv arm_lf-pretty.exp ap242-arm_lf-pretty.exp; fi
${EENG} --pretty -mode mim_shortform -schema ${AP242}/mim.exp -stepmod ${STEPMOD} -out-dir ./ |& tee ap242-mim-pretty-sf.sbcl
if test mim-pretty.exp; then mv mim-pretty.exp ap242-mim-pretty.exp; fi
${EENG} --pretty -mode mim_longform  -schema ${AP242}/mim_lf.exp -out-dir ./ |& tee ap242-mim-pretty-lf.sbcl
if test mim_lf-pretty.exp; then mv mim_lf-pretty.exp ap242-mim_lf-pretty.exp; fi
