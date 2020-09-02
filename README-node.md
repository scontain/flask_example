# A simple node JS example

The application `app.js` requires 
```bash
export CAS_ADDR="4-2-1.scone-cas.cf" # we use a public SCONE CAS to store the session policies
export IMAGE="sconecuratedimages/apps:node-10-alpine-scone4.2"
unset NODE_SESSION
export NODE_SESSION=$(./upload_session --template=nodejs-template.yml --session=nodejs-session.yml  --image=$IMAGE --cas=$CAS_ADDR)
export DEVICE=$(./determine_sgx_device) # determine the SGX device of the local computer
```

and then run locally by executing

```bash
docker-compose --file docker-compose-node.yml up
```
