oc create secret generic pull-secret \
--from-file=.dockerconfigjson=/Users/jjeong/git/test/config.json \
--type=kubernetes.io/dockerconfigjson