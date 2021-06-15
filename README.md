# A Confidential Flask-Based Application

We **demonstrate** with this example multiple features of the SCONE platform:

- we show that we can execute **unmodified Python** programs inside of SGX enclaves
- we show how to **encrypt the Python program** to protect the **confidentiality** and **integrity** of the Python code
- how to **implicitly attest other services** with the help of TLS, i.e., to ensure that one talks to services that satisfy their security policy.
  - we demonstrate how Redis, an in-memory data structure store, and the Python flask **attest each other** via **TLS** without needing to change Redis.
- we show how to **generate TLS certificates** with the help of a policy:
  - a SCONE security policy describes how to attest applications and services (i.e., describe the code, the filesystem state, the environment, the node on which to execute, and secrets).
  - a SCONE policy can generate secrets and in particular, key-pairs and TLS certificates.
- we show how to execute this example
  - on a local computer with the help of docker compose
  - on a generic Kubernetes cluster, and
  - in particular, on **Azure Kubernetes Service** (AKS).

!!! note "Next Step"
    In the second version of this example, we **simplifies the
    workflow** in the sense that we use a generic script to transform an existing Python application into a confidential application.

## Service

We implement a simple Flask-based service. The Python [code](https://github.com/scontain/flask_example/blob/master/rest_api.py) implements a REST API:

- to store patient records (i.e., POST to resource `/patient/<string:patient_id>`)
- to retrieve patient records (i.e., GET of resource `/patient/<string:patient_id>`)
- to retrieve some *score* for a patient (i.e., GET of ressource `'/score/<string:patient_id>`)

The Python code is executed inside of an enclave to ensure that even users with root access cannot read the patient data.

## TLS Certificates

The service uses a Redis instance to store the resources. The communication between 1) the Flask-based service and its clients and  2) Redis and the application is encrypted with the help of TLS. To do so, we need to provision the application and Redis with multiple keys and certificates:

- Redis client certificate
- Redis server certificate
- Flask server certificate

