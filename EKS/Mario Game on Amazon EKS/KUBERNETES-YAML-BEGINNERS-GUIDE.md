# ☸️ The Ultimate Beginner's Guide to Kubernetes YAML Files (Super Mario Deployment)

Welcome to the comprehensive, line-by-line guide explaining all Kubernetes YAML manifests used to run **Super Mario** on **Amazon EKS**!

This guide is designed for beginners to understand **what** every line does, **why** it is written that way, and **how** Kubernetes components interact with each other.

---

## 📍 Table of Contents
1. [What is Kubernetes and Why Do We Use YAML?](#1-what-is-kubernetes-and-why-do-we-use-yaml)
2. [The 4 Fundamental Fields of Every K8s Manifest](#2-the-4-fundamental-fields-of-every-k8s-manifest)
3. [Deep-Dive: `deployment.yaml` (Running the Game)](#3-deep-dive-deploymentyaml-running-the-game)
   - [Replicas & Label Selectors](#31-replicas--label-selectors)
   - [Rolling Update Strategy](#32-rolling-update-strategy)
   - [Container & Image Configuration](#33-container--image-configuration)
   - [Resource Requests & Limits (CPU/Memory)](#34-resource-requests--limits-cpumemory)
   - [Probes: Startup, Readiness & Liveness](#35-probes-startup-readiness--liveness)
   - [Container Security Context](#36-container-security-context)
4. [Deep-Dive: `service.yaml` (Exposing Game to the Internet)](#4-deep-dive-serviceyaml-exposing-game-to-the-internet)
   - [Service Type & Load Balancer](#41-service-type--load-balancer)
   - [AWS Load Balancer Annotations](#42-aws-load-balancer-annotations)
   - [Port Mapping (`port` vs `targetPort`)](#43-port-mapping-port-vs-targetport)
5. [Deep-Dive: `horizontal-pod-autoscaler.yaml` (Auto-Scaling)](#5-deep-dive-horizontal-pod-autoscalingyaml-auto-scaling)
   - [Scale Target & Metrics](#51-scale-target--metrics)
   - [Scale-Up & Scale-Down Behavior](#52-scale-up--scale-down-behavior)
6. [Deep-Dive: `network-policy.yaml` (Pod Firewall)](#6-deep-dive-network-policyyaml-pod-firewall)
   - [Ingress vs Egress Rules](#61-ingress-vs-egress-rules)
7. [Deep-Dive: `service-monitor.yaml` (Prometheus Metrics)](#7-deep-dive-service-monitoryaml-prometheus-metrics)

---

## 1. What is Kubernetes and Why Do We Use YAML?

### Imperative vs. Declarative
- **Imperative (Manual commands)**: `kubectl run mario --image=sevenajay/mario:latest`. If the pod dies, nobody knows what configuration was used to restart it.
- **Declarative (YAML files)**: You write a `.yaml` manifest describing your **Desired State**. You give it to Kubernetes (`kubectl apply -f file.yaml`), and Kubernetes continuously works to ensure **Actual State == Desired State**. If a server dies, Kubernetes recreates your exact pods on another healthy server automatically!

---

## 2. The 4 Fundamental Fields of Every K8s Manifest

Every single Kubernetes file starts with these 4 top-level keys:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mario-deployment
spec:
  ...
```

1. **`apiVersion`**: Tells Kubernetes which API endpoint to use to process this object.
   - Core objects like `Pod`, `Service` use `v1`.
   - `Deployment` uses `apps/v1`.
   - `HorizontalPodAutoscaler` uses `autoscaling/v2`.
   - `NetworkPolicy` uses `networking.k8s.io/v1`.
2. **`kind`**: Defines the type of resource being created (`Deployment`, `Service`, `NetworkPolicy`).
3. **`metadata`**: Contains identification data (`name`, `namespace`, `labels`, `annotations`).
4. **`spec`**: **WHY DO WE USE `spec`?** `spec` stands for **Specification**. This is the heart of Kubernetes. It specifies the **Desired State**—how many copies to run, what container image to pull, what port to open, and how much CPU/memory to allocate.

---

## 3. Deep-Dive: `deployment.yaml` (Running the Game)

A **Deployment** manages a set of identical Pods (the smallest deployable units containing your Docker containers).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mario-deployment
  namespace: default
  labels:
    app: mario
    version: v1
spec:
  replicas: 3
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: mario
      version: v1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### 3.1 Replicas & Label Selectors
- **`replicas: 3`**: Tells Kubernetes to keep **3 copies (pods)** of the Super Mario game running at all times across your EC2 worker nodes for high availability.
- **`selector.matchLabels`**: **Crucial concept!** The Deployment controller uses `matchLabels` to find and manage its Pods. The labels listed in `selector.matchLabels` MUST match the labels defined under `template.metadata.labels`.

### 3.2 Rolling Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```
- **`maxUnavailable: 0`**: Ensures that during a code update, **zero** old pods are destroyed until a new pod is fully ready.
- **`maxSurge: 1`**: Allows Kubernetes to spin up 1 temporary extra pod (3 -> 4) during an update.
- **Result**: **Zero downtime deployment!** Users playing Mario won't experience disconnected sessions while updating code.

---

### 3.3 Container & Image Configuration

```yaml
  template:
    spec:
      containers:
      - name: mario-container
        image: sevenajay/mario:latest
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
```

- **`image: sevenajay/mario:latest`**: The Docker image pulled from Docker Hub containing the HTML5 Mario game files and Web server.
- **`imagePullPolicy: Always`**: Forces Kubernetes to check Docker Hub for updated image digests every time a pod restarts.
- **`containerPort: 80`**: Exposes port 80 inside the container where Nginx/Web server serves the game.

---

### 3.4 Resource Requests & Limits (CPU/Memory)

```yaml
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

#### Why split into `requests` vs `limits`?
- **`requests` (Guaranteed minimum)**:
  - `cpu: "100m"` = 0.1 vCPU core (100 millicores).
  - `memory: "128Mi"` = 128 Megabytes of RAM.
  - Kubernetes uses `requests` to find a worker node that has at least 100m CPU and 128Mi RAM free to place the pod.
- **`limits` (Maximum ceiling)**:
  - `cpu: "500m"` = 0.5 vCPU core max. If the pod tries to consume more CPU, Kubernetes throttles CPU usage.
  - `memory: "512Mi"` = 512 Megabytes max. **What happens if memory exceeds 512Mi?** The Linux kernel kills the container with an `OOMKilled` (Out Of Memory) error to protect the underlying EC2 node!

---

### 3.5 Probes: Startup, Readiness & Liveness

```yaml
        startupProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
          failureThreshold: 30

        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3

        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
```

#### Why do we have 3 separate probes?

| Probe | Question Asked | Action taken if check fails |
| :--- | :--- | :--- |
| **Startup Probe** | "Has the web server finished booting up?" | Gives slow-starting apps extra time. Holds off readiness/liveness checks until passed. |
| **Readiness Probe** | "Is the app ready to accept web traffic?" | **Removes pod from Load Balancer target pool.** Prevents sending users to a pod that is still loading assets. |
| **Liveness Probe** | "Is the app alive or deadlocked?" | **Restarts container automatically!** If Nginx crashes or hangs, Kubernetes kills and restarts it. |

---

### 3.6 Container Security Context

```yaml
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: false
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
```
- **`allowPrivilegeEscalation: false`**: Prevents child processes from gaining root privileges via `setuid` binaries.
- **`runAsUser: 1000`**: Runs the container under a non-root Linux user account (UID 1000).
- **`capabilities.drop: ["ALL"]`**: Drops default Linux kernel privileges (like raw socket manipulation or system reboot permissions) to harden container security against exploits!

---

## 4. Deep-Dive: `service.yaml` (Exposing Game to the Internet)

Pods are ephemeral—their IP addresses change every time they restart. A **Service** provides a single stable DNS name and virtual IP to route public internet traffic to healthy pods.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mario-service
  namespace: default
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "external"
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  selector:
    app: mario
    version: v1
  ports:
  - name: http
    port: 80
    targetPort: http
    protocol: TCP
```

### 4.1 Service Type & Load Balancer
- **`type: LoadBalancer`**: Instructs EKS to automatically provision an AWS Load Balancer in your AWS account.

### 4.2 AWS Load Balancer Annotations
- **`aws-load-balancer-type: "external"`**: Triggers the **AWS Load Balancer Controller** to provision a Network Load Balancer (NLB).
- **`aws-load-balancer-scheme: "internet-facing"`**: Places the NLB in public subnets so it gets a public DNS URL accessible over the internet.

### 4.3 Port Mapping (`port` vs `targetPort`)
```
[ User Browser ] ---> ( Port 80 on Load Balancer ) ---> ( targetPort: http/80 on Mario Container )
```
- **`port: 80`**: The port exposed publicly on the AWS Load Balancer.
- **`targetPort: http`**: Routes incoming traffic from port 80 to port 80 (`name: http`) inside the Mario pod.

---

## 5. Deep-Dive: `horizontal-pod-autoscaler.yaml` (Auto-Scaling)

The **Horizontal Pod Autoscaler (HPA)** automatically increases or decreases the number of Mario pods based on CPU and Memory load.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mario-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mario-deployment
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 5.1 Scale Target & Metrics
- **`scaleTargetRef`**: Links this HPA controller directly to `mario-deployment`.
- **`minReplicas: 3` / `maxReplicas: 10`**: Establishes boundaries. It will never shrink below 3 pods or expand beyond 10 pods.
- **`averageUtilization: 70`**: If average CPU usage across pods exceeds 70% of their requested CPU (70% of 100m = 70m), HPA adds extra pods!

---

## 6. Deep-Dive: `network-policy.yaml` (Pod Firewall)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mario-network-policy
spec:
  podSelector:
    matchLabels:
      app: mario
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: default
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
```

### 6.1 Ingress vs Egress Rules
- **`Ingress` (Inbound traffic)**: Allows incoming connections only on TCP port 80 from pods within the `default` namespace.
- **`Egress` (Outbound traffic)**: Restricts outgoing connections from Mario pods to DNS (UDP/TCP port 53) and HTTP/HTTPS (ports 80/443). Blocks any rogue outbound scanning or data exfiltration attempts.

---

## 7. Deep-Dive: `service-monitor.yaml` (Prometheus Metrics)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mario-service-monitor
  labels:
    app: mario
    release: prometheus
spec:
  selector:
    matchLabels:
      app: mario
  endpoints:
  - port: http
    path: /
    interval: 30s
```

### Why is this optional?
- **`apiVersion: monitoring.coreos.com/v1`**: Requires the **Prometheus Operator / kube-prometheus-stack** to be installed in your cluster first.
- **`interval: 30s`**: Asks Prometheus to scrape HTTP metrics from the Mario service every 30 seconds.
- **Note**: If Prometheus Operator is not installed, skip applying this file.

---

## 💡 Summary of kubectl Deployment Order

```bash
# 1. Connect kubectl to EKS
aws eks update-kubeconfig --name EKS_CLOUD --region ap-south-1

# 2. Deploy Application
kubectl apply -f deployment.yaml

# 3. Expose via Load Balancer
kubectl apply -f service.yaml

# 4. Enable Auto-scaling
kubectl apply -f horizontal-pod-autoscaler.yaml

# 5. Enable Security Policy
kubectl apply -f network-policy.yaml

# 6. Verify Status
kubectl get deployments,pods,services,hpa
```
