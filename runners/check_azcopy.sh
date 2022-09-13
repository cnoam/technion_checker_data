#!/bin/bash -eu

touch empty_file
SRC_FILE="empty_file"

#production setup
#CLUSTER_NAME=noam-spark
#STORAGE_NAME=noamcluster1hdistorage
CONTAINER_NAME=ex2
# Create the SAS using the GUI in the portal, by going to the storage,
# in "Data storage" select "Containers.
# select the container (e.g. "ex2" ).
# on the right hand side there is "..." and insdie "generate SAS"
# the secret has this format
#SECRET_SIG="sp=rw&st=2021-07-01T12:00:01Z&se=2025-01-01T21:40:51Z&spr=https&sv=2020-02-10&sr=c&sig=nCydcOygfUbu2Z66BPsjeIkF54kLSArJi0H%2BXXhL54w%3D"

export AZCOPY_LOG_LOCATION="/logs"
export AZCOPY_JOB_PLAN_LOCATION="/logs"
#echo PWD = `pwd`
echo $0
WORK_DIR=`echo $0 | sed 's|\(.*\)/.*|\1|'`
echo $WORK_DIR
$WORK_DIR/azcopy copy --log-level=NONE $SRC_FILE "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/$SRC_FILE?$SECRET_SIG"

