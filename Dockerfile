FROM python:3.9.12-alpine3.15
COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
COPY rest_api.py rest_api.py
CMD python3 rest_api.py
