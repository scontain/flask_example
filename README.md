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
export URL=localhost:4996
```

```bash
curl -X POST  -d "address=patient3 address"  ${URL}/patient/patient_3
curl -X GET  ${URL}/patient/patient_3 
curl -X GET  ${URL}/score/patient_3
```

The output might look as follows:

```txt
$ curl -X POST  -d "address=patient3 address"  localhost:4996/patient/patient_3
{"address":"patient3 address","score":0.2781606437899131}
$ curl -X GET  localhost:4996/patient/patient_3 
{"address":"patient3 address","score":0.2781606437899131}
$ curl -X GET  localhost:4996/score/patient_3 
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

### Run the application

Start by creating a Docker image and setting its name. Remember to specify a repository to which you are allowed to push:

```bash
export IMAGE=sconecuratedimages/application:v0.4
./create-image.sh
source myenv
docker push $IMAGE
```

Use the Helm chart in `deploy/helm` to deploy the application to a Kubernetes cluster.

```bash
helm install api-v1 deploy/helm \
   --set image=$IMAGE \
   --set scone.cas=$SCONE_CAS_ADDR \
   --set scone.flask_session=$FLASK_SESSION \
   --set scone.redis_session=$REDIS_SESSION
```

After all resources are `Running`, you can test the API:

```bash
helm test api-v1
```

This will spawn a pod and make a few queries to the API.

### Clean up

```bash
helm delete cas
helm delete las
helm delete api-v1
kubectl delete pod api-v1-record-api-test-api
```

