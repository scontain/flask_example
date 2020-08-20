from flask import Flask, request, jsonify, Response
from flask_restful import Resource, Api
import json
import os
import random
import redis

app = Flask(__name__)
api = Api(app)

# Setup redis instance.
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = os.environ.get("REDIS_PORT", 6379)
db = redis.StrictRedis(host=REDIS_HOST, port=REDIS_PORT)


class Patient(Resource):
    def get(self, patient_id):
        patient_data = db.get(patient_id)
        if patient_data is not None:
            return jsonify(json.loads(patient_data.decode('utf-8')))
        return Response({"error": "unknown patient_id"}, status=404, mimetype='application/json')

    def post(self, patient_id):
        if db.exists(patient_id):
            return Response({"error": "already exists"}, status=403, mimetype='application/json')
        else:
            # convert patient data to binary.
            patient_data = json.dumps({"address": request.form['address'], "score": random.random()}).encode('utf-8')
            try:
                db.set(patient_id, patient_data)
            except Exception as e:
                print(e)
                return Response({"error": "internal server error"}, status=500, mimetype='application/json')
            return jsonify(json.loads(patient_data.decode('utf-8')))

class Score(Resource):
    def get(self, patient_id):
        patient_data = db.get(patient_id)
        if patient_data is not None:
            score = json.loads(patient_data.decode('utf-8'))["score"]
            return jsonify({"id": patient_id, "score": score})
        return Response({"error": "unknown patient"}, status=404, mimetype='application/json')


api.add_resource(Patient, '/patient/<string:patient_id>')
api.add_resource(Score, '/score/<string:patient_id>')

if __name__ == '__main__':
    app.debug = True
    app.run(host='0.0.0.0', port=4996)
