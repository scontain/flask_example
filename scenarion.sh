#!/bin/bash
# deloy
helm install app ./deploy/helm
# test
helm test app
# check logs
kubectl logs app-example-test-api
# dump
# container has to be privilaged
kubectl exec -it app-example-redis-master -- python3 /dumpmemory.py 1 >& dump.log
# find some values in memory
grep -o Richmond dump.log

# native run
helm install app \ 
--set redis.image=registry.scontain.com:5050/sconecuratedimages/proximus:redis-6-native \ 
--set image=registry.scontain.com:5050/sconecuratedimages/proximus:flask-app-native \ 
./deploy/helm