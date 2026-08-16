# Jenkins: Interview and Practical Notes

This guide explains the examples in this repository and gives you a safe order for learning Jenkins. The aim is not to memorise Jenkinsfile syntax: it is to be able to explain a pipeline, create one, and troubleshoot it.

## 1. Jenkins in one sentence

Jenkins is an automation server that receives a trigger, coordinates a sequence of steps, runs those steps on an appropriate machine or container, and records the result, logs, and artifacts.

It is usually used for CI (build, test, scan, package, publish) and can participate in CD. In a GitOps setup, Jenkins normally updates the deployment configuration in Git while Argo CD applies that desired state to Kubernetes.

## 2. Core architecture

```text
Developer push / webhook / schedule / manual click
                    |
                    v
        Jenkins controller (UI, queue, scheduling)
                    |
                    v
          agent selected by label or Docker image
                    |
                    v
 checkout -> test -> build -> scan -> image -> publish -> deploy/update Git
```

| Term | Meaning | Interview-ready explanation |
| --- | --- | --- |
| Controller | Jenkins server that schedules builds and stores job configuration, logs, and credentials metadata. | It should coordinate work; resource-heavy builds should run on agents. |
| Agent | Worker machine, VM, Kubernetes pod, or container that executes steps. | Agents let us scale, isolate dependencies, and choose the correct OS/toolchain. |
| Executor | A slot on an agent that can run one build at a time. | Two executors allow two concurrent builds, subject to resource limits. |
| Workspace | Per-job directory on an agent where source code is checked out and commands run. | Do not assume files remain when later stages use a different agent. |
| Node/label | A node is a Jenkins machine; a label selects suitable nodes. | Example: `agent { label 'linux-docker' }`. |
| Plugin | Extension that adds integrations or Pipeline steps. | Keep plugins minimal and updated because they are part of Jenkins's attack surface. |
| `JENKINS_HOME` | Persistent Jenkins data: job config, build metadata, plugins, and credentials. | Back it up consistently; it is more important than the controller VM itself. |

## 3. How one pipeline actually runs

1. A trigger creates a build and adds it to the Jenkins queue.
2. The controller finds an available agent/executor that satisfies the job or stage `agent` requirement.
3. Jenkins allocates a workspace and normally checks out the repository.
4. Each stage runs its declared steps. A non-zero shell exit code normally fails the stage and build.
5. `post` actions run according to the result, for example publishing test reports or deleting temporary files.
6. Jenkins saves the console log, stage result, artifacts, and build number.

The key rule is: **the controller orchestrates; the agent executes.**

## 4. Pipeline as Code

Store a `Jenkinsfile` with the application source and configure the job as **Pipeline script from SCM**. This is Pipeline as Code.

Benefits: code review, version history, reproducible pipeline changes, branch-specific pipelines, and no important build logic hidden in the Jenkins UI.

For a first experiment, pasting a script into the UI is fine. For real work, use SCM and preferably a Multibranch Pipeline, which discovers branches and pull requests automatically.

## 5. Declarative Pipeline syntax

The repository uses Declarative Pipeline. Its common structure is:

```groovy
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    IMAGE_REPOSITORY = 'your-docker-user/your-app'
  }

  stages {
    stage('Test') {
      steps {
        sh 'npm ci'
        sh 'npm test'
      }
    }
  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'reports/*.xml'
      cleanWs()
    }
  }
}
```

Know these blocks:

- `agent`: where work runs (`any`, `none`, a label, Docker, or Kubernetes).
- `stages` / `stage`: visible logical units of work.
- `steps`: commands and Jenkins steps inside a stage.
- `environment`: non-secret environment variables. Credentials should be injected only where needed.
- `when`: conditionally run a stage, e.g. only on `main`.
- `parameters`: inputs chosen before a build.
- `options`: timeouts, build retention, timestamps, concurrency controls.
- `post`: actions after the pipeline or stage (`always`, `success`, `failure`, `cleanup`).

`sh` runs a shell command on Linux/macOS agents; use `bat` or `powershell` on Windows agents.

## 6. Repository examples, explained

### `my-first-pipeline/Jenkinsfile`

```groovy
agent { docker { image 'node:16-alpine' } }
```

Jenkins starts a temporary Node container and runs `node --version` inside it. This verifies Docker-based execution, not an application build. Use a maintained image tag such as `node:22-alpine` for new work.

### `multi-stage-multi-agent/Jenkinsfile`

`agent none` at top level means no single agent is reserved for the whole pipeline. The Maven stage gets a Java/Maven container and the Node stage gets a Node container. This is valuable for polyglot applications and prevents tool-version conflicts.