Redis and the Flask-based service, require that the private keys and certificates are stored in the filesystem. We generate and provision these TLS-related files with the help of a [SCONE policy](https://sconedocs.github.io/CAS_session_lang_0_3/). 

To do so, we generate **secrets** related to the Flask-based service. We specify in the [flask policy](https://github.com/scontain/flask_example/blob/master/flask-template.yml) that

- a private key (`api_ca_key`) for a new certificate authority (CA) is generated
- a certificate (`api_ca_cert`) for a certification authority is generated
  - using the private key (i.e., `api_ca_key`), and
  - making this certificate available to everybody (see `export_public: true`)
- we generate a private key for the certificate used by the REST API (i.e., `flask_key`)
- we generate a certificate (`flask`) with the help of CA `api_ca_cert` and assign it a dns name `api`.

The SCONE policy is based on Yaml and the [flask policy](https://github.com/scontain/flask_example/blob/master/flask-template.yml) contains the following section to define these secrets:

```YML
secrets:
    - name: api_ca_key
      kind: private-key
    - name: api_ca_cert
      kind: x509-ca
      export_public: true
      private_key: api_ca_key
    - name: flask_key
      kind: private-key
    - name: flask
      kind: x509
      private_key: flask_key
      issuer: api_ca_cert
      dns:
        - api
```

The private keys and certificates are expected at certain locations in the file system. SCONE permits to map these secrets into the filesystem of the Flask-based service: these files are only  visible to the service inside of an SGX enclave after a successful attestation (see below) and in particular, not visible on the outside i.e., in the filesystem of the container.

To map the private keys and certificates into the filesystem of a service, we specify in the policy which secrets are visible to a service at which path. In the [flask policy](https://github.com/scontain/flask_example/blob/master/flask-template.yml) this is done as follows:

```YML
images:
   - name: flask_restapi_image
     injection_files:
        - path: /tls/flask.crt
          content: $$SCONE::flask.crt$$
        - path: /tls/flask.key
          content: $$SCONE::flask.key$$
```

And in the Python program, one can just access these files as normal files. One can create a SSL context (see [code](https://github.com/scontain/flask_example/blob/master/rest_api.py)):

```Python
    app.run(host='0.0.0.0', port=4996, threaded=True, ssl_context=(("/tls/flask.crt", "/tls/flask.key")))
```

We do not show how to enforce client authentication of the REST API but we show how to do this for Redis.

## TLS-based Mutual Attestation

The communication between the Flask-based service $S$ and Redis instance $R$ is encrypted via TLS. Actually, we make sure that the service $S$ and instance $R$ **attest** each other. Attestation means that $S$ ensures that $R$ satisfies all requirements specified in its security policy and $R$ ensures that $S$ satisfies all the requirements of $S$'s policy. Of course, this should be done without changing the code of neither $S$ nor $R$. In case, $S$ and $R$ using TLS with client authentication, this is straightforward to enforce. If this is not the case, please contact us for an alternative.

The approach is as follows. Redis defines a [policy](https://github.com/scontain/flask_example/blob/master/redis-template.yml) in which it defines a certification authority (`redis_ca_cert`) and defines both a Redis certificate (`redis_ca_cert`) as well as a Redis client certificate (`redis_client_cert`). The client certificate and the private key (`redis_client_key`), are exported to the policy of the Flask service $S$. The policy for this looks like this:

```yml
secrets:
  - name: redis_key
    kind: private-key
  - name: redis # automatically generate Redis server certificate
    kind: x509
    private_key: redis_key
    issuer: redis_ca_cert
    dns:
     - redis
  - name: redis_client_key
    kind: private-key
    export:
    - session: $FLASK_SESSION
  - name: redis_client_cert # automatically generate client certificate
    kind: x509
    issuer: redis_ca_cert
    private_key: redis_client_key
    export:
    - session: $FLASK_SESSION # export client cert/key to client session
  - name: redis_ca_key
    kind: private-key
  - name: redis_ca_cert # export session CA certificate as Redis CA certificate
    kind: x509-ca
    private_key: redis_ca_key
    export:
    - session: $FLASK_SESSION # export the session CA certificate to client session
```

Note that `$FLASK_SESSION` is replaced by the unique name of the policy of $S$. The security
policies are in this example on the same SCONE CAS (Configuration and Attestation Service). In more complex scenarios, the policies could also be stored on separate SCONE CAS instances operated by different entities.

The flask service can import the Redis CA certificate, client certificate and private key as follows:

```yml
secrets:
    - name: redis_client_key
      import:
        session: $REDIS_SESSION
        secret: redis_client_key
    - name: redis_client_cert
      import:
        session: $REDIS_SESSION
        secret: redis_client_cert
    - name: redis_ca_cert
      import:
        session: $REDIS_SESSION
        secret: redis_ca_cert
```

These secrets are made available to the Flask-based service in the filesystem (i.e., files `/tls/redis-ca.crt`, `/tls/client.crt` and `/tls/client.key`) via the following entries in its security policy:

```yml
images:
   - name: flask_restapi_image
     injection_files:
        - path: /tls/redis-ca.crt
          content: $$SCONE::redis_ca_cert.chain$$
        - path: /tls/client.crt
          content: $$SCONE::redis_client_cert.crt$$
        - path: /tls/client.key
          content: $$SCONE::redis_client_cert.key$$
```

## Code

The source code is open source and available on github:

```bash
git clone https://github.com/scontain/flask_example.git
cd flask_example
```

## Run Service On Local Computer

You can use `docker-compose` to run this example on your local SGX-enabled computer as follows.
You first generate an encrypted image using script `create_image.sh`. This generates some environment variables that stored in file `myend` and are loaded via `source myenv`. The service and Redis are started with `docker-compose up`.

```bash
./create_image.sh
source myenv
docker-compose up
```

Please note that some images are not publicly available. Follow the instructions outlined in the [official documentation](https://sconedocs.github.io/SCONE_Curated_Images/#login-in) to get access to those images. If you already have access to the gitlab instance of scone available under gitlab.scontain.com, the commands will work right away.

We use a public instance of SCONE CAS.

### Testing the service

Retrieve the API certificate from CAS:

```bash
source myenv
curl -k -X GET "https://${SCONE_CAS_ADDR-cas}:8081/v1/values/session=$FLASK_SESSION" | jq -r .values.api_ca_cert.value > cacert.pem
```

Since the API certificates are issued to the host name "api", we have to use it. You can rely on cURL's --resolve option to point to the actual address (you can also edit your /etc/hosts file).

```bash
export URL=https://api:4996
```

```bash
curl --cacert cacert.pem -X POST ${URL}/patient/patient_3 -d "fname=Jane&lname=Doe&address='123 Main Street'&city=Richmond&state=Washington&ssn=123-223-2345&email=nr@aaa.com&dob=01/01/2010&contactphone=123-234-3456&drugallergies='Sulpha, Penicillin, Tree Nut'&preexistingconditions='diabetes, hypertension, asthma'&dateadmitted=01/05/2010&insurancedetails='Primera Blue Cross'" --resolve api:4996:127.0.0.1
curl --cacert cacert.pem -X GET ${URL}/patient/patient_3 --resolve api:4996:127.0.0.1
curl --cacert cacert.pem -X GET ${URL}/score/patient_3 --resolve api:4996:127.0.0.1
```

The output might look as follows:

```txt
$ curl --cacert cacert.pem -X POST https://localhost:4996/patient/patient_3 -d "fname=Jane&lname=Doe&address='123 Main Street'&city=Richmond&state=Washington&ssn=123-223-2345&email=nr@aaa.com&dob=01/01/2010&contactphone=123-234-3456&drugallergies='Sulpha, Penicillin, Tree Nut'&preexistingconditions='diabetes, hypertension, asthma'&dateadmitted=01/05/2010&insurancedetails='Primera Blue Cross'" --resolve api:4996:127.0.0.1
{"address":"'123 Main Street'","city":"Richmond","contactphone":"123-234-3456","dateadmitted":"01/05/2010","dob":"01/01/2010","drugallergies":"'Sulpha, Penicillin, Tree Nut'","email":"nr@aaa.com","fname":"Jane","id":"patient_3","insurancedetails":"'Primera Blue Cross'","lname":"Doe","preexistingconditions":"'diabetes, hypertension, asthma'","score":0.1168424489618366,"ssn":"123-223-2345","state":"Washington"}
$ curl --cacert cacert.pem -X GET localhost:4996/patient/patient_3 --resolve api:4996:127.0.0.1
{"address":"'123 Main Street'","city":"Richmond","contactphone":"123-234-3456","dateadmitted":"01/05/2010","dob":"01/01/2010","drugallergies":"'Sulpha, Penicillin, Tree Nut'","email":"nr@aaa.com","fname":"Jane","id":"patient_3","insurancedetails":"'Primera Blue Cross'","lname":"Doe","preexistingconditions":"'diabetes, hypertension, asthma'","score":0.1168424489618366,"ssn":"123-223-2345","state":"Washington"}
$ curl --cacert cacert.pem -X GET localhost:4996/score/patient_3 --resolve api:4996:127.0.0.1
{"id":"patient_3","score":0.2781606437899131}
```

## Execution on a Kubernetes Cluster and AKS

You can run this example on a Kubernetes cluster or Azure Kubernetes Service (AKS).

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
export IMAGE=sconecuratedimages/application:v0.4 # please change to an image that you can push
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
   --set scone.redis_session=$REDIS_SESSION/redis \
   --set service.type=LoadBalancer
```

**NOTE**: Setting `service.type=LoadBalancer` will allow the application to get traffic from the internet (through a managed LoadBalancer).

### Test the application

After all resources are `Running`, you can test the API via Helm:

```bash
helm test api-v1
```

Helm will run a pod with a couple of pre-set queries to check if the API is working properly.

### Access the application

If the application is exposed to the world through a service of type LoadBalancer, you can retrieve its CA certificate from CAS:

```bash
source myenv
curl -k -X GET "https://${SCONE_CAS_ADDR-cas}:8081/v1/values/session=$FLASK_SESSION" | jq -r .values.api_ca_cert.value > cacert.pem
```

Retrieve the service public IP address:

```bash
export SERVICE_IP=$(kubectl get svc --namespace default api-v1-example --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
```

Since the API certificates are issued to the host name "api", we have to use it. You can rely on cURL's --resolve option to point to the actual address (you can also edit your /etc/hosts file).

```bash
export URL=https://api
```

Now you can perform queries such as:

```bash
curl --cacert cacert.pem -X POST ${URL}/patient/patient_3 -d "fname=Jane&lname=Doe&address='123 Main Street'&city=Richmond&state=Washington&ssn=123-223-2345&email=nr@aaa.com&dob=01/01/2010&contactphone=123-234-3456&drugallergies='Sulpha, Penicillin, Tree Nut'&preexistingconditions='diabetes, hypertension, asthma'&dateadmitted=01/05/2010&insurancedetails='Primera Blue Cross'" --resolve api:443:${SERVICE_IP}
```

### Clean up

```bash
helm delete cas
helm delete las
helm delete sgxdevplugin
helm delete api-v1
kubectl delete pod api-v1-example-test-api
```

