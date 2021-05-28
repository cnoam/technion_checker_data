#!/bin/bash
set -euxo pipefail
# test XV6 codebase by unzipping the user supplied file, compiling and running.
#
# the code must be based on my own commit, so the testing code is already inside


echo Running $1 with args $2 $3 $4
echo Timeout set to $UUT_TIMEOUT

INPUT_SRC=`realpath $1`
GOLDEN=`realpath $3`
COMPARATOR=`realpath $4`

TESTDIR=`mktemp -d`
# the master copy is from https://github.com/noam1023/xv6-public.git
MASTER_SRC_DIR=/data/data/94210/xv6/xv6-public
PATCH_DIR=/data/patches
pushd $TESTDIR
cp -r $MASTER_SRC_DIR .

# copy with the .git so we can clearly see diffs
cd xv6-public
# start with a well known commit
git checkout lsproc   # <<<<<<<<<<<<<<<<<<<<<< WARNING <<<<<<<<<<<< This is hardwired

set +e
git apply -3 $INPUT_SRC --whitespace=nowarn
if [ $? -ne 0 ]; then
    echo "------------>> Failed applying your patch. Please verify your patch contains only your changes."
    echo "and can be applied on top of the baseline code"
    exit 1
fi

set -e
git apply $PATCH_DIR/testcode.patch 
set +e

# first compile etc. so random output does not contaminate the user's program output
make fs.img xv6.img   >& /dev/null
if [ $? -ne 0 ]; then
    echo "------------>> Failed compiling your patch."
    exit 1
fi

/usr/bin/time  -f "run time: %U user %S system" timeout $UUT_TIMEOUT make qemu-nox > output
# if there is an error, this line is NOT executed ( "-e" )
# ...

#
echo --- finished the tested run.
set +e

echo Comparing output , $GOLDEN
python3 $COMPARATOR output $GOLDEN
retVal=$?
if [ $retVal -eq 42 ]; then
    echo "Sorry: actual output is different from the required output"
    exit 42
fi
if [ $retVal -ne 0 ]; then
    echo "Sorry: some error occured. Please examine the STDERR"
    exit 43
fi
popd
echo ---------- run OK
