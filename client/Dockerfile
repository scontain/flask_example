FROM registry.scontain.com:5050/clenimar/network-shield-demo/python:3.7.3-alpine3.10-scone5.6.0-9c79a943

COPY encrypted-files /fspf/encrypted-files
COPY fspf-file/fs.fspf /fspf/fs.fspf
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
