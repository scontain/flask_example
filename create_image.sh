#!/bin/bash
#
# tasks performed:
#
# - creates a local Docker image with an encrypted Python program (flask patient service) and encrypted input file
# - pushes a new session to a CAS instance
# - creates a file with the session name
#
# show what we do (-x), export all varialbes (-a), and abort of first error (-e)

set -x -a -e
trap "echo Unexpected error! See log above; exit 1" ERR

# CONFIG Parameters (might change)

export IMAGE=${IMAGE:-flask_restapi_image}
export SCONE_CAS_ADDR="4-2-1.scone-cas.cf"
export DEVICE="/dev/sgx"

export CAS_MRENCLAVE="4cd0fe54d3d8d787553b7dac7347012682c402220acd062e4d0da3bbe10a1c2c"

export CLI_IMAGE="sconecuratedimages/sconecli:alpine3.7-scone4.2.1"
export PYTHON_IMAGE=" sconecuratedimages/experimental:scone-run-ubuntu18.04-python3.8.1"
export PYTHON_MRENCLAVE="7f3bd1a74e8ed3355656c6e262f26955678421af99d2ca7b0b439eac565900a9"
export REDIS_IMAGE="sconecuratedimages/experimental:redis-6-ubuntu"
export REDIS_MRENCLAVE="60c87d30d609afd79d9c0af2b211ac30291d72e8989c1c6895d9aa3703b28882"

# create random and hence, uniquee session number
FLASK_SESSION="FlaskSession-$RANDOM-$RANDOM-$RANDOM"
REDIS_SESSION="RedisSession-$RANDOM-$RANDOM-$RANDOM"

# create directories for encrypted files and fspf
rm -rf encrypted-files
rm -rf native-files
rm -rf fspf-file

mkdir native-files/
mkdir encrypted-files/
mkdir fspf-file/
cp fspf.sh fspf-file
cp rest_api.py native-files/

# ensure that we have an up-to-date image
docker pull $CLI_IMAGE

# check if SGX device exists

if [[ ! -c "$DEVICE" ]] ; then
    export DEVICE_O="DEVICE"
    export DEVICE="/dev/isgx"
    if [[ ! -c "$DEVICE" ]] ; then
        echo "Neither $DEVICE_O nor $DEVICE exist"
        exit 1
    fi
fi


# attest cas before uploading the session file, accept CAS running in debug
# mode (-d) and outdated TCB (-G)
docker run --device=$DEVICE -it $CLI_IMAGE sh -c "
scone cas attest -G --only_for_testing-debug  $SCONE_CAS_ADDR $CAS_MRENCLAVE >/dev/null \
&&  scone cas show-certificate" > cas-ca.pem

# create encrypted filesystem and fspf (file system protection file)
#docker run --device=$DEVICE  -it -v $(pwd)/fspf-file:/fspf/fspf-file -v $(pwd)/native-files:/fspf/native-files/ -v $(pwd)/encrypted-files:/fspf/encrypted-files $CLI_IMAGE /fspf/fspf-file/fspf.sh

cat >Dockerfile <<EOF
FROM $CLI_IMAGE as cli
FROM $PYTHON_IMAGE as requirements

COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

FROM requirements as fspf

ENV SCONE_MODE=sim
COPY native-files /fspf/native-files/
COPY fspf.sh /fspf.sh
COPY --from=cli /opt/scone/bin /opt/scone/bin
COPY --from=cli /opt/scone/scone-cli /opt/scone/scone-cli
COPY --from=cli /usr/local/bin/scone /usr/local/bin/scone
RUN mkdir -p /fspf/fspf-file && mkdir -p /fspf/encrypted-files && /fspf.sh && \
    cat /fspf/native-files/keytag

FROM requirements
COPY --from=fspf /fspf/fspf-file/fs.fspf /fspf/fs.fspf
COPY --from=fspf /fspf/encrypted-files /fspf/encrypted-files
EOF

# create a image with encrypted flask service
output=$(docker build --no-cache --pull -t $IMAGE .)
echo $output
KEYTAG=$(printf "$output" | grep "key:")

# ensure that we have self-signed client certificate

if [[ ! -f client.pem || ! -f client-key.pem  ]] ; then
    openssl req -newkey rsa:4096 -days 365 -nodes -x509 -out client.pem -keyout client-key.pem -config clientcertreq.conf
fi

# create session file

export SCONE_FSPF_KEY=$(echo $KEYTAG | awk '{print $11}')
export SCONE_FSPF_TAG=$(echo $KEYTAG | awk '{print $9}')

MRENCLAVE=$REDIS_MRENCLAVE envsubst '$MRENCLAVE $REDIS_SESSION $FLASK_SESSION' < redis-template.yml > redis_session.yml
# note: this is insecure - use scone session create instead
curl -v -k -s --cert client.pem  --key client-key.pem  --data-binary @redis_session.yml -X POST https://$SCONE_CAS_ADDR:8081/session
MRENCLAVE=$PYTHON_MRENCLAVE envsubst '$MRENCLAVE $SCONE_FSPF_KEY $SCONE_FSPF_TAG $FLASK_SESSION $REDIS_SESSION' < flask-template.yml > flask_session.yml
# note: this is insecure - use scone session create instead
curl -v -k -s --cert client.pem  --key client-key.pem  --data-binary @flask_session.yml -X POST https://$SCONE_CAS_ADDR:8081/session


# create file with environment variables

cat > myenv << EOF
export FLASK_SESSION="$FLASK_SESSION"
export REDIS_SESSION="$REDIS_SESSION"
export SCONE_CAS_ADDR="$SCONE_CAS_ADDR"
export IMAGE="$IMAGE"
export DEVICE="$DEVICE"

EOF

echo "OK"
