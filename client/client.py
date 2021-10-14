import os
import time
import uuid

import requests


server = os.environ.get("SERVER_ADDRESS", "http://api-server")
port = os.environ.get("SERVER_PORT", 4996)


print("Sending requests to: %s:%d" % (server, port))


dummy_data = {
    "fname": "Jane",
    "lname": "Doe",
    "address": "123 Main Street",
    "city": "Richmond",
    "state": "Washington",
    "ssn": "123-223-2345",
    "email": "nr@aaa.com",
    "dob": "01/01/2010",
    "contactphone": "123-234-3456",
    "drugallergies": "Sulpha, Penicillin, Tree Nut",
    "preexistingconditions": "diabetes, hypertension, ashtma",
    "dateadmitted": "01/05/2010",
    "insurancedetails": "Primera Blue Cross"
}


while True:
    try:
        # create one patient record...
        patient_id = uuid.uuid4()
        print("Creating records for patient: %s\n" % patient_id)
        r_post = requests.post("%s:%d/patient/%s" % (server, port, patient_id), data=dummy_data)
        if r_post.status_code != 200:
            print(r_post.status_code)
            print(r_post.text)

        # retrieve one patient record...
        r_get = requests.get("%s:%d/patient/%s" % (server, port, patient_id))
        assert(r_get.status_code == 200)
        if r_get.status_code != 200:
            print(r_post.status_code)
            print(r_post.text)
        else:
            print("Records for patient %s: %s" % (patient_id, r_get.text))

        # retrieve one patient score...
        s_get = requests.get("%s:%d/score/%s" % (server, port, patient_id))
        assert(s_get.status_code == 200)
        if s_get.status_code != 200:
            print(r_post.status_code)
            print(r_post.text)
        else:
            print("Score for patient %s: %s" % (patient_id, s_get.text))
        
        print("Success!\n")
    except Exception as e:
        print("An error has occurred while trying to contact the server:", e)
        print("Retrying in 10 seconds...")
        continue
    finally:
        time.sleep(10)


