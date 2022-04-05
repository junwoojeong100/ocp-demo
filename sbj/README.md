# jp-fep-build-deploy

This repository is for configuring pipelines based on Tekton and gitops based on ArgoCD.

There are two directories. One is build for CI pipeline, the other is deploy for gitops based CD.

You can check out REAME.md of each directory for the details.


# build

1. Do git clone `http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git`

```
git clone http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git
```

2. Make a directory under `jp-fep-build-deploy/build` directory for your application build

```
cd jp-fep-build-deploy/build

mkdir <your-application-name>
```

3. Copy from `jp-fep-build-deploy/build/jp-fep-account-login`

```
cp -rf jp-fep-account-login/* <your-application-name>
```

4. Edit `pipeline.yaml` according to your application
  - Change `name` to your own

```  
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: pipeline-jp-fep-account-login
```

4. Edit `pipeline-run.yaml` according to your application
  - Change `name`, `pipelineRef` and `params` to your own

```
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: pipeline-run-jp-fep-account-login
spec:
  serviceAccountName: pipeline
  pipelineRef:
    name: pipeline-jp-fep-account-login
  workspaces:
    - name: source
      persistentVolumeClaim:
        claimName: source
    - name: maven-settings
      configMap:
        name: maven-settings         
    - name: helm-chart
      persistentVolumeClaim:
        claimName: helm-chart           
  params:
    - name: deployment-name
      value: jp-fep-account-login
    - name: git-url
      value: http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-account-login.git
    - name: git-revision
      value: Red_Hat-develop-patch-02640
    - name: IMAGE
      value: image-registry.openshift-image-registry.svc:5000/jp-fep-account/jp-fep-account-login:1.1.7
    - name: helm-chart-git-url
      value: http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git
    - name: helm-chart-git-revision
      value: main      
    - name: image-tag
      value: "1.1.7"    
    - name: file-path
      value: "/workspace/output/jp-fep-build-deploy/deploy/jp-fep-account-login/values.yaml"    
```

5. Edit `trigger.yaml` according to your application
  - Change `name` and `params` to your own

```
---
apiVersion: triggers.tekton.dev/v1alpha1
kind: TriggerBinding
metadata:
  name: trigger-binding-jp-fep-account-login
spec:
  params:
  - name: git-repo-url
    value: http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-account-login.git
  - name: git-repo-name
    value: $(body.repository.name)
  - name: git-revision
    value: $(body.commits[0].id)
  - name: IMAGE
    value: image-registry.openshift-image-registry.svc:5000/jp-fep-account/jp-fep-account-login:1.1.7    
  - name: helm-chart-git-url
    value: http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git
  - name: helm-chart-git-revision
    value: "main"
  - name: file-path
    value: "/workspace/output/jp-fep-build-deploy/deploy/jp-fep-account-login/values.yaml"
  - name: image-tag
    value: "1.1.7"

---
apiVersion: triggers.tekton.dev/v1alpha1
kind: TriggerTemplate
metadata:
  name: trigger-template-jp-fep-account-login

---
apiVersion: triggers.tekton.dev/v1alpha1
kind: EventListener
metadata:
  name: eventlistener-jp-fep-account-login

---
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  annotations:
    openshift.io/host.generated: 'true'
  namespace: jp-fep-account
  labels:
    app.kubernetes.io/managed-by: EventListener
    app.kubernetes.io/part-of: Triggers
    eventlistener: eventlistener-jp-fep-account-login
spec:
  host: >-
    el-eventlistener-jp-fep-account-login-jp-fep-account.apps.uibfepdev.ui-bk.com
  to:
    kind: Service
    name: el-eventlistener-jp-fep-account-login
    weight: 100    
```

6. Make sure a `project access token` in `jp-fep-build-deploy` GitLab repository’s Settings - `Access Tokens`

![Capture](/uploads/51de5fce5379133a2b3e2213bd668f0b/Capture.PNG)

7. Create a `secret` from GitLab `project access token` above

```
oc create secret generic gitlab-pat-secret-build-deploy \
--type=kubernetes.io/basic-auth \
--from-literal=username=jjeong@redhat.com \
--from-literal=password=VWRmH3CCNRA5kULutSiq \
-n <your-namespace>

oc annotate secret gitlab-pat-secret-build-deploy \
"tekton.dev/git-0=http://gitlab.repo.ui-bk.com:7443" \
-n <your-namespace>
```

8. Link the `secret` to serviceaccount `pipeline`

