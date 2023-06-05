#!/bin/bash -ex
#This script takes as input a zip file that contains source code.
#
#1. extract the files
#2. compile
#4. run the executable
#5. compare the output (stdout) to the supplied golden reference and return pass/fail
#
# return value:
# 0     full success
# any other value - failure of some sort
echo running $0 $1 $2 $3 $4
echo `pwd`
function Usage()
{
    echo "Usage:"
    echo "checker_c  some_file.zip input_data_file the_needed_output full/path/to/compare/script"
}

# if [ -z "$4" ]; then
#  Usage
#  exit 40
# fi

INPUT_C=`realpath $1`
#COMPARATOR=`realpath $4`

TESTDIR=`mktemp -d`
pushd /tmp
rm -rf $TESTDIR
mkdir $TESTDIR
cp /data/runners/check_94210_hw1.c $TESTDIR
cd $TESTDIR

sed -e "s/main/nomain/" $INPUT_C > cleaned.c
gcc check_hw1.c cleaned.c -o exe
echo ----------- compilation OK
# do not remove the tempdir, to allow for postmortem
echo --- about to run: $EXE $INPUT_DATA
/usr/bin/time  -f "run time: %U user %S system" timeout $UUT_TIMEOUT ./exe $INPUT_DATA > output
echo --- finished the tested run.
set +e

echo Comparing output , $GOLDEN
python $COMPARATOR output $GOLDEN
retVal=$?

# ExitCode.COMPARE_FAILED == 42
if [ $retVal -eq 42 ]; then
    echo "Sorry: output is different from the required output"
fi
if [ $retVal -ne 0 ]; then
    echo "Sorry: some error occured. Please examine the STDERR"
fi
popd
exit $retVal
echo ---------- run OK


