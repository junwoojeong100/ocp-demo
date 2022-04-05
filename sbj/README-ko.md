# jp-fep-build-deploy

이 문서는 Tekton을 기반으로 CI 파이프라인을 구성하고, ArgoCD를 기반으로 GitOps방식의 CD를 구성하는 방법을 가이드합니다.

build, deploy 디렉토리의 README.md를 통해서 빌드/배포의 상세 내용을 확인할 수 있습니다.


# build

이 문서는 Tekton Pipeline을 생성하고, Pipeline Run을 통해 파이프라인을 실행하는 방법을 가이드합니다.

그리고 Tekton Trigger를 통해서 파이프라인을 자동화하는 방법을 가이드합니다.

1. git clone을 실행합니다. `http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git`

```
git clone http://gitlab.repo.ui-bk.com:7443/Red_Hat/jp-fep-build-deploy.git
```

2. `jp-fep-build-deploy/build`아래에서 애플리케이션 빌드를 위한 신규 디렉토리를 생성합니다.

```
cd jp-fep-build-deploy/build

mkdir <your-application-name>
```

3. `jp-fep-build-deploy/build/jp-fep-account-login` 하위 파일을 복사하여 신규 디렉토리 하위에 붙여넣습니다.

```
cp -rf jp-fep-account-login/* <your-application-name>
```

4. `pipeline.yaml`을 열어서 아래 부분을 애플리케이션에 맞게 변경합니다.
  - `metadata.name`

```  
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: pipeline-jp-fep-account-login
```

5. `pipeline-run.yaml`을 열어서 아래 부분을 애플리케이션에 맞게 변경합니다.
  - `metadata.name`
  - `spec.pipelineRef.name` 
  - `spec.params`

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

6. `trigger.yaml`을 열어서 아래 부분을 애플리케이션에 맞게 변경합니다.
  - 각 리소스의 `metadata.name`
  - TriggerBinding의 `spec.params`
  - Route의 `spec.host`, `spec.to.name`

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

7. `jp-fep-build-deploy` GitLab repository’s Settings - `Access Tokens`에 `project access token`이 있는지 확인합니다.

![Capture](/uploads/51de5fce5379133a2b3e2213bd668f0b/Capture.PNG)

8. GitLab `project access token`을 기반으로 `secret`를 생성합니다.

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

9. `pipeline` serviceaccount에 위에서 생성한 `secret`을 링크합니다.

```
oc secrets link pipeline gitlab-pat-secret-build-deploy -n <your-namespace>
```

10. Tekton 파이프라인이 생성될 네임스페이스에 아래와 같은 `Tekton 활성화` 레이블을 추가합니다. 

```
oc label namespace <your-namespace> operator.tekton.dev/enable-annotation=enabled
```

11. 위에서 변경한 아래와 같은 Kubernetes 리소스를 OCP에 반영합니다.

```
oc apply -f configmap-maven-settings.yaml -n <your-namespace>

oc apply -f pvc-source.yaml -n <your-namespace>

oc apply -f yq-gitpush-task.yaml -n <your-namespace>

oc apply -f pipeline.yaml -n <your-namespace>

oc apply -f pipeline-run.yaml -n <your-namespace>

oc apply -f trigger.yaml -n <your-namespace>
```

12. 애플리케이션의 GitLab repository에서 `webhook`을 생성합니다.

![Capture](/uploads/11260d32f6a566c381ff9b4a3be9821b/Capture.PNG)

13. Tekton Trigger의 동작을 확인하기 위해서 애플리케이션 소스를 변경하고 아래와 같이 git push를 실행합니다.

```
git add .
git commit -m "update"
git push 
```


# deploy

이 문서는 ArgoCD를 사용해서 GitOps 방식으로 Kubernetes 리소스를 OCP 클러스터에 반영하는 방법을 가이드합니다.

deploy 단계는 build 단계 진행을 전제하고 있습니다. 

build 단계를 진행하지 않았다면, build 단계의 1~2번 항목을 반드시 진행 후, 아래 가이드를 참조해 주세요.

1. `jp-fep-build-deploy/deploy` 아래에서 애플리케이션 배포를 위한 신규 디렉토리를 생성합니다.

```
cd jp-fep-build-deploy/deploy

mkdir <your-application-name>
```

2. `jp-fep-build-deploy/deploy/jp-fep-account-login` 하위 파일을 복사하여 신규 디렉토리 하위에 붙여넣습니다

```
cp -rf jp-fep-account-login/* <your-application-name>
```

3. 애플리케이션이 배포될 네임스페이스에 아래와 같은 `ArgoCD 활성화` 레이블을 추가합니다

```
oc label namespace <your-namespace> argocd.argoproj.io/managed-by=openshift-gitops
```

4. `values.yaml`을 열어서 아래 부분을 애플리케이션에 맞게 변경합니다.
  - `image.repository`
  - `image.tag`
  - `resources`
  - `ports`
  - `env`

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

5. `argocd-application.yaml`을 열어서 아래 부분을 애플리케이션에 맞게 변경합니다. 
  - `source.repoURL`
  - `source.path`
  - `source.helm.valueFiles`
  - `destination.namespace`

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

6. 변경 내용을 반영하기 위해서 `jp-fep-build-deploy` GitLab repository에 git push를 실행합니다.

7. Apply resource manifest file below to OCP

```
oc apply -f argocd-application.yaml -n <your-namespace>
```

8. ArgoCD 어드민 콘솔에 로그인합니다.
  - Username에 `admin`을, Password에 admin의 패스워드를 입력합니다.
  - `openshift-gitops` 네임스페이스에서 `openshift-gitops-cluster` secret을 찾아서 `admin.password`의 value를 확인합니다.

![Capture](/uploads/67c5124a2a7e5f90dafe2ea498a38cec/Capture.PNG)

9. ArgoCD 어드민 콘솔에서 `Sync`버튼을 클릭해서 동기화를 진행합니다.

![Capture](/uploads/34a6b58b1b09150997ec3f25ab687d38/Capture.PNG)
