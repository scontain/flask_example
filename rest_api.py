from flask import Flask, request, jsonify, Response
from flask_restful import Resource, Api
import json
import os
import random
import redis


app = Flask(__name__)
api = Api(app)


# Setup redis instance.
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", 6379)
db = redis.StrictRedis(
   host=REDIS_HOST,
   port=REDIS_PORT,
   ssl=False,
   ssl_keyfile='/tls/client.key',
   ssl_certfile='/tls/client.crt',
   ssl_cert_reqs="required",
   ssl_ca_certs='/tls/redis-ca.crt')

# Test connection to redis (break if the connection fails).
db.info()


class Patient(Resource):
    def get(self, patient_id):
        patient_data = db.get(patient_id)
        if patient_data is not None:
            decoded_data = json.loads(patient_data.decode('utf-8'))
            decoded_data["id"] = patient_id
            return jsonify(decoded_data)
        return Response({"error": "unknown patient_id"}, status=404, mimetype='application/json')

    def post(self, patient_id):
        if db.exists(patient_id):
            return Response({"error": "already exists"}, status=403, mimetype='application/json')
        else:
            # convert patient data to binary.
            patient_data = json.dumps({
            "fname": request.form['fname'],
            "lname": request.form['lname'],
            "address": request.form['address'],
            "city": request.form['city'],
            "iban": request.form['iban'],
            "ssn": request.form['ssn'],
            "email": request.form['email'],
            "score": random.random()
            }).encode('utf-8')
            try:
                db.set(patient_id, patient_data)
            except Exception as e:
                print(e)
                return Response({"error": "internal server error"}, status=500, mimetype='application/json')
            patient_data = json.loads(patient_data.decode('utf-8'))
            patient_data["id"] = patient_id
            return jsonify(patient_data)


class Score(Resource):
    def get(self, patient_id):
        patient_data = db.get(patient_id)
        if patient_data is not None:
            score = json.loads(patient_data.decode('utf-8'))["score"]
            return jsonify({"id": patient_id, "score": score})
        return Response({"error": "unknown patient"}, status=404, mimetype='application/json')


class Listkeys(Resource):
    def get(self):
        all_keys = db.keys(pattern="*")
        if all_keys is not None:
            all_data = [db.get(k) for k in all_keys]
            all_data_d = [json.loads(v.decode('utf-8')) for v in all_data]
            score = json.dumps(all_data_d)
            return jsonify({"keys": all_data_d})
        return Response({"error": "no keys"}, status=404, mimetype='application/json')

api.add_resource(Patient, '/patient/<string:patient_id>')
api.add_resource(Score, '/score/<string:patient_id>')
api.add_resource(Listkeys, '/keys')


if __name__ == '__main__':
    app.debug = False
    # app.run(host='0.0.0.0', port=4996, threaded=True, ssl_context=(("/tls/flask.crt", "/tls/flask.key")))
    app.run(host='0.0.0.0', port=4996, threaded=True)
