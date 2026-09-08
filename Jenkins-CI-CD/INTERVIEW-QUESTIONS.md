# DevOps Interview QA: Jenkins & Docker CI/CD Pipeline

If you showcase this Jenkins + Docker Node.js deployment project on your resume, you can expect the following interview questions. 

---

### Q1. Can you explain the architecture of the CI/CD pipeline you built using Jenkins and Docker?
**Answer:** I built a fully automated CI/CD pipeline where code merged into GitHub triggers a remote Jenkins server via Webhooks. Jenkins pulls the source code and utilizes the "Publish over SSH" plugin to securely transfer the files to a dedicated target Docker-Host EC2 instance. On that server, Jenkins executes remote bash commands to tear down the old container, run `docker build` to create a fresh image, and finally spin up the new container using `docker run`, exposing the Node.js application to the end users.

---

### Q2. Why did you use Docker in this pipeline instead of just installing Node.js directly on the target server?
**Answer:** Docker brings environment consistency. By containerizing the app, I eliminate the "it works on my machine" problem. The `Dockerfile` ensures that the exact same Node.js version, Alpine OS footprint, and dependencies are packed with the code. If we used bare-metal Node.js, a server OS update or a conflicting global software package installed on the machine could unexpectedly break the app. 

---

### Q3. How did you ensure Jenkins could securely communicate with the remote Docker Host instance?
**Answer:** I configured the **Publish Over SSH** plugin in Jenkins. Ideally, you handle this securely in an enterprise environment by generating an SSH Key Pair, placing the public key inside the target EC2's `~/.ssh/authorized_keys`, and providing the Private Key to Jenkins' secure Credentials Manager (rather than relying on a basic password).

---

### Q4. What happens if your developer pushes bad code that causes the Node.js app to crash on initialization? How do you prevent that?
**Answer:** In the current foundational pipeline architecture, the new container would exit and downtime would occur. To prevent this in a production environment, I would add a "Test" script to run `npm test` during the Jenkins build step *before* creating the runtime image. Additionally, I would implement zero-downtime deployments using a load balancer (like AWS ALB) or an orchestrator like Kubernetes, which runs a health check on the new container before tearing down the old stable container. 

---

### Q5. If your organization was moving to a microservices architecture with 50 distinct applications, how would this Jenkins approach change? 
**Answer:** We would migrate away from manual Jenkins Freestyle jobs. I would implement **Pipeline as Code** by placing a declarative `Jenkinsfile` in every microservice's repository. Rather than building the Docker image natively on the target host via SSH, the Jenkins nodes would build the Docker Images centrally, push them to an AWS ECR (Elastic Container Registry), and then issue deployment updates to a cluster orchestrator like Amazon EKS (Kubernetes) or ECS.

---

### Q6. What is the difference between Continuous Integration and Continuous Deployment?
**Answer:** 
* **Continuous Integration (CI):** The process of automatically pulling, compiling, and testing code multiple times a day when developers merge branches. The goal is to catch bugs early.
* **Continuous Delivery/Deployment (CD):** The process of taking that tested code, building the release artifact (like a Docker image), and automatically releasing it to the Staging or Production environment seamlessly.