Important consequence: these containers have separate workspaces. If one stage creates a file needed by another, use the same workspace deliberately or transfer it with `stash`/`unstash` (small files), an artifact repository, or external storage.

### `python-jenkins-argocd-k8s/Jenkinsfile`

It demonstrates this GitOps flow:

```text
application Git -> Docker build -> container registry
                -> update image tag in manifest Git -> Argo CD -> Kubernetes
```

Do **not** copy its credential ID, Git URLs, Docker image name, or the hard-coded `sed` replacement. They belong to the original author. In your version, use a dedicated GitOps repository, a stable image marker or Helm values file, and a credential ID that you create in Jenkins.

### Java/Maven/Sonar example

The advanced pipeline adds Maven packaging, SonarQube analysis, a Docker image push, and a manifest update. It mounts `/var/run/docker.sock` in its Docker agent. That permits the container to control the host Docker daemon and is powerful but high-risk; use isolated, short-lived agents and restrict who can modify the Jenkinsfile.

### Shared library

`vars/helloWorld.groovy` defines a global step named `helloWorld`, so a Jenkinsfile can call `helloWorld()`. Shared libraries centralize repeated pipeline logic. Version them (for example `@Library('company-ci@v1') _`) and keep application-specific decisions in the Jenkinsfile.

## 7. Credentials and security

Never put tokens, passwords, private keys, or registry logins in a Jenkinsfile, Git repository, shell history, or echo statement.

Create credentials in **Manage Jenkins -> Credentials** and scope them to the smallest appropriate folder/job. Typical types are:

- Username/password: container registry login or legacy service account.
- Secret text: API token, Sonar token, or Git token.
- SSH private key: Git access over SSH.
- Secret file: cloud service account configuration.

Inject secrets only around the command needing them:

```groovy
withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
  sh 'mvn sonar:sonar -Dsonar.token=$SONAR_TOKEN'
}
```

Jenkins masks known credential values in logs, but this is not a reason to print them. Avoid Groovy string interpolation of secrets (`"...${TOKEN}..."`); let the shell expand an environment variable in a single-quoted Groovy string instead.

Also use role-based access control, least-privilege service accounts, HTTPS, current Jenkins LTS/plugins, controller backups, and a trusted-review rule for Jenkinsfile changes.

## 8. Triggers

| Trigger | Best use | Important point |
| --- | --- | --- |
| Webhook | Normal Git push/PR automation | Fast and event-driven; preferred over polling. |
| Manual | Testing or deliberate release action | Gives a human an explicit control point. |
| Cron | Nightly scan, scheduled job | Use `triggers { cron('H 2 * * *') }`; `H` spreads load. |
| Poll SCM | When webhook cannot be configured | Jenkins periodically asks Git for changes; less efficient. |
| Upstream job | Pipeline depends on another pipeline | Pass versioned artifacts, not only an implicit workspace. |

## 9. Practical CI/CD design

A production-quality outline is:

```text
Checkout -> dependency install -> unit test -> quality/security scan
-> package -> build immutable image -> scan/sign image -> push registry
-> update GitOps desired-state repo -> Argo CD syncs -> verify deployment
```

Use an immutable image tag such as a Git commit SHA or release version, not only `latest`. Keep CI and CD responsibilities clear:

- Jenkins: validates, creates, and publishes a version.
- GitOps repository: declares the desired version/environment configuration.
- Argo CD: reconciles the declared state into Kubernetes.
- Kubernetes: runs and heals the workloads.

For environments, promote the **same tested image digest/tag** from dev to staging to production by changing configuration through reviewed Git changes. Do not rebuild a different image for each environment.

## 10. A safe Jenkinsfile to practise

Put this in your own Node project after adding `package.json` and tests. It has no real secrets or publishing action.

```groovy
pipeline {
  agent {
    docker { image 'node:22-alpine' }
  }

  options {
    timestamps()
    timeout(time: 15, unit: 'MINUTES')
  }

  stages {
    stage('Install') {
      steps { sh 'npm ci' }
    }
    stage('Test') {
      steps { sh 'npm test' }
    }
    stage('Build') {
      steps { sh 'npm run build --if-present' }
    }
  }
  post {
    always { cleanWs() }
  }
}
```

Practise in this sequence:

