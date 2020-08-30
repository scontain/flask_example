#!/bin/bash
#
# tasks performed:
#
# - creates a docker image of a simple Flask-based application running in native mode
#
# show what we do (-x), export all variables (-a), and abort of first error (-e)

set -x -a -e
trap "echo Unexpected error! See log above; exit 1" ERR

# CONFIG Parameters (might change)

export IMAGE="native_flask_restapi_image"
export BASE_IMAGE=${BASE_IMAGE:-python:3.7-alpine3.11}

# Create debug certificate

## note: this is not completely correct...

openssl req -x509 -newkey rsa:4096 -keyout flask.key -out flask.crt -days 365 -nodes -subj '/CN=api'
openssl req -x509 -newkey rsa:4096 -keyout redis.key -out redis.crt -days 365 -nodes -subj '/CN=redis'

# Create Dockerfile to create image

cat >Dockerfile <<EOF
FROM $BASE_IMAGE
COPY rest_api.py /app/rest_api.py
COPY flask.key /tls/flask.key
COPY flask.crt /tls/flask.crt
COPY redis.crt /tls/redis-ca.crt
COPY redis.crt /tls/client.crt
COPY redis.key /tls/client.key
COPY requirements.txt /app/requirements.txt
RUN pip3 install -r /app/requirements.txt
CMD python3 /app/rest_api.py
EOF

# create a native image for the flask service
docker build --pull -t $IMAGE .

echo "OK"
