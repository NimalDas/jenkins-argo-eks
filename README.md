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
    * [Kubernetes Namespace](#57-kubernetes-namespace)
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

# Jenkins-Argo-EKS Node.js App Deployment

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
.
├── Jenkinsfile                     # Jenkins Pipeline definition
├── terraform/                      # Terraform code for infrastructure
│   └── ...                         # VPC, EKS, ECRs, IRSA setup
├── eks-gitops/
│   └── nodejs-app/
│       ├── k8s/                    # Kubernetes manifest files for Node.js app
│       │   ├── blue-deployment.yaml  # Manifest for the blue deployment
│       │   ├── green-deployment.yaml # Manifest for the green deployment
│       │   ├── service.yaml          # Service manifest
│       │   └── active-env.txt        # Tracks the current active environment (blue/green)
│       ├── Dockerfile              # Dockerfile for the Node.js app
│       ├── package.json            # Node.js package file
│       └── server.js               # Node.js application code
└── jenkins-agent/                  # Directory for custom Jenkins agent image
    └── Dockerfile.jenkins-agent    # Dockerfile for the Podman-enabled agent

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

Ensure your Jenkins Helm chart values.yaml is configured:

To use the jenkins Service Account in the correct namespace (jenkins).
The agent.image.repository and agent.image.tag fields point to your custom Podman-enabled Jenkins agent image in your jenkins-agents ECR repository (you'll build and push this image in a later step).
The Service Account is annotated with the IRSA role ARN created by Terraform (your Terraform code should handle this annotation).

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