1. Run the pipeline and read every Console Output line.
2. Add a stage that prints `pwd` and `ls -la`; identify the workspace.
3. Intentionally run an invalid command, locate the failing stage and exit code, then fix it.
4. Change the job to **Pipeline script from SCM**.
5. Add a webhook and prove a Git push triggers a build.
6. Add a Dockerfile, build locally, then add an image-build stage.
7. Add credentials and publish only to a registry/repository you own.

## 11. Troubleshooting checklist

| Symptom | Likely cause | First checks |
| --- | --- | --- |
| Build stays queued | No agent/executor matches | Agent online? Label correct? Enough executors? |
| `docker: permission denied` | Jenkins user cannot access Docker socket | Docker service, group membership, Jenkins restart; review socket security. |
| Tool command not found | Wrong agent/image | Print tool version; choose an image containing the tool. |
| Checkout fails | Incorrect URL/branch or credential scope | Test repository access and job credential ID. |
| Stage cannot find output | Different agent/workspace | Use `stash`/`unstash`, artifacts, or persistent storage. |
| Secret appears in a log | Unsafe echo/interpolation | Revoke/rotate it, remove output, and change credential handling. |
| Pipeline behaves differently after restart | State depended on workspace/container | Persist only intentional artifacts and use reproducible setup. |

Always start with the Console Output: find the first genuine error, identify the stage, command, agent, and exit code. Later errors are often consequences.

## 12. Interview answers you should be able to say naturally

**What is Jenkins?** Jenkins is an extensible automation server. I use it to define CI/CD pipelines as code, schedule work on agents, integrate Git/build/scanning/registry tools, and keep build logs and artifacts.

**Controller versus agent?** The controller queues and orchestrates work; agents execute build steps. Separating them protects controller capacity and lets each workload use a dedicated environment.

**What is a Jenkinsfile?** A version-controlled file that defines the pipeline. It makes pipeline changes reviewable and reproducible alongside the application code.

**Declarative versus Scripted Pipeline?** Declarative Pipeline has a structured, opinionated syntax and is easier to read and govern. Scripted Pipeline is more flexible Groovy code but can become harder to maintain. I choose Declarative unless advanced dynamic behavior needs Scripted sections.

**How do you secure secrets?** I store them in Jenkins Credentials or an external secret manager, scope access by folder/job, inject them only for the needed command, never commit or print them, and rotate any exposed secret.

**How do you use different tools in one pipeline?** With stage-level agents. For example, Maven/JDK in the backend stage and Node in the frontend stage. I explicitly transfer artifacts because separate agents do not share a workspace by default.

**Webhook or Poll SCM?** I prefer a webhook because it is immediate and efficient. Polling is a fallback when the Git provider cannot notify Jenkins.

**How do you handle a failed pipeline?** I use the console log to locate the first failing command and exit code, fix the root cause, rerun, and use `post { always { ... } }` to preserve test reports/logs and clean the workspace. For transient infrastructure failures, I use limited, targeted retry rather than hiding real failures.

**How do Jenkins and Argo CD work together?** Jenkins performs CI and publishes an immutable image. It then updates the desired image version in a GitOps repository. Argo CD observes that Git change and reconciles Kubernetes; that provides an auditable separation between build and deployment.

**How do you back up Jenkins?** I back up `JENKINS_HOME` consistently—job and folder configuration, credentials/secrets with the required encryption keys, plugins, and relevant build metadata—then test restoration. I also manage configuration and plugin versions as code where possible.

## 13. Frequent interview pitfalls

- Do not say Jenkins "deploys with Argo CD" when using GitOps. Jenkins updates desired state; Argo CD reconciles it.
- Do not call every Docker container an agent. A Docker container becomes the execution environment only when Jenkins allocates it for a stage/job.
- Do not say environment variables are a secure secret store. They are only a delivery mechanism and can leak.
- Do not expose Jenkins port 8080 to the entire internet. Restrict network access and use TLS/reverse proxy where appropriate.
- Do not quote a "latest Jenkins version" unless you verify it on the interview day. Say whether your environment uses LTS or weekly releases and why.

## 14. Your revision checklist

Before an interview, make sure you can do these without copying:

- Write a basic Declarative Jenkinsfile with `agent`, `stages`, `steps`, `environment`, and `post`.
- Explain webhook-to-build flow and configure a Pipeline-from-SCM job.
- Read a failed console log and identify the first meaningful failure.
- Create and use a Jenkins credential without putting its value in source control.
- Explain why stage-level agents require artifact transfer.
- Describe an end-to-end Git -> Jenkins -> registry -> GitOps repo -> Argo CD -> Kubernetes flow.
- Explain one pipeline you personally ran, including a failure you diagnosed and fixed.
