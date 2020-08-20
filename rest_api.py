from flask import Flask, request, jsonify, Response
from flask_restful import Resource, Api
import random

app = Flask(__name__)
api = Api(app)

patients={}

class Patient(Resource):
    def get(self, patient_id):
        if patient_id in patients:
            return jsonify(patients[patient_id])
        return Response({"error": "unknown patient_id"}, status=404, mimetype='application/json')

    def post(self, patient_id):
        if patient_id in patients:
            return Response({"error": "already exists"}, status=403, mimetype='application/json')
        else:
            patients[patient_id] = {"id": patient_id, "address": request.form['address'], "score": random.random()}
            return jsonify(patients[patient_id])

class Score(Resource):
    def get(self, patient_id):
        if patient_id in patients:
            score = patients[patient_id]["score"]
            return jsonify({"id": patient_id, "score": score})
        return Response({"error": "unknown patient"}, status=404, mimetype='application/json')


api.add_resource(Patient, '/patient/<string:patient_id>')
api.add_resource(Score, '/score/<string:patient_id>')

if __name__ == '__main__':
    app.debug = True
    app.run(host='0.0.0.0', port=4996)