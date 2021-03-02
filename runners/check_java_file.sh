#!/bin/bash

# Try to compile and run a set of java files packaged in a zip file.
# The zip file MUST contain a 'src' directory.
# in the src directory, MUST have a java file Main.java that will run all the code.

# tell the shell to fail if something goes wrong
set -exuo pipefail

echo Running "$1" "$2" "$3" "$4" "$5"
echo Timeout set to "$UUT_TIMEOUT"

INPUT_SRC=`realpath $1`
INPUT_DATA=`realpath $2`
GOLDEN=`realpath $3`
COMPARATOR=`realpath $4`
DATA_DIR=`realpath $5`

# extract the zip in a temp directory. This allows for parallel runs without cross influences
TESTDIR=`mktemp -d`
pushd /tmp
rm -rf $TESTDIR
mkdir $TESTDIR
cd $TESTDIR
echo PWD="`pwd`"

# extract the zip, cd to src, compile
unzip $INPUT_SRC
cd src
javac Main.java
echo ==== compilation OK ====

# run the compiled code within a timeout limit, measure how long it takes.
#
# write the output to both stdout and local file.
# the local file is used for pass/fail checking here (but in the future might be moved to inside the python code)
/usr/bin/time  -f "run time: %U user %S system"  timeout $UUT_TIMEOUT java Main  $DATA_DIR $INPUT_DATA | tee output
echo ==== finished the tested run ====

set +e
echo Comparing output , $GOLDEN
python3 $COMPARATOR output $GOLDEN
retVal=$?
if [ $retVal -eq 42 ]; then
    echo "Sorry: actual output is different from the required output"
    exit 42
fi
if [ $retVal -ne 0 ]; then
    echo "Sorry: some error occurred. Please examine the STDERR"
    exit 43
fi
popd
echo ---------- run OK
