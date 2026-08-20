# Mario Project: Kubernetes YAML Guide

These files are separate from Terraform. Run them from Ubuntu after `aws eks update-kubeconfig` connects `kubectl` to the created cluster.

```bash
cd EKS-TF
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f horizontal-pod-autoscaler.yaml
kubectl apply -f network-policy.yaml
```

Apply `service-monitor.yaml` only after Prometheus Operator is installed.

## 1. `deployment.yaml`: the Mario application

A Deployment maintains a desired set of Pods. This one asks Kubernetes to run three Mario Pods.

```yaml
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mario
      version: v1
  template:
    metadata:
      labels:
        app: mario
        version: v1
```

The selector and the Pod-template labels must match exactly. The Deployment uses them to own the correct Pods; the Service later uses the same labels to find them.

### Rolling updates

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

During an image update, Kubernetes may create one extra Pod (`maxSurge: 1`) but must not make any existing requested Pod unavailable (`maxUnavailable: 0`). This aims for no downtime, provided enough node capacity exists.

### Container, ports, and image policy

```yaml
containers:
- name: mario-container
  image: sevenajay/mario:latest
  imagePullPolicy: Always
  ports:
  - name: http
    containerPort: 80
```

`containerPort` documents and names the container port; it does not expose it externally. `imagePullPolicy: Always` checks for a newer `latest` image whenever a Pod starts. For a repeatable production deployment, replace `latest` with an immutable tag or digest.

### Requests and limits

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

- `100m` is 0.1 CPU core. Requests influence where Pods can be scheduled.
- Limits cap resource use. Exceeding the memory limit can cause an OOM kill.
- HPA calculates CPU/memory utilisation relative to resource **requests**, so these requests are essential for this project's HPA.

### Probes: three different checks

| Probe | Question | Project timing |
| --- | --- | --- |
| Startup | Has the app started yet? | Every 10 sec, up to 30 failures |
| Readiness | Should the Service send traffic now? | Every 5 sec after 5 sec |
| Liveness | Is a running app stuck and needs restart? | Every 10 sec after 30 sec |

All call `GET /` on named port `http`. A failed readiness probe removes the Pod from Service endpoints; a repeated liveness failure restarts the container.

### Security context

The container drops Linux capabilities and prevents privilege escalation. `runAsUser: 1000` runs the process as that Linux UID. Note that `runAsNonRoot: false` does not enforce non-root execution; changing it to `true` is a stronger configuration only if the image supports it.

## 2. `service.yaml`: public entry point

```yaml
spec:
  type: LoadBalancer
  selector:
    app: mario
    version: v1
  ports:
  - name: http
    port: 80
    targetPort: http
```

The Service provides a stable endpoint even when Pod IP addresses change. `targetPort: http` refers to the container port named `http` in the Deployment.

The annotations request an internet-facing NLB, HTTP health checks on `/`, cross-zone balancing, and five-minute target stickiness. These annotations require AWS Load Balancer Controller. Without it, do not assume an NLB will appear.

`externalTrafficPolicy: Local` preserves the original client IP, but it sends traffic only to nodes with local ready Pods. It can create uneven traffic if Pods are not balanced across nodes.

Check the result:

```bash
kubectl get service mario-service --watch
kubectl get endpoints mario-service
kubectl describe service mario-service
```

## 3. `horizontal-pod-autoscaler.yaml`: application autoscaling

```yaml
scaleTargetRef:
  apiVersion: apps/v1
  kind: Deployment
  name: mario-deployment
minReplicas: 3
maxReplicas: 10
```

The HPA changes the replica count of `mario-deployment`; it does not create EC2 nodes.

It targets average CPU 70% and memory 80%. It needs Metrics Server to provide resource metrics:

```bash
kubectl top pods
kubectl get hpa mario-hpa
kubectl describe hpa mario-hpa
```

The scale-up rule permits fast growth; scale-down waits five minutes and reduces at most 10% per minute. This avoids repeatedly shrinking and regrowing Pods when traffic briefly changes.

## 4. `network-policy.yaml`: Pod traffic rules

The policy selects all Pods with `app: mario`, then declares both Ingress and Egress policies. Once enforced, selected Pods allow only traffic matching the listed rules.

- **Ingress**: TCP 80 from Pods in a namespace labelled `name: default` or from Pods labelled `app: mario`.
- **Egress**: DNS (TCP/UDP 53) and TCP 80/443 to the same selected destinations.

Important: Kubernetes does not enforce NetworkPolicy automatically. Your CNI must support enforcement. Also verify the `default` namespace has the label `name: default`; it often does not. Inspect before applying:

```bash
kubectl get namespace default --show-labels
```

An overly restrictive egress policy can prevent DNS resolution, image access, metrics, or AWS API communication. Apply it only after the app works without it and inspect the results.

## 5. `service-monitor.yaml`: Prometheus discovery

`ServiceMonitor` is not built into Kubernetes. It is a custom resource supplied by Prometheus Operator.

It selects Services labelled `app: mario` in `default` and asks Prometheus to scrape the Service's port named `http` every 30 seconds. The Mario game may not expose Prometheus-format metrics, so successful scraping is not guaranteed just because this YAML applies.

Check whether the custom resource exists first:

```bash
kubectl api-resources | grep -i servicemonitor
```

## Apply order and diagnostic commands

```bash
kubectl apply -f deployment.yaml
kubectl rollout status deployment/mario-deployment
kubectl apply -f service.yaml
kubectl apply -f horizontal-pod-autoscaler.yaml

kubectl get deployment,pods,service,hpa
kubectl get events --sort-by=.lastTimestamp
kubectl logs deployment/mario-deployment --tail=50
```

Apply NetworkPolicy next, test the game, and finally apply ServiceMonitor only when Prometheus Operator is present.

## Delete in cost-safe order

```bash
kubectl delete -f service.yaml
kubectl delete -f horizontal-pod-autoscaler.yaml
kubectl delete -f network-policy.yaml
kubectl delete -f service-monitor.yaml --ignore-not-found
kubectl delete -f deployment.yaml
```

Wait until the load balancer is gone, then run `terraform destroy`.
