# script to extract and count patterns from the possible issues results file
#!/bin/bash -xe

ISSUES=$(cat results_qt.log | cut -d ' ' -f 11)
ISSUES_TOTAL=$(cat results_qt.log | wc -l)

# clear file
> patterns.log

# issues have the following format:
# t3376_opengl_qopengltexturehelper_cpp-R->/home/shane/src/qt/qt-everywhere-opensource-src-5.3.0/qtbase/examples/widgets/draganddrop/puzzle/
# qtbase/bin/moc->t19379_sub_embedded_make_first
echo "Starting common pattern analysis"
I=0
for ISSUE in $ISSUES
do
	[ "$(($I % 1000))" -eq 0 ] && echo "$I/${ISSUES_TOTAL}"
	TARGETS=(${ISSUE//->/ })
	# strip -R from the end of the READ_TARGET
	READ_TARGET="${TARGETS[0]%??}"
	COMMAND="${TARGETS[1]}"
	WRITE_TARGET="${TARGETS[2]}"
	# get last part of string after _	
	READ_PATTERN=${READ_TARGET##*_}
	WRITE_PATTERN=${WRITE_TARGET##*_}
	PATTERN="${READ_PATTERN}_${WRITE_PATTERN}"
	echo $PATTERN >> patterns.log
	I=$((I+1))
done
echo "DONE"

echo "Counting pattern occurences"
sort patterns.log | uniq -c | sort -n -r | tee patterns_count.log
echo "DONE"

rm patterns.log
