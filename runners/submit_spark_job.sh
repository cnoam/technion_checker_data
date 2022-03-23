#!/bin/bash -eu

# for unknown reason, if the azcopy returns with a failure when run from the command line, it hangs when runs in the script
# and don't even trip the timeout.
# I added "> junk" redirect and for one time it did work and the call returned. However it is not working properly now.

LIVY_PASS="%Qq12345678"
SRC_FILE=$1
MY_SERVER=jobs.eastus.cloudapp.azure.com
AZ_COPY_TIMEOUT_SEC=5

TEST_MODE=0

if [ $TEST_MODE -eq 1 ]; then
   echo ---- test setup -----
   CLUSTER_NAME=noam-c3
   STORAGE_NAME=noamc3hdistorage
   CONTAINER_NAME=noam-c3-2021-04-06t10-05-57-099z
   SECRET_SIG="sp=racwl&st=2021-06-24T05:00:23Z&se=2021-09-01T13:28:23Z&spr=https&sv=2020-02-10&sr=c&sig=4IIHWei9gAY4LqkZd3qN7v%2B%2BqU8JWHHMzAJDCpokAJ0%3D"
else
   #production setup
   CLUSTER_NAME=spark96224
   STORAGE_NAME=noamcluster1hdistorage
   CONTAINER_NAME=ex2
   # Create the SAS using the GUI in the portal, by going to the storage,
   # in "Data storage" select "Containers.
   # select the container (e.g. "ex2" ).
   # on the right hand side there is "..." and insdie "generate SAS"
   # key for noam1hdstorage
   SECRET_SIG="sp=racw&st=2022-03-22T14:06:27Z&se=2022-06-30T21:06:27Z&sv=2020-08-04&sr=c&sig=IrLmcnjxV9TJWPOl4Da0%2F%2FdMbXzoC0eGMgQsL6cYAYk%3D"
fi

# for the uploaded file (to the azure storage) we keep only the relative name to avoid directory naming problems
REL_PATH_SRC_FILE=`echo $SRC_FILE | cut -d'/' -f 4`

# upload the file to storage
echo Uploading source file $SRC_FILE
export AZCOPY_LOG_LOCATION="/logs"
export AZCOPY_JOB_PLAN_LOCATION="/logs"
PATH=$CHECKER_DATA_DIR/runners:$PATH  # so azcopy etc. is in the path
echo PATH==$PATH
azcopy copy $SRC_FILE "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/$REL_PATH_SRC_FILE?$SECRET_SIG"
# bad syntax below
#[ $? -ne 0 ]; then
#   echo azcopy timed out or just failed. Is the server properly configured? Run the azcopy command from a terminal and check the output
#fi

echo Sending source for execution
# send to spark for processing

# We need Kafka package with the Spark. Since Azure uses Spark 2.4, we need to use a matching package.
#https://mvnrepository.com/artifact/org.apache.spark/spark-sql-kafka-0-10_2.12
x=`curl --silent -k --user "admin:$LIVY_PASS" \
-X POST --data "{ \"file\":\"wasbs:///$REL_PATH_SRC_FILE\" , \
\"conf\": { \"spark.yarn.appMasterEnv.PYSPARK_PYTHON\" : \"/usr/bin/anaconda/envs/py35/bin/python\", \
\"spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON\" : \"/usr/bin/anaconda/envs/py35/bin/python\",  \
\"spark.jars.packages\" : \"org.apache.spark:spark-sql-kafka-0-10_2.12:2.4.8,com.microsoft.azure:spark-mssql-connector:1.0.1\" }\
 }" \
"https://$CLUSTER_NAME.azurehdinsight.net/livy/batches" \
-H "X-Requested-By: admin" \
-H "Content-Type: application/json" `

BATCH_ID=`echo $x | cut -d: -f 2-2 | cut -d, -f 1`

# the response looks like
# {"id":11,"state":"starting","appId":null,"appInfo":{"driverLogUrl":null,"sparkUiUrl":null},"log":["stdout: ","\nstderr: ","\nYARN Diagnostics: "]}

get_app_id(){
  # check the status of the batch
  y=`curl --silent -k --user "admin:$LIVY_PASS"  -H "Content-Type: application/json"  \
    "https://$CLUSTER_NAME.azurehdinsight.net/livy/batches/$1"   \
    -H "X-Requested-By: admin"`

  # set the GLOBAL "appId"
  appId=`echo $y | jq -r .appId`
  echo get_app_id   APP ID = $appId
}

wait_for_app_id() {
# param: $1 == batch_id
# wait up to 20 seconds to get the App ID.
    for i in $(seq 1 20); do
      sleep 1
      get_app_id $1
      echo ID = $appId
      if [[ $appId =~ "application" ]]; then
        echo "Found ID = "$appId
        return 0
      else echo "still don't have ID for batch " $1
      fi
    done
    return 1
}
echo $x
echo =============
set +e
echo $x | grep 404 > blackhole
if [ $? -eq 0  ]; then
   echo "====  Connection Error:  It looks like the Spark cluster if OFFLINE  ====="
   exit 1
fi
echo $x | grep starting > blackhole
if [ $? -ne 0  ]; then
   echo "Job submission failed. See the log in Azure portal for batch ID " $BATCH_ID
else
   echo "Job is starting..."
   #echo "You can check the status at https://$CLUSTER_NAME.azurehdinsight.net/yarnui/hn/cluster"
fi

echo "BATCH ID = "$BATCH_ID


# While testing, I saw that sometime it takes more than 20 sec to get the appId.
# so I prefer to return immedialtly, and let the user query using the batch ID ( from the Checker)
#wait_for_app_id $BATCH_ID
#if [ $? -ne 0  ]; then
#   echo "Job submission failed. See the log in Azure portal for batch ID " $BATCH_ID
#fi
set -e

# get the logs (maybe too early )
# MUST use public key here.
# run ssh-copyid sshuser@$CLUSTER_NAME-ssh.azurehdinsight.net before!!
#logs=`ssh sshuser@$CLUSTER_NAME-ssh.azurehdinsight.net yarn logs -applicationId $appId`
#echo LOGS =======
#echo $logs > log_output
echo ================================================================
echo To see the logs:     http://$MY_SERVER/spark/logs?batchId=$BATCH_ID
echo  =====
echo
echo To manualy delete this job, visit the link below. WARNING: no confirmation! I will try to delete without questions!
echo http://$MY_SERVER/spark/delete?batchId=$BATCH_ID
