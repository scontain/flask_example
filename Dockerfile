FROM registry.scontain.com:5050/sconecuratedimages/proximus:3.9.5-alpine3.12-prd
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
COPY rest_api.py rest_api.py
CMD python3 rest_api.py