```
oc secrets link pipeline gitlab-pat-secret-build-deploy -n <your-namespace>
```

9. Set namespace `tekton enabled`

```
oc label namespace <your-namespace> operator.tekton.dev/enable-annotation=enabled
```

10. Apply resource manifest files below to OCP

```
oc apply -f configmap-maven-settings.yaml -n <your-namespace>

oc apply -f pvc-source.yaml -n <your-namespace>

oc apply -f yq-gitpush-task.yaml -n <your-namespace>

oc apply -f pipeline.yaml -n <your-namespace>

oc apply -f pipeline-run.yaml -n <your-namespace>

oc apply -f trigger.yaml -n <your-namespace>
```

11. Create a `webhook` in your application's GitLab repository

![Capture](/uploads/11260d32f6a566c381ff9b4a3be9821b/Capture.PNG)

12. Do git push to your application’s GitLab repository to make sure trigger works

```
git add .
git commit -m "update"
git push 
```


# deploy

1. Make a directory under `jp-fep-build-deploy/deploy` directory for your application deploy

```
cd jp-fep-build-deploy/deploy

mkdir <your-application-name>
```

2. Copy from `jp-fep-build-deploy/deploy/jp-fep-account-login`

```
cp -rf jp-fep-account-login/* <your-application-name>
```

3. Set namespace `argocd enabled`

```
oc label namespace <your-namespace> argocd.argoproj.io/managed-by=openshift-gitops
```

4. Edit `values.yaml` according to your application
  - Change `image repository`, `tag`, `resources`, `ports` and `env` to your own

```
# Default values for app.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.
replicaCount: 1
image:
  repository: image-registry.openshift-image-registry.svc:5000/jp-fep-account/jp-fep-account-login
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "1.1.7"
imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""
serviceAccount:
  # Specifies whether a service account should be created
  create: false
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""
podAnnotations: {}
podSecurityContext: {}
# fsGroup: 2000

securityContext: {}
# capabilities:
#   drop:
#   - ALL
# readOnlyRootFilesystem: true
# runAsNonRoot: true
# runAsUser: 1000

service:
  type: ClusterIP
  port: 80
ingress:
  enabled: false
  className: ""
  annotations: {}
  # kubernetes.io/ingress.class: nginx
  # kubernetes.io/tls-acme: "true"
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: chart-example-tls
  #    hosts:
  #      - chart-example.local
resources:
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  limits:
    cpu: 1000m
    memory: 1024Mi
  requests:
    cpu: 1000m
    memory: 1024Mi
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80
nodeSelector: {}
tolerations: []
affinity: {}
ports:
  - containerPort: 8080
    name: http
    protocol: TCP
  - containerPort: 8443
    name: https
    protocol: TCP
  - containerPort: 8778
    name: jolokia
    protocol: TCP
  - containerPort: 9779
    name: jmx
    protocol: TCP
env:
  - name: JAVA_OPTIONS
    value: >-
      -Djava.net.preferIPv4Stack=true -verbose:gc -Xloggc:/tmp/gc.log -XX:+UseG1GC -XX:+DisableExplicitGC -XX:+UseStringDeduplication
  - name: LANG
    value: jp_JP.utf-8
  - name: LOGGING_LEVEL_COM_SHB
    value: DEBUG
  - name: SPRING_PROFILES_ACTIVE
    value: staging
  - name: TZ
    value: Asia/Tokyo
route:
  enabled: true

```

5. Edit `argocd-application.yaml` according to your application
  - Change `source repoURL`, `path`, `helm valueFiles` and `destination namespace` to your own

```
project: default
source:
  repoURL: 'http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git'
  path: deploy
  targetRevision: HEAD
  helm:
    valueFiles:
      - jp-fep-account-login/values.yaml
destination:
  server: 'https://kubernetes.default.svc'
  namespace: jp-fep-account
syncPolicy:
  automated: {}
```

6. Do git push `values.yaml` to `jp-fep-build-deploy` GitLab repository

7. Apply resource manifest file below to OCP

```
oc apply -f argocd-application.yaml -n <your-namespace>
```

8. Log in to ArgoCD admin console
  - Enter `admin` and `admin.password` value of `openshift-gitops-cluster` secret in `openshift-gitops` namespace
![Capture](/uploads/67c5124a2a7e5f90dafe2ea498a38cec/Capture.PNG)

9. Do sync your `ArgoCD application` in ArgoCD admin console

![Capture](/uploads/34a6b58b1b09150997ec3f25ab687d38/Capture.PNG)
