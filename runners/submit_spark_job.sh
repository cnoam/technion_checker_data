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
   CLUSTER_NAME=spark3
   STORAGE_NAME=noamcluster1hdistorage
   CONTAINER_NAME=proj
   # key for noamcluster1hdistorage/proj
   SECRET_SIG="sp=racwdl&st=2022-08-22T16:58:52Z&se=2022-09-30T00:58:52Z&spr=https&sv=2021-06-08&sr=c&sig=HzwKK2Bq%2FxdclT6ABc78IL4vY7%2Fc%2FdcEc8zNtT2XLZ0%3D"
 else
   #production setup
   CLUSTER_NAME=spark96224
   STORAGE_NAME=noamcluster1hdistorage
   CONTAINER_NAME=ex2
   # Create the SAS using the GUI in the portal, by going to the storage,
   # in "Data storage" select "Containers.
   # select the container (e.g. "ex2" ).
   # on the right hand side there is "..." and inside "generate SAS"
   # choose permissions (read,add,create,write)
   # set the date range properly!
   # key for noam1hdstorage/ex2
   SECRET_SIG="sp=racw&st=2022-07-20T11:52:20Z&se=2023-02-20T20:52:20Z&spr=https&sv=2021-06-08&sr=c&sig=YTB1kVUGIz0vnhmnsaoeB%2B%2B%2FVmnEoQ5aj5YeI19h1gk%3D"
fi

# for the uploaded file (to the azure storage) we keep only the relative name to avoid directory naming problems
REL_PATH_SRC_FILE=`echo $SRC_FILE | cut -d'/' -f 4`

# upload the file to storage
echo ">>>" Uploading source file $SRC_FILE
echo

#
## sanity test: we forbid old incompatible package
#grep "org.apache.spark:spark-sql-kafka-0-10_2.12:2.4.8" $SRC_FILE
#if [ $? -eq 0 ]; then
#  echo "OOPS! JAR package is not compatible with spark v3. Please remove it from the code (kafka and azure sql)"
#  exit 1
#fi

export AZCOPY_LOG_LOCATION="/logs"
export AZCOPY_JOB_PLAN_LOCATION="/logs"
PATH=$CHECKER_DATA_DIR/runners:$PATH  # so azcopy etc. is in the path
#echo PATH=$PATH

azcopy copy --log-level=NONE $SRC_FILE "https://$STORAGE_NAME.blob.core.windows.net/$CONTAINER_NAME/$REL_PATH_SRC_FILE?$SECRET_SIG" > /dev/null
if [ $? -ne 0 ]; then
  echo azcopy timed out or just failed. Is the server properly configured? Run the azcopy command from a terminal and check the output
  exit 1
fi

echo ">>>" Sending source for execution
# send to spark for processing

set +e
# We need Kafka package with the Spark. Since Azure uses Spark 2.4, we need to use a matching package.
#https://mvnrepository.com/artifact/org.apache.spark/spark-sql-kafka-0-10_2.12

#For the Spark 3.1.2 version,
# the Apache PySpark kernel is removed and a new Python 3.8 environment
# is installed under /usr/bin/miniforge/envs/py38/bin which is used by
# the PySpark3 kernel. The PYSPARK_PYTHON and PYSPARK3_PYTHON
# environment variables are updated with the following:
#
#problem reading JARs : https://github.com/GoogleCloudPlatform/spark-on-k8s-operator/issues/1226
# loading JAR from jupyter notebook: https://stackoverflow.com/questions/35946868/adding-custom-jars-to-pyspark-in-jupyter-notebook
#export PYSPARK_PYTHON=${PYSPARK_PYTHON:-/usr/bin/miniforge/envs/py38/bin/python}
#export PYSPARK3_PYTHON=${PYSPARK_PYTHON:-/usr/bin/miniforge/envs/py38/bin/python}
#   \"spark.jars.packages\" : \"org.apache.spark:spark-sql-kafka-0-10_2.12:2.4.8,com.microsoft.azure:spark-mssql-connector:1.0.1\" }\
#
# Use this for spark 3.x :
#\"conf\": { \
#            \"spark.yarn.maxAppAttempts\" : \"1\" , \
#            \"spark.yarn.appMasterEnv.PYSPARK_PYTHON\" : \"/usr/bin/miniforge/envs/py38/bin/python\", \
#            \"spark.yarn.appMasterEnv.PYSPARK3_PYTHON\" : \"/usr/bin/miniforge/envs/py38/bin/python\", \
#            \"spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON\" : \"/usr/bin/miniforge/envs/py38/bin/python\"  \
#            }\
# }" \

x=`curl --silent -k --user "admin:$LIVY_PASS" \
-X POST --data "{ \"file\":\"wasbs:///$REL_PATH_SRC_FILE\" , \
\"conf\": { \
\"spark.yarn.maxAppAttempts\" : \"1\" , \
\"spark.yarn.appMasterEnv.PYSPARK_PYTHON\" : \"/usr/bin/anaconda/envs/py35/bin/python\", \
\"spark.yarn.appMasterEnv.PYSPARK_DRIVER_PYTHON\" : \"/usr/bin/anaconda/envs/py35/bin/python\",  \
\"spark.jars.packages\" : \"org.apache.spark:spark-sql-kafka-0-10_2.12:2.4.8,com.microsoft.azure:spark-mssql-connector:1.0.1\" }\
 }" \
"https://$CLUSTER_NAME.azurehdinsight.net/livy/batches" \
-H "X-Requested-By: admin" \
-H "Content-Type: application/json" `

if [ $? -ne 0 ]; then
   echo Failed submitting the spark job. This is a server error.
   echo If you expected the server to work now, please send email to cnoam@technion.ac.il
   exit 1
fi
set -e
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
echo $x | grep 404 > /dev/null
if [ $? -eq 0  ]; then
   echo "====  Connection Error:  It looks like the Spark cluster is OFFLINE  ====="
   exit 1
fi
echo $x | grep starting > /dev/null
if [ $? -ne 0  ]; then
   echo "Job submission failed. See the log in Azure portal for batch ID " $BATCH_ID
else
   echo ">>> Job is starting..."
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
