# How the Kubernetes YAML Works

The YAML files in this project are instructions sent to the Kubernetes API using `kubectl apply -f <file>`. They are not Terraform. Kubernetes stores the requested state and continuously works to make the real cluster match it.

Create the files manually from the examples in `README.md`; this guide explains every important line.

## The general YAML pattern

Most Kubernetes resource definitions follow this shape:

```yaml
apiVersion: ...  # Which Kubernetes API understands this object?
kind: ...        # What type of object are we creating?
metadata:        # Name, namespace, labels, annotations
spec:            # The desired state for this object
```

`spec` means **desired state**. You say “run two game Pods”; Kubernetes decides which worker node runs each Pod and replaces a Pod if it fails.

## 1. Namespace YAML

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: game-2048
```

| Line / field | Meaning |
| --- | --- |
| `apiVersion: v1` | Namespace is a core Kubernetes object, so it uses the core `v1` API. |
| `kind: Namespace` | Creates a logical isolation boundary. |
| `metadata.name` | The namespace identifier. It must be unique in the cluster. |

Namespaces let multiple applications share one cluster without mixing their names. After creating `game-2048`, a Service called `game-2048` in this namespace is different from a Service with the same name in `default`.

Apply it first:

```bash
kubectl apply -f namespace.yaml
kubectl get namespaces
```

## 2. Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: game-2048
  namespace: game-2048
spec:
  replicas: 2
  selector:
    matchLabels:
      app: game-2048
  template:
    metadata:
      labels:
        app: game-2048
    spec:
      containers:
        - name: game-2048
          image: blackicebird/2048:latest
          ports:
            - containerPort: 80
```

### Deployment identity

| Field | Meaning |
| --- | --- |
| `apiVersion: apps/v1` | Deployments belong to the `apps` API group. |
| `kind: Deployment` | A controller that manages a set of identical Pods. |
| `metadata.name` | The Deployment name: `game-2048`. |
| `metadata.namespace` | Place this Deployment inside `game-2048`; the Namespace must already exist. |
| `replicas: 2` | Kubernetes should keep two matching Pods running. |

### The most important relationship: selector and labels

```yaml
selector:
  matchLabels:
    app: game-2048
template:
  metadata:
    labels:
      app: game-2048
```

The Deployment selector says: “I manage Pods labelled `app: game-2048`.” The template then creates Pods with that exact label. These values must match.

The same label is also used later by the Service. It is the link that lets the Service send traffic to the correct Pods.

### Pod template and container

| Field | Meaning |
| --- | --- |
| `template` | Blueprint for every Pod created by the Deployment. |
| `template.spec.containers` | List of containers inside each Pod. This project has one. |
| `name: game-2048` | Container name used in logs and troubleshooting commands. |
| `image: blackicebird/2048:latest` | Image that the node downloads and runs. `latest` is simple for learning, but production should use a fixed version or image digest. |
| `containerPort: 80` | Documents that the application listens on port 80. It does not publish the app to the internet by itself. |

Apply and observe the controller's work:

```bash
kubectl apply -f 2048-deployment.yaml
kubectl get deployment game-2048 -n game-2048
kubectl get pods -n game-2048
```

Behind the scenes, the Deployment creates a ReplicaSet, and the ReplicaSet creates two Pods. If you delete one Pod, the ReplicaSet notices only one remains and creates a replacement.

## 3. Service YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: game-2048
  namespace: game-2048
spec:
  type: LoadBalancer
  selector:
    app: game-2048
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

### What each Service field does

| Field | Meaning |
| --- | --- |
| `kind: Service` | Creates a stable network endpoint in front of a changing set of Pods. |
| `type: LoadBalancer` | Asks the AWS integration to provision an external AWS load balancer. This is the part that adds a public hostname and recurring cost. |
| `selector.app` | Finds Pods labelled `app: game-2048`. It must match the Deployment Pod-template label. |
| `protocol: TCP` | HTTP runs over TCP. |
| `port: 80` | The Service and external load balancer listen on port 80. |
| `targetPort: 80` | Forward traffic to port 80 inside the selected Pod. |

Traffic flow:

```text
Browser → AWS Load Balancer:80 → Service:80 → selected Pod:80 → 2048 container
```

Apply it and wait:

```bash
kubectl apply -f 2048-service.yaml
kubectl get service game-2048 -n game-2048 --watch
```

AWS may take several minutes to create the load balancer. When `EXTERNAL-IP` shows a hostname, open it in your browser.

## Why order matters

1. Create the Namespace — otherwise the Deployment and Service cannot be created in it.
2. Create the Deployment — it creates the Pods.
3. Create the Service — it finds those Pods through the label selector and exposes them.

## How to inspect the YAML after applying

```bash
# Show the API objects actually stored by Kubernetes.
kubectl get deployment,replicaset,pods,service -n game-2048

# Confirm that the Service found Pod endpoints.
kubectl get endpoints game-2048 -n game-2048

# Detailed events and configuration when something is wrong.
kubectl describe deployment game-2048 -n game-2048
kubectl describe service game-2048 -n game-2048
```

If the endpoint list is empty, first compare the Service selector with the Pod labels:

```bash
kubectl get pods -n game-2048 --show-labels
kubectl get service game-2048 -n game-2048 -o yaml
```

## Safe changes to practice

### Scale the app

```bash
kubectl scale deployment game-2048 -n game-2048 --replicas=3
```

This changes the desired number of Pods to three. Reapply your original Deployment YAML to return to two.

### Change the container image

Edit the `image:` value in the Deployment YAML, then apply it again:

```bash
kubectl apply -f 2048-deployment.yaml
kubectl rollout status deployment/game-2048 -n game-2048
```

Kubernetes performs a rolling update: it creates Pods with the new image and removes old Pods gradually, keeping the Service pointed at ready Pods.

## Delete in the right order

Delete the Service first so AWS removes the billable load balancer, then the Deployment and Namespace:

```bash
kubectl delete -f 2048-service.yaml
kubectl delete -f 2048-deployment.yaml
kubectl delete -f namespace.yaml
```

Deleting the Namespace also deletes everything still inside it, but explicitly deleting the Service first makes the cost-sensitive resource clear.
