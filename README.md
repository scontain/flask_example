# A simple flask example executed inside of an SGX enclave

## Setup

```bash
git clone https://github.com/scontain/flask_example.git
cd flask_example
```


## Run Service using docker-compose

```bash
./create_image.sh
source myenv
docker-compose up
```

### Testing the service

```bash
export URL=https://localhost:4996
```

```bash
curl -k -X POST ${URL}/patient/patient_3 -d "fname=Jane&lname=Doe&address='123 Main Street'&city=Richmond&state=Washington&ssn=123-223-2345&email=nr@aaa.com&dob=01/01/2010&contactphone=123-234-3456&drugallergies='Sulpha, Penicillin, Tree Nut'&preexistingconditions='diabetes, hypertension, asthma'&dateadmitted=01/05/2010&insurancedetails='Primera Blue Cross'"
curl -k -X GET  ${URL}/patient/patient_3 
curl -k -X GET  ${URL}/score/patient_3
```

The output might look as follows:

```txt
$ curl -k -X POST https://localhost:4996/patient/patient_3 -d "fname=Jane&lname=Doe&address='123 Main Street'&city=Richmond&state=Washington&ssn=123-223-2345&email=nr@aaa.com&dob=01/01/2010&contactphone=123-234-3456&drugallergies='Sulpha, Penicillin, Tree Nut'&preexistingconditions='diabetes, hypertension, asthma'&dateadmitted=01/05/2010&insurancedetails='Primera Blue Cross'"
{"address":"'123 Main Street'","city":"Richmond","contactphone":"123-234-3456","dateadmitted":"01/05/2010","dob":"01/01/2010","drugallergies":"'Sulpha, Penicillin, Tree Nut'","email":"nr@aaa.com","fname":"Jane","id":"patient_3","insurancedetails":"'Primera Blue Cross'","lname":"Doe","preexistingconditions":"'diabetes, hypertension, asthma'","score":0.1168424489618366,"ssn":"123-223-2345","state":"Washington"}
$ curl -k -X GET  localhost:4996/patient/patient_3 
{"address":"'123 Main Street'","city":"Richmond","contactphone":"123-234-3456","dateadmitted":"01/05/2010","dob":"01/01/2010","drugallergies":"'Sulpha, Penicillin, Tree Nut'","email":"nr@aaa.com","fname":"Jane","id":"patient_3","insurancedetails":"'Primera Blue Cross'","lname":"Doe","preexistingconditions":"'diabetes, hypertension, asthma'","score":0.1168424489618366,"ssn":"123-223-2345","state":"Washington"}
$ curl -k -X GET  localhost:4996/score/patient_3 
{"id":"patient_3","score":0.2781606437899131}
```

## Execution on a Kubernetes Cluster

### Install SCONE services

Get access to `SconeApps` (see <https://sconedocs.github.io/helm/>):

```bash
helm repo add sconeapps https://${GH_TOKEN}@raw.githubusercontent.com/scontain/sconeapps/master/
helm repo update
```

Give SconeApps access to the private docker images (see <https://sconedocs.github.io/helm/>)

```bash
export DOCKER_HUB_USERNAME=...
export DOCKER_HUB_ACCESS_TOKEN=...
export DOCKER_HUB_EMAIL=...

kubectl create secret docker-registry sconeapps --docker-server=index.docker.io/v1/ --docker-username=$DOCKER_HUB_USERNAME --docker-password=$DOCKER_HUB_ACCESS_TOKEN --docker-email=$DOCKER_HUB_EMAIL
```

Start LAS and CAS service:

```bash
helm install las sconeapps/las --set service.hostPort=true
helm install cas sconeapps/cas
```

Install the SGX device plugin for Kubernetes:

```bash
helm install sgxdevplugin sconeapps/sgxdevplugin
```

### Run the application

Start by creating a Docker image and setting its name. Remember to specify a repository to which you are allowed to push:

```bash
export IMAGE=sconecuratedimages/application:v0.4
./create_image.sh
source myenv
docker push $IMAGE
```

Use the Helm chart in `deploy/helm` to deploy the application to a Kubernetes cluster.

```bash
helm install api-v1 deploy/helm \
   --set image=$IMAGE \
   --set scone.cas=$SCONE_CAS_ADDR \
   --set scone.flask_session=$FLASK_SESSION/flask_restapi \
   --set scone.redis_session=$REDIS_SESSION/redis
```

If you want your service to get traffic from the internet, add `--set service.type=LoadBalancer` to the line above. The external IP address will be visible when you `kubectl get services`.

After all resources are `Running`, you can test the API:

```bash
helm test api-v1
```

This will spawn a pod and make a few queries to the API.

### Clean up

```bash
helm delete cas
helm delete las
helm delete sgxdevplugin
helm delete api-v1
kubectl delete pod api-v1-example-test-api
```

