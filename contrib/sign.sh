#!/bin/bash
CONT_JSON="Content-Type: application/json"
ACPT_JSON="Accept: application/json"
CURL_AUTH=(--basic -u "oc:${OCSIGN_SERVICE_KEY}")
SERVER_URL="https://ocsign.openconnect-vpn.net:${OCSIGN_SERVICE_PORT}/sign"

#check for required programs
which zip       >/dev/null 2>&1 || { echo "zip not found"; exit 1; }
which unzip     >/dev/null 2>&1 || { echo "unzip not found"; exit 1; }
which sha256sum >/dev/null 2>&1 || { echo "sha256sum not found"; exit 1; }
which base64    >/dev/null 2>&1 || { echo "base64 not found"; exit 1; }
which jq        >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
which curl      >/dev/null 2>&1 || { echo "curl not found"; exit 1; }

EXEEXT=.exe
input=$1

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"

echo Signing called with \"$input\"

if [ ! -f "$input" ]; then
    echo Input file not found: \"$input\"
    exit 1
fi

backup=$(dirname $input)/$(basename -s ${EXEEXT} $input).unsigned${EXEEXT}

if [ -f $backup ]; then
    rm -f $backup || exit 2
fi

echo Keeping backup of $input to $backup
cp "$input" "$backup"


#create unsigned.zip containing $file and compute the sha256sum of file
echo "Creating zip with file $input"
cwd=`pwd`
workdir=$(dirname $input)
rm -f ${cwd}/unsigned.zip
cd $workdir
zip -q ${cwd}/unsigned.zip $(basename $input)
cd $cwd
file=unsigned.zip
hash=$( cat $file | sha256sum | cut -d " " -f 1 -s )

#submit the file for signing
# sample responses 
#    {"status":"queued","id":"f6464cfb-3bd5-422c-b878-e360e4dd1773"}
#    {"status":"failed","error":{"message":"Hash does not match."}}

submit_response=$(
  (echo -n '{"file": "'; base64 -w 0 $file; echo '", "hash": "'${hash}'", "description": "-", "url": "-"}') | 
   curl -s ${CURL_AUTH[@]} -H "${CONT_JSON}" -d @-  ${SERVER_URL}/
)
curl_status=$?

if [ $curl_status -ne 0 ]; then
    echo "Failed to submit file for signing, curl exited with code $curl_status"
    exit 3
fi

request_status=$( echo $submit_response| jq ".status" | tr -d '"' )
request_id=$(     echo $submit_response| jq ".id" | tr -d '"' )
request_error=$(  echo $submit_response| jq ".error.message" | tr -d '"' )

if [ "$request_status" != "queued" ] ; then
    echo Failed to submit file for signing. $request_status: $request_error
    echo Submit response $submit_response
    exit 3
fi

echo Submitted request with id $request_id. Current status $request_status

#poll the server until processing completes
trials=20
interval=10

while [[ ${request_status} = "processing" || $request_status = "queued" ]] && [[ $trials > 0 ]];
do
    echo "Sign Server Processing. Waiting $interval seconds"
    sleep $interval
    #sample responses
    #   {"status":"processing"}
    #   {"status":"completed","hash":"96b874b2ff868ed8afc280330cb9008c61c3191b2e6090051318f3752e47d590"} 
    #   {"status":"failed","error: { "message":"Unable to create directory structure"} }
    status_response=$( curl -s ${CURL_AUTH[@]} -H "${CONT_JSON}" ${SERVER_URL}/${request_id}/status )
    curl_status=$?
    request_status=$( echo $status_response | jq ".status" | tr -d '"' )

    if [ $curl_status -ne 0 ]; then
        echo "Failed to get server status, curl exited with code $curl_status"
        exit 4
    fi

    #echo $status_response
    let trials=trials-1
done;

if [ "${request_status}" != "completed" ]; then
    echo "Server returned: ${status_response}"
    exit 5
else
    outfile=${cwd}/signed.zip
    rm -f ${outfile}
    echo "Retrieving signed file into ${outfile}"

    expected_hash=$( echo $status_response | jq ".hash" | tr -d '"' )

    if [ "x${expected_hash}" = "xnull" ]; then
        echo "Hash not found in output: ${status_response}"
	exit 6
    fi

    http_response_code=$(curl -s ${CURL_AUTH[@]} -H "${ACPT_JSON}" -w "%{response_code}" -o $outfile ${SERVER_URL}/${request_id}/result)

    if [ "$http_response_code" != "200" ]; then
        echo "Server returned:" $http_response_code
        cat $outfile
        rm $outfile
	exit 6
    else
        echo Retrieved $outfile
	actual_hash=$(sha256sum $outfile | cut -d " " -f 1 -s)

	if [ $actual_hash != $expected_hash ]; then
	    echo "Hash verification failed: expected hash $expected_hash ; computed hash $actual_hash"
	    exit 6
	else
	    echo "Hash verification succeeded: ${expected_hash}"
	fi
    fi
fi

rm -f $input
cd $workdir
unzip -o $outfile
ret=$?
cd $cwd

if [ $ret -ne 0 ]; then
    echo "Unzip failed. Exit code $ret"
    exit 6
fi

if [ ! -f "$input" ]; then
    echo "Output file \"$input\" not found"
    exit 6
fi

echo "Comparing $backup with signed"

objdump -s ${input} |tail -n +3 > out.signed
objdump -s ${backup} |tail -n +3 > out.orig
cmp out.signed out.orig
ret=$?
rm -f out.signed out.orig

if [ $ret -ne 0 ]; then
    echo "The signed executable sections differ from the original"
    exit 7
fi

touch $input

exit 0
