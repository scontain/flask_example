#!/bin/bash
#
# tasks performed:
#
# - creates a local Docker image with an encrypted Python program (flask patient service) and encrypted input file
#
# show what we do (-x), export all varialbes (-a), and abort of first error (-e)

set -x -a -e
trap "echo Unexpected error! See log above; exit 1" ERR

# CONFIG Parameters (might change)

export IMAGE=${CLIENT_IMAGE:-registry.scontain.com:5050/clenimar/network-shield-demo/client:0.1}
export SCONE_CAS_ADDR="5-5-0.scone-cas.cf"
export DEVICE="/dev/sgx/enclave"

export CLI_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/sconecli:alpine3.10-scone5.6.0-9c79a943"
export PYTHON_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/python:3.7.3-alpine3.10-scone5.6.0-9c79a943"
export PYTHON_MRENCLAVE="a156d6dd1e3edee6f5cda01c66d9399ccc5c642ef87644c3cabf0774ac310440"
export REDIS_IMAGE="registry.scontain.com:5050/clenimar/network-shield-demo/redis:6-alpine-scone5.6.0-9c79a943"
export REDIS_MRENCLAVE="a50a72bcc960a167dfb9c20dbcc0989db809ec53fc43241297c84e96a6514fc7"

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

echo "OK"
