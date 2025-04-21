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

```mermaid
graph LR
    User[User] --> Git[Git Repository];
    Git --> Jenkins[Jenkins Pipeline];
    Jenkins --> Podman[Podman Build];
    Podman --> ECR[AWS ECR];
    Jenkins --> Git; %% Pipeline updates manifests in Git
    Git --> ArgoCD[ArgoCD];
    ArgoCD --> EKS[AWS EKS Cluster];
    ECR --> EKS; %% EKS pulls images from ECR
    EKS --> User; %% User accesses Application via Service/Ingress
    Jenkins --> EKS; %% Jenkins Agents run in EKS
    Jenkins --> AWS[AWS (IRSA)]; %% Jenkins agent assumes IAM Role
    AWS --> ECR; %% Jenkins agent pushes to ECR