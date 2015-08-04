# script to remove possible issues following certain patterns from the possible issues results file
#!/bin/bash -xe

ISSUES=$(cat results_qt.log | cut -d ' ' -f 11)
ISSUES_TOTAL=$(cat results_qt.log | wc -l)

# clear file
> filtered_results_qt.log

# issues have the following format:
# t3376_opengl_qopengltexturehelper_cpp-R->/home/shane/src/qt/qt-everywhere-opensource-src-5.3.0/qtbase/examples/widgets/draganddrop/puzzle/
# qtbase/bin/moc->t19379_sub_embedded_make_first
echo "Starting to filter results"
I=0
for ISSUE in $ISSUES
do
	[ "$(($I % 1000))" -eq 0 ] && echo "$I/${ISSUES_TOTAL}"
	I=$((I+1))
	TARGETS=(${ISSUE//->/ })
	# strip -R from the end of the READ_TARGET
	READ_TARGET="${TARGETS[0]%??}"
	COMMAND="${TARGETS[1]}"
	WRITE_TARGET="${TARGETS[2]}"
	# get last part of string after _	
	READ_PATTERN=${READ_TARGET##*_}
	WRITE_PATTERN=${WRITE_TARGET##*_}
	# this should be a configurable thing but let's hack it for now
	if [ "${WRITE_PATTERN}" == "pro" ]
	then 
		continue
	fi

	if [ "${WRITE_PATTERN}" == "pri" ]
	then 
		continue
	fi
	if [[ $ISSUE == *"example"* ]]
	then
		continue
	fi
	
	if [[ "${WRITE_TARGET}" == *"moc"* ]]
	then 
		continue
	fi
	
	if [[ "${WRITE_TARGET}" == *"_first" ]]
	then 
		continue
	fi

	echo $ISSUE >> filtered_results_qt.log
	
done
echo "DONE"
