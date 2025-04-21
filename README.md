# CI/CD Pipeline for Node.js App on EKS with Jenkins, Podman, ECR, and ArgoCD Blue/Green

This project demonstrates a complete Continuous Integration (CI) and Continuous Deployment (CD) pipeline for a simple Node.js application deployed to an Amazon Elastic Kubernetes Service (EKS) cluster using a Blue/Green deployment strategy managed by ArgoCD.

## Table of Contents

1.  [Overview](#1-overview)
2.  [Architecture](#2-architecture)
3.  [Prerequisites](#3-prerequisites)
4.  [Repository Structure](#4-repository-structure)
5.  [Setup](#5-setup)
    * [Terraform Infrastructure](#51-terraform-infrastructure)
    * [Jenkins Deployment via ArgoCD](#52-jenkins-deployment-via-argocd)
    * [ArgoCD Setup](#53-argocd-setup)
    * [Custom Jenkins Agent Image](#54-custom-jenkins-agent-image)
    * [Jenkins Configuration](#55-jenkins-configuration)
    * [ArgoCD Application for Node.js App](#56-argocd-application-for-nodejs-app)
6.  [CI/CD Pipeline (Jenkinsfile)](#6-cicd-pipeline-jenkinsfile)
7.  [Deployment Strategy (Blue/Green with ArgoCD)](#7-deployment-strategy-bluegreen-with-argocd)
8.  [How to Run the Demo](#8-how-to-run-the-demo)
    * [Initial Blue Deployment](#81-initial-blue-deployment)
    * [Release Green Deployment](#82-release-green-deployment)
    * [Demonstrate Rollback (Optional)](#83-demonstrate-rollback-optional)
9.  [Future Improvements](#9-future-improvements)
10. [Troubleshooting](#10-troubleshooting)

## 1. Overview

This project sets up an automated CI/CD pipeline that:
* Builds a Node.js application container image using Podman.
* Pushes the image to Amazon Elastic Container Registry (ECR).
* Updates Kubernetes manifest files in a Git repository to reference the new image.
* Uses ArgoCD to automatically detect changes in the Git repository and deploy the application to an EKS cluster.
* Implements a Blue/Green deployment strategy for zero-downtime releases, visually demonstrated by changing the application's background color.

## 2. Architecture

The setup involves the following key components:

* **Git Repository:** Stores application code, Kubernetes manifests, and Jenkins Pipeline (`Jenkinsfile`). Serves as the single source of truth.
* **Jenkins:** Runs the CI pipeline, triggered by Git commits. Deployed within EKS using a Helm chart and managed by ArgoCD. Uses a custom agent image with Podman and AWS CLI. Authenticates to AWS ECR via IRSA. Authenticates to Git via SSH credentials.
* **Podman:** Used by the Jenkins agent to build OCI-compliant container images.
* **Amazon ECR:** A private container registry to store the application's Docker images.
* **AWS EKS:** The Kubernetes cluster where Jenkins agents and the Node.js application are deployed.
* **IRSA (IAM Roles for Service Accounts):** Grants the Jenkins agent pod necessary AWS permissions (e.g., to push to ECR) without using long-lived access keys. Managed by Terraform.
* **ArgoCD:** A declarative GitOps tool deployed within EKS. Monitors the Git repository for manifest changes and automatically synchronizes the desired state to the EKS cluster. Manages the Blue/Green deployment strategy.
* **Node.js Application:** A simple web application deployed as Kubernetes Deployments and a Service. Its background color changes based on an environment variable to indicate the deployment version (Blue/Green).
* **Kubernetes Manifests:** Define the desired state of the Node.js application (Deployments for blue/green versions, Service) in YAML files stored in Git.
* **Terraform:** Used to provision the core AWS infrastructure (VPC, EKS cluster, ECR repositories) and configure IRSA.

## 3. Prerequisites

- An AWS account with appropriate permissions to create VPC, EKS, ECR, IAM resources.
- AWS CLI installed and configured locally.
- `kubectl` installed and configured to connect to your EKS cluster.
- `helm` installed.
- `terraform` installed.
- `git` installed.
- `docker` or `podman` installed locally to build and push the custom Jenkins agent image.
- Node.js and `npm` installed locally to test the Node.js application.

## 4. Repository Structure

Your Git repository is structured to contain the application code, Kubernetes manifests, Terraform code, and `Jenkinsfile`.
└── jenkins-argo-eks/
    ├── eks-gitops/
    │   └── nodejs-app/
    │       ├── k8s/
    │       ├── Dockerfile
    │       ├── package.json
    │       └── server.js
    ├── infra/
    │   ├── ecr_repo.tf
    │   └── eks_cluster.tf
    ├── jenkins-agent/
    │   └── Dockerfile
    └── misc

## 5. Setup

Follow these steps to set up the entire CI/CD pipeline and infrastructure.

### 5.1 Terraform Infrastructure

Navigate to the `infra/` directory and apply your Terraform code to provision the VPC, EKS cluster, ECR repositories (nodejs-app and jenkins-agents), and the IAM role/policy/Service Account annotation for Jenkins IRSA.

```bash
cd infra/
terraform init
terraform plan
terraform apply
```
### 5.2 Jenkins Deployment via ArgoCD

Deploy Jenkins into your EKS cluster using its Helm chart, managed by ArgoCD. Refer to your ArgoCD App of Apps setup or create a dedicated ArgoCD Application for Jenkins.

Ensure your Jenkins Helm chart `values.yaml` is configured:

* To use the `jenkins` Service Account in the correct namespace (`jenkins`).
* The `agent.image.repository` and `agent.image.tag` fields point to your custom Podman-enabled Jenkins agent image in your `jenkins-agents` ECR repository (you'll build and push this image in a later step).
* The Service Account is annotated with the IRSA role ARN created by Terraform (your Terraform code should handle this annotation).

### 5.3 ArgoCD Setup
Ensure ArgoCD is installed in your cluster (if not already done via App of Apps). Access the ArgoCD UI.

### 5.4 Custom Jenkins Agent Image
Build the custom Jenkins agent Docker image that includes Podman, AWS CLI, and any other necessary tools, using the Dockerfile. (located in misc/ or similar). Push this image to your jenkins-agents ECR repository.

```bash
# Navigate to the directory containing your Dockerfile
cd jenkins-agent/

# Build the image (replace <your-registry> and <tag>)
docker build -t 965202785849.dkr.ecr.us-east-1.amazonaws.com/jenkins-agents:1.0.0-podman-npm -f .

# Authenticate to your jenkins-agents ECR repository
aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin [965202785849.dkr.ecr.us-east-1.amazonaws.com/jenkins-agents](https://965202785849.dkr.ecr.us-east-1.amazonaws.com/jenkins-agents)

# Push the image
docker push 965202785849.dkr.ecr.us-east-1.amazonaws.com/jenkins-agents:1.0.0-podman-npm
Important: Ensure the <your-registry>/jenkins-inbound-podman:<tag> exactly matches the agent.image.repository and agent.image.tag configured in your Jenkins Helm chart values.yaml. Sync ArgoCD for the Jenkins application if you changed the image reference.
```
### 5.5 Jenkins Configuration

Configure your Jenkins instance to connect to your Git repository and define the pipeline job.

* **Create Git Credential:** In Jenkins, create a **SSH Username with private key** credential. Use the `jenkins-argo-eks-repo-creds` ID (as used in your Jenkinsfile). Provide the username (`git`) and your SSH private key for accessing your Git repository.
* **Create Pipeline Job:** Create a new Jenkins Pipeline job. Configure it to pull the `Jenkinsfile` from your Git repository (`main` branch) using the SSH credential.

### 5.6 ArgoCD Application for Node.js App

Create an ArgoCD Application resource to manage the Node.js application deployment using GitOps. This tells ArgoCD where to find the application manifests and how to deploy them.

Create a YAML file (e.g., `argocd-nodejs-app.yaml`) with the Application definition and apply it to your cluster in the namespace where ArgoCD is installed.

## 6. CI/CD Pipeline (Jenkinsfile)

Your Jenkinsfile orchestrates the CI process:

* **Add GitHub Host Key:** Adds the Git host's SSH key to `known_hosts` for SSH communication.
* **Checkout Repository:** Clones the Git repository using SSH credentials.
* **Build Node.js App:** Installs Node.js dependencies and runs a brief local health check.
* **Build Docker Image with Podman:** Builds the application's Docker image using Podman, tagged with the ECR registry URI and Jenkins build number.
* **Push to ECR:** Authenticates Podman to ECR using AWS CLI (leveraging IRSA) and pushes the newly built image (both the build-specific tag and `:latest`).
* **Update Manifest:** This stage implements the Blue/Green toggle logic. It reads `active-env.txt` to find the current active environment (`blue` or `green`). It determines the `newEnv` by toggling. It updates the image tag and `DEPLOYMENT_VERSION` environment variable in the *new environment's deployment file* (`blue-deployment.yaml` or `green-deployment.yaml`). It updates the `service.yaml`'s selector to point to the `newEnv` by changing the `env` label value. It updates `active-env.txt` and commits/pushes these manifest changes back to Git via SSH.

## 7. Deployment Strategy (Blue/Green with ArgoCD)

This setup implements a Blue/Green strategy where:

* You have two separate deployment manifests in Git (`blue-deployment.yaml`, `green-deployment.yaml`).
* Your `service.yaml` uses a selector (`env: <color>`) to route traffic to either the blue or green deployment.
* The Jenkins pipeline is responsible for:
    * Building the new image.
    * Updating the manifest file for the inactive environment with the new image tag.
    * Updating the `service.yaml` in Git to change the `env` selector, thereby switching traffic to the newly updated environment.
* ArgoCD monitors the `eks-gitops/nodejs-app/k8s/` path in Git and automatically applies the changes to the cluster, including the Service selector update.
* The `active-env.txt` file is a simple mechanism in the Git repository to track which environment is currently active, allowing the pipeline to determine which deployment file to update and which environment to switch to next.

## 8. How to Run the Demo

Follow these steps to demonstrate the Blue/Green deployment cycle using the pipeline and ArgoCD.

### 8.1 Initial Blue Deployment

To start with a known "blue" state for your demo:

1.  **Prepare for Blue:** Manually edit `eks-gitops/nodejs-app/k8s/blue-deployment.yaml` in your Git repository. Set the `image:` tag to a known blue image in ECR (e.g., `:build-1`) and the `DEPLOYMENT_VERSION` env var `value:` to `"v1"`. Ensure `eks-gitops/nodejs-app/k8s/service.yaml` has `selector: { app: nodejs-app, env: blue }`. Ensure `eks-gitops/nodejs-app/k8s/active-env.txt` contains `blue`.
2.  **Commit Initial State:** Commit these files (`blue-deployment.yaml`, `service.yaml`, `active-env.txt`) to your Git repository and push.
3.  **Observe in ArgoCD:** Go to the ArgoCD UI. Your `nodejs-app` Application should sync the initial state, creating the blue deployment and service pointing to it.
4.  **Verify Blue:** Access your application URL. It should show the **blue page**.

### 8.2 Release Green Deployment

Now, trigger a new release to deploy the "green" version and switch traffic.

1.  **Trigger Jenkins:** Go to Jenkins and trigger your pipeline job ("Build Now").
2.  **Pipeline Runs:** The pipeline will build a new image (e.g., `:build-2`), push it, update `green-deployment.yaml` with `:build-2` and `DEPLOYMENT_VERSION: v2`, update `service.yaml` selector to `env: green`, and update `active-env.txt` to `green`. These changes are committed and pushed to Git.
3.  **ArgoCD Syncs:** ArgoCD detects the changes in Git. It will sync:
    * The updated `green-deployment.yaml` (deploying the new green pods).
    * The updated `service.yaml` (changing the selector to `env: green`, instantly switching traffic to green).
    * The updated `active-env.txt`.
4.  **Verify Green:** Access your application URL. It should now show the **green page**. Both blue and green deployments will likely be running concurrently for a period, but traffic goes to green.

### 8.3 Demonstrate Rollback (Optional)

To demonstrate rolling back to the previous blue version:

1.  **Revert Manifests in Git:** You can use `git revert` or manually edit `service.yaml` and `active-env.txt` in your repository to switch the `env` selector back to `blue`. Also, ensure `blue-deployment.yaml` has the desired image tag for the rollback version if it was changed.
2.  **Commit Rollback:** Commit these changes and push to Git.
3.  **ArgoCD Syncs Rollback:** ArgoCD detects the changes and syncs, switching the Service selector back to `env: blue`.
4.  **Verify Rollback:** Access your application URL. It should switch back to the **blue page**.

Alternatively, you could build a "rollback" stage into your Jenkins pipeline that performs the necessary `sed`/git commands to switch the service back to blue.

## 9. Future Improvements

Consider these potential enhancements to your setup:

* **Argo Rollouts:** For a more advanced Blue/Green or Canary strategy with features like automated analysis, traffic splitting, and easier rollback managed directly by a Kubernetes controller, integrate with Argo Rollouts. This would involve converting your Deployments to Rollouts and configuring the strategy in the Rollout spec.
* **Automated Testing:** Add pipeline stages to perform automated tests on the newly deployed (but inactive) green environment before switching traffic.
* **Manifest Templating:** Use Kustomize or Helm to manage your Kubernetes manifests, reducing duplication between blue/green deployment files and allowing easier parameterization of the image tag and version.
* **Pipeline Optimization:** Refine the pipeline stages, potentially combining some steps or using shared libraries.
* **Rootless Podman:** Configure the Jenkins agent to run Podman rootless for enhanced security.

## 10. Troubleshooting

Here are some common issues and troubleshooting tips:

* **`command not found`:** Ensure Podman, AWS CLI, and any other tools are installed on your custom Jenkins agent image and the Helm chart is configured to use that image.
* **SSH Issues (Host Key, Permissions):** Verify SSH host key scanning in the pipeline, correct Git repository URL (SSH), and correct SSH credential in Jenkins.
* **ECR Authentication (`unauthorized`):** Check Jenkins IRSA setup, ensure the Service Account is correctly annotated with the IAM role ARN, and the IAM role has permissions to push/pull from ECR. Verify the `aws ecr get-login-password | podman login ...` command is correct and executed by a user with IRSA permissions.
* **ArgoCD OutOfSync:** Check ArgoCD logs for sync errors. Ensure the repoURL, targetRevision, and path in the ArgoCD Application are correct. Verify the cluster and namespace details are correct.
* **Blue/Green Not Switching:** Check the `service.yaml` selector labels and ensure they match the labels on your blue/green deployment pods (`env: blue` or `env: green`). Verify the pipeline is correctly updating the `service.yaml` selector in Git. Check ArgoCD Application logs for blue/green specific errors or events.
* **Podman Build/Mount Issues:** If encountering `fuse-overlayfs` or mounting errors, ensure the agent has necessary privileges (`privileged: true` for rootful, or proper rootless setup) and required kernel modules/capabilities.
