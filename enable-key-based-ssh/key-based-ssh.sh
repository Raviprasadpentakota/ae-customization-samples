#!/bin/sh
#This script download the publickey from the object store and establish a key based ssh across the nodes.
authEndpoint=$1
COS_SECRET_KEY=$2
COS_ACCESS_KEY=$3
scriptPath=$4

downloadKeyFile()
{  
        hashs()
        {
         KEY="$1"
         DATA="$2"
         shift 2
         printf "$DATA" | openssl dgst -binary -sha256 -hmac "$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
        }

        hashh()
        {
         KEY="$1"
         DATA="$2"
         shift 2
         printf "$DATA" | openssl dgst -binary -sha256 -mac HMAC -macopt "hexkey:$KEY" | od -An -vtx1 | sed 's/[ \n]//g' | sed 'N;s/\n//'
        }


        # Signature function for S3 object store
        createSignatureKey()
        {
            keyDate=$(hashs AWS4$1 $2)
            keyRegion=$(hashh $keyDate $3)
            keyService=$(hashh $keyRegion $4)
            keySigning=$(hashh $keyService 'aws4_request')
            echo $keySigning
        }  

        REQUEST_TIME=$(date +"%Y%m%dT%H%M%SZ")
        REQUEST_DATE=$(printf "${REQUEST_TIME}" | cut -c 1-8)

        request_parameters=''
        host=`echo $authEndpoint | awk -F "//" '{print $2}'`
        standardized_resource=$scriptPath
        standardized_querystring=$request_parameters
        standardized_headers="host:$host\nx-amz-date:$REQUEST_TIME\n"
        echo standardized_headers: $standardized_headers
        signed_headers='host;x-amz-date'
        payload_hash=$(python -c "import hashlib; print hashlib.sha256('').hexdigest()")
        echo payload_hash: $payload_hash
        http_method='GET'
        region='universe'

        standardized_request="$http_method\n$standardized_resource\n$standardized_querystring\n$standardized_headers\n$signed_headers\n$payload_hash"
        echo standardized_request: $standardized_request

        hashing_algorithm='AWS4-HMAC-SHA256'
        credential_scope="$REQUEST_DATE/$region/s3/aws4_request"
        echo credential_scope: $credential_scope

        hashed_standardized_request=$(python -c "import hashlib; print hashlib.sha256('$standardized_request').hexdigest()")
        sts="$hashing_algorithm\n$REQUEST_TIME\n$credential_scope\n$hashed_standardized_request"
        echo sts: $sts

        signature_key=$(createSignatureKey $COS_SECRET_KEY $REQUEST_DATE $region 's3')
        echo signature_key: $signature_key

        signature=$(hashh $signature_key $sts)
        echo signature: $signature


        # assemble all elements into the 'authorization' header
        v4auth_header="$hashing_algorithm Credential=$COS_ACCESS_KEY/$credential_scope,SignedHeaders=$signed_headers,Signature=$signature"

        request_url="$authEndpoint$standardized_resource$standardized_querystring"

        curl -H "Authorization:$v4auth_header" -H "x-amz-date:$REQUEST_TIME" $request_url -o /tmp/ops_key
}
function sshAcrossNodes()
     {
cat > /tmp/key_based.exp <<EOF
        #!/usr/bin/expect -f
        set TARGET_HOST [lindex \$argv 0]
        set user [lindex \$argv 1]
        set passwd [lindex \$argv 2]
        set home [lindex \$argv 3]
        spawn scp -o StrictHostKeyChecking=no -r \$home/.ssh/ \$user@\$TARGET_HOST:\$home
        expect "*password*"
        send "\$passwd\n"
        expect eof
EOF

cat > /tmp/key_based.exp1 <<EOF
        #!/usr/bin/expect -f
        set TARGET_HOST [lindex \$argv 0]
        set user [lindex \$argv 1]
        set passwd [lindex \$argv 2]
        set home [lindex \$argv 3]
        spawn ssh-copy-id -i \$user@\$TARGET_HOST
        expect "*password*"
        send "\$passwd\n"
        expect eof
EOF

        cat /etc/hosts | awk -F " " '{print $3}' | grep ^chs  > /tmp/hostnames
        while read host ; do
        if [[ $host != *"mn001"* ]]; then
                expect /tmp/key_based.exp $host $AMBARI_USER $AMBARI_PASSWORD $HOME
                expect /tmp/key_based.exp1 $host $AMBARI_USER $AMBARI_PASSWORD $HOME
        fi
        done < /tmp/hostnames
    }
    
if [ "x$NODE_TYPE" == "xmanagement-slave2" ]; then
    downloadKeyFile
        if [ -e ~/.ssh/id_rsa ] && [ -e ~/.ssh/id_rsa.pub ];then
          cat /tmp/ops_key >> ~/.ssh/authorized_keys
          echo "the public key already generated please use it no need to re-generate."
        else
            ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
            status=$?
            if [ $status -eq 0 ];then
               cat /tmp/ops_key >> ~/.ssh/authorized_keys
               host=`uname -n`
               echo "generated the keys successfully on this host: $host"
            fi
        fi
    sshAcrossNodes
fi
