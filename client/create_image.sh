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

export IMAGE=${IMAGE:-registry.scontain.com:5050/clenimar/network-shield-demo/client:0.1}
export SCONE_CAS_ADDR="5-5-0.scone-cas.cf"
export DEVICE="/dev/sgx/enclave"

#export CAS_MRENCLAVE="4cd0fe54d3d8d787553b7dac7347012682c402220acd062e4d0da3bbe10a1c2c"

export CLI_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/sconecli:alpine3.10-scone5.6.0-9c79a943"
export PYTHON_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/python:3.7.3-alpine3.10-scone5.6.0-9c79a943"
export PYTHON_MRENCLAVE="a156d6dd1e3edee6f5cda01c66d9399ccc5c642ef87644c3cabf0774ac310440"
export REDIS_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/redis:6-alpine-scone5.6.0-9c79a943"
export REDIS_MRENCLAVE="a50a72bcc960a167dfb9c20dbcc0989db809ec53fc43241297c84e96a6514fc7"

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
cp client.py native-files/

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
scone cas attest -GCS --only_for_testing-debug --only_for_testing-trust-any --only_for_testing-ignore-signer $SCONE_CAS_ADDR >/dev/null \
&&  scone cas show-certificate" > cas-ca.pem

# create encrypte filesystem and fspf (file system protection file)
docker run --device=$DEVICE  -it -v $(pwd)/fspf-file:/fspf/fspf-file -v $(pwd)/native-files:/fspf/native-files/ -v $(pwd)/encrypted-files:/fspf/encrypted-files $CLI_IMAGE /fspf/fspf-file/fspf.sh

cat >Dockerfile <<EOF
FROM $PYTHON_IMAGE

COPY encrypted-files /fspf/encrypted-files
COPY fspf-file/fs.fspf /fspf/fs.fspf
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
EOF

# create a image with encrypted flask service
docker build --pull -t $IMAGE .
docker push $IMAGE

# ensure that we have self-signed client certificate
exit 0
if [[ ! -f client.pem || ! -f client-key.pem  ]] ; then
    openssl req -newkey rsa:4096 -days 365 -nodes -x509 -out client.pem -keyout client-key.pem -config clientcertreq.conf
fi

# create session file

export SCONE_FSPF_KEY=$(cat native-files/keytag | awk '{print $11}')
export SCONE_FSPF_TAG=$(cat native-files/keytag | awk '{print $9}')

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
