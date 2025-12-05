# Multi-Stage CI/CD Pipeline on Kubernetes with Jenkins & Terraform

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-623CE4?logo=terraform)](https://www.terraform.io/)
[![Container Orchestration](https://img.shields.io/badge/K8s-EKS-326CE5?logo=kubernetes)](https://aws.amazon.com/eks/)
[![CI/CD](https://img.shields.io/badge/CI/CD-Jenkins-D24939?logo=jenkins)](https://www.jenkins.io/)
[![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws)](https://aws.amazon.com/)

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Installation & Deployment](#installation--deployment)
  - [Step 1: Initial Terraform Deployment](#step-1-initial-terraform-deployment)
  - [Step 2: Access Terraform Outputs](#step-2-access-terraform-outputs)
  - [Step 3: Configure kubectl for EKS](#step-3-configure-kubectl-for-eks)
- [Troubleshooting Common Issues](#troubleshooting-common-issues)
  - [Token Expiration (Unauthorized Errors)](#token-expiration-unauthorized-errors)
  - [EC2 Slave Agent Not Connected](#ec2-slave-agent-not-connected)
- [Configuring Kubernetes Access for Agents](#configuring-kubernetes-access-for-agents)
  - [EC2 Slave Agent Configuration](#ec2-slave-agent-configuration)
  - [Jenkins Master Configuration](#jenkins-master-configuration)
- [Jenkins Configuration](#jenkins-configuration)
  - [Installing Required Plugins](#installing-required-plugins)
  - [Setting Up Credentials](#setting-up-credentials)
  - [Configuring Kubernetes Dynamic Pod Agents](#configuring-kubernetes-dynamic-pod-agents)
- [Running the Pipelines](#running-the-pipelines)
- [Pipeline Descriptions](#pipeline-descriptions)
- [Monitoring & Observability](#monitoring--observability)
- [Security Considerations](#security-considerations)
- [Project Review](#project-review)

---

## 🎯 Overview

This project implements a **production-grade, multi-stage CI/CD infrastructure** on AWS using modern DevOps practices and tools. It combines Infrastructure as Code (Terraform), container orchestration (Kubernetes/EKS), and continuous integration/delivery (Jenkins) to create a fully automated, scalable deployment pipeline.

### What This Project Does

- **Provisions complete AWS infrastructure** including VPC, subnets, NAT gateways, security groups, and EKS cluster
- **Deploys Jenkins master and slave agents** for distributed build execution
- **Implements Kubernetes dynamic pod agents** that spawn on-demand for each pipeline run
- **Automates application deployment** using Helm charts to Kubernetes
- **Includes comprehensive quality gates**: security scanning (TruffleHog, Bandit), linting (Flake8), and unit testing (Pytest)
- **Provides horizontal pod autoscaling** based on CPU utilization
- **Monitors infrastructure** with Prometheus
- **Exposes applications** via AWS Application Load Balancer with automatic ingress management

---

## 🏗 Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-west-2)                        │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │                          VPC (10.0.0.0/16)                          │ │
│  │                                                                      │ │
│  │  ┌────────────────────┐         ┌────────────────────┐            │ │
│  │  │  Public Subnet A   │         │  Public Subnet B   │            │ │
│  │  │   (10.0.1.0/24)    │         │   (10.0.2.0/24)    │            │ │
│  │  │                    │         │                    │            │ │
│  │  │  ┌──────────────┐ │         │  ┌──────────────┐ │            │ │
│  │  │  │   Jenkins    │ │         │  │  EKS Public  │ │            │ │
│  │  │  │   Master EC2 │ │         │  │  Node Group  │ │            │ │
│  │  │  │   (8080)     │ │         │  │              │ │            │ │
│  │  │  └──────┬───────┘ │         │  └──────────────┘ │            │ │
│  │  │         │ JNLP    │         │                    │            │ │
│  │  │         │ :50000  │         │                    │            │ │
│  │  └─────────┼─────────┘         └────────────────────┘            │ │
│  │            │                                                       │ │
│  │            │  ┌────────────────────────────────────────┐         │ │
│  │            │  │      Private Subnet A (10.0.3.0/24)    │         │ │
│  │            │  │                                         │         │ │
│  │            │  │  ┌──────────────┐  ┌──────────────┐   │         │ │
│  │            └──┼─▶│  EC2 Slave   │  │  EKS Private │   │         │ │
│  │               │  │   Agent      │  │  Node Group  │   │         │ │
│  │               │  │  (kubectl)   │  │              │   │         │ │
│  │               │  └──────────────┘  └──────┬───────┘   │         │ │
│  │               │                            │           │         │ │
│  │               │  ┌─────────────────────────▼────────┐ │         │ │
│  │               │  │      Amazon EKS Cluster          │ │         │ │
│  │               │  │                                   │ │         │ │
│  │               │  │  ┌────────────────────────────┐  │ │         │ │
│  │               │  │  │   devops namespace         │  │ │         │ │
│  │               │  │  │                            │  │ │         │ │
│  │               │  │  │  ┌──────────────────────┐ │  │ │         │ │
│  │               │  │  │  │  Dynamic Pod Agents  │ │  │ │         │ │
│  │               │  │  │  │  (Ephemeral)         │ │  │ │         │ │
│  │               │  │  │  │  - JNLP Container    │ │  │ │         │ │
│  │               │  │  │  │  - Tools Container   │ │  │ │         │ │
│  │               │  │  │  │    (kubectl, helm,   │ │  │ │         │ │
│  │               │  │  │  │     docker, python)  │ │  │ │         │ │
│  │               │  │  │  └──────────────────────┘ │  │ │         │ │
│  │               │  │  │                            │  │ │         │ │
│  │               │  │  │  ┌──────────────────────┐ │  │ │         │ │
│  │               │  │  │  │ Application Pods     │ │  │ │         │ │
│  │               │  │  │  │ (Python Flask App)   │ │  │ │         │ │
│  │               │  │  │  │ Replicas: 3 (HPA)    │ │  │ │         │ │
│  │               │  │  │  └──────────────────────┘ │  │ │         │ │
│  │               │  │  │                            │  │ │         │ │
│  │               │  │  │  Service Accounts:         │  │ │         │ │
│  │               │  │  │  - jenkins-deployer        │  │ │         │ │
│  │               │  │  │  - aws-load-balancer-cntrl │  │ │         │ │
│  │               │  │  └────────────────────────────┘  │ │         │ │
│  │               │  │                                   │ │         │ │
│  │               │  │  ┌────────────────────────────┐  │ │         │ │
│  │               │  │  │   monitoring namespace     │  │ │         │ │
│  │               │  │  │   - Prometheus             │  │ │         │ │
│  │               │  │  └────────────────────────────┘  │ │         │ │
│  │               │  └───────────────────────────────────┘ │         │ │
│  │               │                                         │         │ │
│  │               └─────────────────────────────────────────┘         │ │
│  │                                                                    │ │
│  │  ┌──────────────────────────────────────────────────────────────┐ │ │
│  │  │              AWS Application Load Balancer                   │ │ │
│  │  │              (Managed by ALB Ingress Controller)             │ │ │
│  │  │              Routes: /api → rickandmorty service             │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────┘

                    ┌───────────────────────────┐
                    │   External Services       │
                    ├───────────────────────────┤
                    │ • Docker Hub              │
                    │ • GitHub (Source)         │
                    │ • Rick & Morty API        │
                    └───────────────────────────┘
```

### Architecture Highlights

**Multi-Tier Network Design:**
- Public subnets host Jenkins master and EKS public nodes (for ALB targets)
- Private subnets host EC2 slave and EKS private nodes (for workloads)
- NAT Gateway enables private subnet internet access

**Hybrid Agent Architecture:**
- **Jenkins Master (EC2)**: Orchestrates all pipelines, stores configurations
- **EC2 Slave Agent**: Static agent with kubectl/helm, handles Docker builds and K8s deployments
- **Dynamic Kubernetes Pod Agents**: Ephemeral agents for quality checks (tests, linting, security scans)

**Security Layers:**
- Security Groups with least-privilege access (Jenkins ↔ Agents, Agents ↔ EKS API)
- RBAC-enabled service accounts for K8s operations
- Secrets management for Docker registry and K8s authentication
- TruffleHog for secrets detection in code

**Auto-Scaling:**
- HPA (Horizontal Pod Autoscaler) for application pods based on CPU
- EKS managed node groups with auto-scaling capabilities

---

## ✨ Key Features

### Infrastructure as Code
- **Fully automated AWS infrastructure provisioning** with Terraform modules
- **Modular design** for VPC, EKS, compute, security, IAM, and monitoring
- **State management** with S3 backend support (optional)

### CI/CD Pipeline
- **Multi-stage pipelines** with quality gates:
  - Secrets detection (TruffleHog)
  - Code linting (Flake8)
  - Security scanning (Bandit)
  - Unit testing (Pytest) with coverage reports
- **Kubernetes-native deployments** using Helm charts
- **Automatic rollbacks** on deployment failures
- **Dynamic agent provisioning** for parallel builds

### Application
- **Python Flask REST API** consuming Rick & Morty API
- **Health checks** and liveness probes
- **Container registry** integration with Docker Hub
- **Zero-downtime deployments** with rolling updates

### Observability
- **Prometheus** for metrics collection
- **Helm-based deployments** for easy management
- **Application health monitoring** via K8s probes

---

## ✅ Prerequisites

### Required Tools
- **Terraform** >= 1.5.0
- **AWS CLI** configured with credentials
- **kubectl** (for EKS interaction)
- **SSH client** (for EC2 access)

### AWS Account Requirements
- IAM user/role with permissions to create:
  - VPC, subnets, route tables, internet/NAT gateways
  - EKS clusters and managed node groups
  - EC2 instances, security groups, key pairs
  - IAM roles, policies, and access entries
  - Application Load Balancers

### External Accounts
- **Docker Hub account** (for pushing/pulling images)
- **GitHub account** (if using private repositories)

### Network Requirements
- Your **public IP address** (for accessing Jenkins UI and SSH)
- Open outbound internet access for downloading dependencies

---

## 📁 Project Structure

```
multi-stage-ci-cd-k8s/
├── Terraform/
│   ├── main.tf                          # Root module orchestration
│   ├── variables.tf                     # Input variables
│   ├── output.tf                        # Output values
│   ├── Modules/
│   │   ├── vpc/                         # VPC, subnets, routing
│   │   ├── eks/                         # EKS cluster configuration
│   │   ├── compute/                     # Jenkins & slave EC2 instances
│   │   │   ├── jenkins_user_data.sh     # Jenkins auto-setup script
│   │   │   └── slave_user_data.sh.tmpl  # Slave agent setup script
│   │   ├── security/                    # Security groups & rules
│   │   ├── iam/                         # IAM roles, service accounts
│   │   ├── helm-alb-controller/         # AWS Load Balancer Controller
│   │   ├── k8s_foundation/              # K8s resources (namespaces, RBAC, HPA)
│   │   └── monitoring/                  # Prometheus setup
│   └── .gitignore
│
├── Docker/
│   ├── Dockerfile                       # Application container
│   ├── main.py                          # Flask API application
│   ├── requirments.txt                  # Python dependencies
│   ├── test_app.py                      # Unit tests
│   └── Tool_container/
│       └── Dockerfile                   # Tools container (kubectl, helm, etc.)
│
├── Helm/
│   ├── Chart.yaml                       # Helm chart metadata
│   ├── values.yaml                      # Default values
│   └── templates/
│       ├── deployment.yaml              # K8s deployment manifest
│       ├── service.yaml                 # K8s service manifest
│       ├── ingress.yaml                 # ALB ingress configuration
│       └── _helpers.tpl                 # Template helpers
│
├── Jenkins/
│   ├── CICD_Deploy_k8S/
│   │   └── Jenkinsfile                  # Main deployment pipeline
│   ├── Control_K8s_Replica_Count/
│   │   └── Jenkinsfile                  # Scaling pipeline
│   ├── File_Injection/
│   │   └── Jenkinsfile                  # Config injection pipeline
│   └── ci/
│       └── trufflehog_exclude.txt       # TruffleHog ignore patterns
│
└── README.md
```

---

## 🚀 Installation & Deployment

### Step 1: Initial Terraform Deployment

#### 1.1 Clone the Repository

```bash
git clone https://github.com/Danielashkenazy/multi-stage-ci-cd-k8s.git
cd multi-stage-ci-cd-k8s/Terraform
```

#### 1.2 Configure Variables

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
# terraform.tfvars
your_iam_role_arn = "arn:aws:iam::123456789012:user/your-username"
own_ip            = "203.0.113.0/32"  # Your public IP with /32
allowed_cidr      = "203.0.113.0/32"  # Same as own_ip for EKS access
instance_type     = "t3.small"        # EC2 instance type

# Optional: Custom CIDR ranges
vpc_cidr              = "10.0.0.0/16"
public_subnet_a_cidr  = "10.0.1.0/24"
public_subnet_b_cidr  = "10.0.2.0/24"
private_subnet_a_cidr = "10.0.3.0/24"
```

**Important:** Replace `your_iam_role_arn` with your actual IAM user/role ARN. This is used for EKS cluster access.

#### 1.3 Initialize Terraform

```bash
terraform init
```

#### 1.4 Review the Plan

```bash
terraform plan
```

This will show you all resources that will be created (~50+ resources).

#### 1.5 Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

⏳ **Expected Duration:** 15-20 minutes

The deployment includes:
- VPC with 3 subnets, IGW, NAT Gateway
- EKS cluster with 4 managed nodes (2 public + 2 private)
- Jenkins master EC2 (auto-configured with plugins)
- Slave EC2 agent (auto-connects to Jenkins)
- Security groups, IAM roles, service accounts
- ALB Ingress Controller
- Prometheus monitoring
- Kubernetes foundation (namespaces, RBAC, HPA)

---

### Step 2: Access Terraform Outputs

After successful deployment, retrieve important information:

```bash
terraform output
```

**Save these outputs** - you'll need them throughout the setup:

```bash
# Save all outputs to a file
terraform output > ../outputs.txt

# Or retrieve specific outputs
terraform output jenkins_public_url      # Jenkins UI URL
terraform output ssh_command_jenkins     # SSH to Jenkins master
terraform output scp_command_app         # SCP key to Jenkins (for slave access)
terraform output jenkins_credentials     # Username/password (sensitive)
terraform output cluster_endpoint        # EKS API endpoint
terraform output jenkins_sa_token        # K8s service account token (sensitive)
terraform output jenkins_sa_ca           # K8s CA certificate (sensitive)
```

**Retrieve sensitive outputs:**

```bash
terraform output -json jenkins_credentials | jq -r
terraform output -raw jenkins_sa_token > jenkins-sa-token.txt
terraform output -raw jenkins_sa_ca > jenkins-sa-ca.crt
```

---

### Step 3: Configure kubectl for EKS

#### 3.1 Update kubeconfig

```bash
aws eks update-kubeconfig --name my-eks-cluster --region us-west-2
```

#### 3.2 Verify Access

```bash
kubectl get nodes
kubectl get namespaces
kubectl get all -n devops
```

You should see:
- 4 nodes (2 in public subnets, 2 in private)
- `devops` and `monitoring` namespaces
- Service accounts in `devops` namespace

---

## 🔧 Troubleshooting Common Issues

### Token Expiration (Unauthorized Errors)

**Symptom:**
```
Error: Unauthorized
```

**Cause:** The EKS authentication token in Terraform state expires after **15 minutes**.

**Solution:**

Re-target the authentication data sources without recreating any infrastructure:

```bash
terraform apply \
  -target="data.aws_eks_cluster.this" \
  -target="data.aws_eks_cluster_auth.this"
```

This refreshes the token and takes ~10 seconds.

**When does this happen?**
- Running `kubectl` commands after 15 minutes of inactivity
- Running `terraform plan/apply` after 15 minutes
- Any Kubernetes/Helm provider operations

---

### EC2 Slave Agent Not Connected

**Symptom:**
- Slave agent shows as "offline" in Jenkins UI (`http://<jenkins-ip>:8080/computer/`)
- Pipeline jobs waiting for `ec2-agent` label hang indefinitely

**Cause:**
- EC2 instance failed to connect to Jenkins master during startup
- Network issues, security group misconfiguration, or user-data script failure

**Diagnosis:**

1. Check agent status in Jenkins:
   ```
   http://<jenkins-ip>:8080/computer/app-agent/
   ```

2. SSH into Jenkins master and check logs:
   ```bash
   ssh -i Modules/compute/jenkins-shared-key.pem ubuntu@<jenkins-public-ip>
   sudo journalctl -u jenkins -n 100
   ```

3. SSH into slave instance (via bastion or directly if accessible):
   ```bash
   ssh -i Modules/compute/jenkins-shared-key.pem ubuntu@<slave-private-ip>
   sudo journalctl -u jenkins-agent -n 100
   ```

**Solution:**

Taint the slave instance to force recreation:

```bash
terraform taint "module.compute.aws_instance.slave_instance"
terraform apply
```

This will:
1. Destroy the problematic slave instance
2. Create a new one with fresh configuration
3. Automatically connect to Jenkins master

Wait 5-10 minutes for the new instance to fully initialize and connect.

---

## 🔑 Configuring Kubernetes Access for Agents

Both the **EC2 Slave Agent** and **Jenkins Master** (for dynamic pod agents) need kubectl access to the EKS cluster.

### EC2 Slave Agent Configuration

The slave agent needs kubectl configured to deploy applications to Kubernetes.

#### Step 1: SSH into Slave Instance

**Option A: Direct SSH (if you have network access)**

```bash
ssh -i Modules/compute/jenkins-shared-key.pem ubuntu@<slave-private-ip>
```

**Option B: SSH via Jenkins Master Bastion**

```bash
# First, copy the private key to Jenkins master
scp -i Modules/compute/jenkins-shared-key.pem \
    Modules/compute/jenkins-shared-key.pem \
    ubuntu@<jenkins-public-ip>:/home/ubuntu/

# SSH to Jenkins master
ssh -i Modules/compute/jenkins-shared-key.pem ubuntu@<jenkins-public-ip>

# From Jenkins master, SSH to slave
ssh -i /home/ubuntu/jenkins-shared-key.pem ubuntu@<slave-private-ip>
```

#### Step 2: Create Kubernetes Config Directory

```bash
mkdir -p ~/.kube
cd ~/.kube
```

#### Step 3: Get Service Account Details

**On your EKS admin machine** (where you run Terraform):

```bash
# List secrets in devops namespace
kubectl get secrets -n devops

# You should see a secret named: jenkins-deployer-token
# Get the secret details
kubectl get secret jenkins-deployer-token -n devops -o yaml
```

The output will look like:

```yaml
apiVersion: v1
data:
  ca.crt: LS0tLS1CRUdJTi... (Base64 encoded)
  namespace: ZGV2b3Bz (Base64 encoded)
  token: ZXlKaGJHY2lPaUpTVXpJMU5pSX... (Base64 encoded)
kind: Secret
...
```

#### Step 4: Decode the Token

```bash
# Extract and decode the token
kubectl get secret jenkins-deployer-token -n devops -o jsonpath='{.data.token}' | base64 --decode
```

**Save this decoded token** - you'll need it for the kubeconfig file.

#### Step 5: Get Cluster Endpoint and CA Certificate

```bash
# Get cluster endpoint
kubectl cluster-info

# The output shows:
# Kubernetes control plane is running at https://ABC123XYZ.gr7.us-west-2.eks.amazonaws.com

# Extract CA certificate (already in the secret, but can also get from cluster)
kubectl get secret jenkins-deployer-token -n devops -o jsonpath='{.data.ca\.crt}'
```

#### Step 6: Create kubeconfig File

**Back on the slave EC2 instance**, create the config file:

```bash
nano ~/.kube/config
```

Paste the following configuration:

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <CA_CERT_BASE64_FROM_SECRET>
    server: <CLUSTER_ENDPOINT_URL>
  name: my-eks-cluster
contexts:
- context:
    cluster: my-eks-cluster
    namespace: devops
    user: jenkins-deployer
  name: jenkins-deployer-context
current-context: jenkins-deployer-context
users:
- name: jenkins-deployer
  user:
    token: <DECODED_TOKEN_FROM_STEP_4>
```

**Replace the placeholders:**

- `<CA_CERT_BASE64_FROM_SECRET>`: The `ca.crt` value from the secret (keep it Base64 encoded)
- `<CLUSTER_ENDPOINT_URL>`: Your EKS cluster endpoint (e.g., `https://ABC123.gr7.us-west-2.eks.amazonaws.com`)
- `<DECODED_TOKEN_FROM_STEP_4>`: The **decoded** token from Step 4

**Complete Example:**

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUM1ekNDQWMrZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJME1UQXdOekEwTVRVd01Gb1hEVE0wTVRBd05UQTBNVFV3TUZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTFFVCnl2M0V6... (truncated for brevity)
    server: https://D8F3A2B1E4C5A678B9C0D1E2F3A4B5C6.gr7.us-west-2.eks.amazonaws.com
  name: my-eks-cluster
contexts:
- context:
    cluster: my-eks-cluster
    namespace: devops
    user: jenkins-deployer
  name: jenkins-deployer-context
current-context: jenkins-deployer-context
users:
- name: jenkins-deployer
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6IjVxQ0pYcGRfX3VRVF9FWFR5TmxfZEJHQ1o2N0VyVmhZdGFCOWJ5UzRkV2cifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZXZvcHMiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlY3JldC5uYW1lIjoiamVua2lucy1kZXBsb3llci10b2tlbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJqZW5raW5zLWRlcGxveWVyIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYTFiMmMzZDQtZTVmNi00N2E4LTk5YjgtMTIzNDU2Nzg5YWJjIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRldm9wczpqZW5raW5zLWRlcGxveWVyIn0.ABC123...xyz789
```

#### Step 7: Set Correct Permissions

```bash
chmod 600 ~/.kube/config
```

#### Step 8: Test Configuration

```bash
kubectl get pods -n devops
kubectl auth can-i create pods -n devops
kubectl auth can-i create deployments -n devops
```

All commands should succeed. If you see "yes" for the `can-i` commands, you're ready!

---

### Jenkins Master Configuration

The Jenkins master needs K8s access to spawn dynamic pod agents.

This configuration is done **through the Jenkins UI** when setting up the Kubernetes cloud, but you'll need the token file ready.

#### Step 1: Extract Token to File

**On your EKS admin machine:**

```bash
kubectl get secret jenkins-deployer-token -n devops -o jsonpath='{.data.token}' | base64 --decode > jenkins-k8s-token.txt
```

This creates a file with the **decoded** token that we'll upload to Jenkins.

**Keep this file secure** - you'll use it when creating Jenkins credentials.

---

## ⚙️ Jenkins Configuration

### Accessing Jenkins

1. Get the Jenkins URL:
   ```bash
   terraform output jenkins_public_url
   # Output: http://54.123.45.67:8080
   ```

2. Get credentials:
   ```bash
   terraform output -json jenkins_credentials
   # Username: admin
   # Password: Admin123!
   ```

3. Open Jenkins in your browser and log in.

---

### Installing Required Plugins

Jenkins is pre-configured with basic plugins, but you need to add Kubernetes support.

#### Step 1: Navigate to Plugin Manager

**Manage Jenkins** → **Manage Plugins** → **Available Plugins**

#### Step 2: Install Kubernetes Plugins

Search for and install:
- ✅ **Kubernetes** - For dynamic pod agents
- ✅ **Kubernetes Credentials** - For K8s authentication
- ✅ **Kubernetes CLI** - For kubectl commands (optional but useful)

Already installed (from user-data script):
- Git
- Pipeline (Workflow Aggregator)
- Docker Pipeline
- Pipeline: Stage View
- Credentials Binding
- Blue Ocean

#### Step 3: Restart Jenkins

After installation completes: **Install without restart** or **Download now and install after restart**

Then: **Manage Jenkins** → **Restart** (or wait for auto-restart)

---

### Setting Up Credentials

Navigate to: **Manage Jenkins** → **Manage Credentials** → **(global)** → **Add Credentials**

#### Credential 1: GitHub Access (Optional)

Only needed if your repository is private.

- **Kind:** Username with password
- **Scope:** Global
- **Username:** Your GitHub username
- **Password:** GitHub Personal Access Token (with `repo` permissions)
- **ID:** `github-credentials`
- **Description:** GitHub Repository Access

#### Credential 2: Docker Hub Access

Required for pushing Docker images.

- **Kind:** Username with password
- **Scope:** Global
- **Username:** Your Docker Hub username
- **Password:** Docker Hub password or access token
- **ID:** `dockerhub`
- **Description:** Docker Hub Registry Access

**Important:** The pipeline uses credential ID `dockerhub` - don't change this unless you also update the Jenkinsfile.

#### Credential 3: Kubernetes Service Account Token (CRITICAL!)

This is the most important credential for dynamic pod agents.

- **Kind:** ⚠️ **Secret file** (NOT "Secret text")
- **Scope:** Global
- **File:** Upload the `jenkins-k8s-token.txt` file created earlier
- **ID:** `kubernetes-sa-token`
- **Description:** Kubernetes Service Account Token for Pod Agents

**Double-check:**
- ✅ The file contains the **decoded** token (NOT Base64 encoded)
- ✅ The credential type is **Secret file**
- ✅ The ID is exactly `kubernetes-sa-token`

---

### Configuring Kubernetes Dynamic Pod Agents

This is where the magic happens - Jenkins will spawn ephemeral pods for pipeline execution.

#### Step 1: Navigate to Cloud Configuration

**Manage Jenkins** → **Manage Nodes and Clouds** → **Configure Clouds** → **Add a new cloud** → **Kubernetes**

#### Step 2: Basic Cloud Configuration

**Name:** `kubernetes`

**Kubernetes URL:** 
```
https://<your-eks-cluster-endpoint>
```
Get this from:
```bash
terraform output cluster_endpoint
# Or: kubectl cluster-info
```

Example: `https://D8F3A2B1E4C5A678B9C0D1E2F3A4B5C6.gr7.us-west-2.eks.amazonaws.com`

**Kubernetes Namespace:** `devops`

**Credentials:** Select `kubernetes-sa-token` (the secret file we created)

**Jenkins URL:** 
```
http://<jenkins-private-ip>:8080
```

Get Jenkins private IP:
```bash
terraform output | grep jenkins_instance_private_ip
# Or check EC2 console
```

Example: `http://10.0.1.234:8080`

**Jenkins tunnel:** 
```
<jenkins-private-ip>:50000
```

Example: `10.0.1.234:50000`

**WebSocket:** ✅ Enable (recommended for better connectivity)

#### Step 3: Test Connection

Click **Test Connection** - you should see: "Connected to Kubernetes vX.XX"

If you get an error:
- ❌ "Unauthorized" → Check that the token is decoded and credential type is "Secret file"
- ❌ "Connection refused" → Verify the cluster endpoint URL
- ❌ "Forbidden" → Check service account RBAC permissions

#### Step 4: Configure Pod Template

Scroll down to **Pod Templates** → **Add Pod Template**

##### Pod Template - Basic Settings

**Name:** `jenkins-agent`

**Namespace:** `devops`

**Labels:** `tools-agent` 
(This is what the Jenkinsfile uses to request this agent)

**Usage:** "Use this node as much as possible"

##### Pod Template - Pod Retention

**Pod Retention:** 
- Select: **Default** (pods deleted after use)
- Or: **On Failure** (keep pods when builds fail - useful for debugging)

**Timeout in seconds:** `300` (5 minutes)

This is how long Jenkins waits for the pod to become ready.

##### Pod Template - Container 1: JNLP Agent

Click **Add Container** → **Container Template**

**Name:** `jnlp`

**Docker Image:** `jenkins/inbound-agent:latest`

**Working directory:** `/home/jenkins/agent`

**Command to run:** (leave empty)

**Arguments to pass to the command:** (leave empty)

**Allocate pseudo-TTY:** ❌ Unchecked

⚠️ **Critical:** 
- The container MUST be named exactly `jnlp`
- Do NOT specify a custom entrypoint or command
- Jenkins automatically injects connection parameters to this container

##### Pod Template - Container 2: Tools Container

Click **Add Container** → **Container Template**

**Name:** `tools`

**Docker Image:** `danielashkenazy1/tools:latest`

⚠️ If you've built and pushed your own tools container, use your repository instead:
```
<your-dockerhub-username>/tools:latest
```

**Working directory:** `/home/jenkins/agent`

**Command to run:** `sh` (or `cat`)

**Arguments to pass to the command:** 
```
-c
sleep infinity
```

Or if using `cat` command:
```
(leave empty)
```

**Allocate pseudo-TTY:** ❌ Unchecked

**Why `sleep infinity` or `cat`?**
This keeps the container running indefinitely. The pipeline will execute commands in this container using `container('tools') { ... }` blocks.

**What's in the tools container?**
- kubectl
- helm  
- Python 3 + pip
- Node.js + npm
- Go
- flake8, bandit, pytest (Python tools)
- git, curl, wget, jq

##### Pod Template - Service Account (Important!)

**Service Account:** `jenkins-deployer`

This service account was created by Terraform with the following permissions in the `devops` namespace:
- Create, get, list, watch, update, patch, delete: pods, services, deployments
- Execute commands in pods (`exec`)
- Manage secrets and configmaps
- Manage ingresses
- Scale deployments

##### Pod Template - Volume Mounts (Optional)

If you want to use Docker-in-Docker (build Docker images from within the pod):

Click **Add Volume** → **Host Path Volume**

**Host Path:** `/var/run/docker.sock`

**Mount Path:** `/var/run/docker.sock`

**Note:** This gives the pod access to the host's Docker daemon. For production, consider using Kaniko or buildah instead.

#### Step 5: Save Configuration

Click **Save** at the bottom of the page.

---

### Verify Kubernetes Cloud Setup

#### Test Pod Creation

Create a simple test pipeline to verify pod spawning works:

1. **New Item** → Enter name: `k8s-pod-test` → **Pipeline** → **OK**

2. In Pipeline script, paste:

```groovy
pipeline {
    agent {
        kubernetes {
            label 'tools-agent'
            defaultContainer 'tools'
        }
    }
    
    stages {
        stage('Test') {
            steps {
                sh 'echo "Running in Kubernetes pod!"'
                sh 'kubectl version --client'
                sh 'helm version'
                sh 'python3 --version'
            }
        }
    }
}
```

3. Click **Build Now**

4. Watch the build - you should see:
   - Jenkins creates a pod named `jenkins-agent-xxxxx` in the `devops` namespace
   - Commands execute successfully
   - Pod is automatically deleted after completion

5. Verify in terminal:
```bash
kubectl get pods -n devops -w
```

You'll see the pod appear, run, and then terminate.

---

## 🏃 Running the Pipelines

### Pipeline 1: CI/CD Deployment Pipeline

**Location:** `Jenkins/CICD_Deploy_k8S/Jenkinsfile`

This is the main pipeline that:
1. Detects Kubernetes agent availability (with EC2 fallback)
2. Checks out code from GitHub
3. Runs TruffleHog for secrets detection
4. Performs quality checks (lint, security scan, unit tests)
5. Waits for manual deployment approval
6. Builds and pushes Docker image to Docker Hub
7. Creates Docker pull secret in Kubernetes
8. Deploys application using Helm

#### Create the Pipeline Job

1. **New Item** → Enter name: `deploy-to-k8s` → **Pipeline** → **OK**

2. **Pipeline Definition:** Pipeline script from SCM

3. **SCM:** Git

4. **Repository URL:** `https://github.com/Danielashkenazy/multi-stage-ci-cd-k8s.git`
   (Or your fork)

5. **Credentials:** Select your GitHub credentials (if private repo)

6. **Branch Specifier:** `*/main`

7. **Script Path:** `Jenkins/CICD_Deploy_k8S/Jenkinsfile`

8. **Save**

#### Run the Pipeline

1. Click **Build Now**

2. **Stage 1 - Detect K8s Availability:** 
   - Tries to connect to `tools-agent`
   - Falls back to EC2 if unavailable

3. **Stage 2 - Checkout:** Clones the repository

4. **Stage 3 - Secrets Detection:**
   - Runs on EC2 agent (requires Docker)
   - Scans code for hardcoded secrets using TruffleHog

5. **Stage 4 - Quality Checks:**
   - Runs on K8s pod or EC2 (depending on availability)
   - Creates Python venv
   - Linting with Flake8
   - Security scan with Bandit
   - Unit tests with Pytest
   - Publishes coverage report

6. **Stage 5 - Approve Deployment:**
   - ⏸️ Pipeline pauses here
   - Requires manual approval (click the blue button)
   - 10-minute timeout

7. **Stage 6 - Build & Push Docker Image:**
   - Runs on EC2 (requires Docker daemon access)
   - Builds image with tag `ci-<git-commit-sha>`
   - Pushes to Docker Hub

8. **Stage 7 - Create Docker Pull Secret:**
   - Creates `regcred` secret in `devops` namespace
   - Allows Kubernetes to pull private images

9. **Stage 8 - Deploy with Helm:**
   - Upgrades or installs the `python-app` release
   - Sets image tag to the newly built image
   - Waits for deployment to become ready

#### Monitor the Deployment

```bash
# Watch pods in devops namespace
kubectl get pods -n devops -w

# Check deployment status
kubectl get deployment python-app-rickandmorty -n devops

# View service
kubectl get svc python-app-rickandmorty -n devops

# Check ingress (ALB)
kubectl get ingress -n devops

# Get ALB DNS name
kubectl get ingress python-app-rickandmorty-ingress -n devops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

#### Test the Application

After deployment succeeds:

```bash
# Get the ALB DNS name
ALB_DNS=$(kubectl get ingress python-app-rickandmorty-ingress -n devops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl http://$ALB_DNS/health

# Test API endpoint
curl http://$ALB_DNS/api
```

Expected response:
```json
{
  "status": "ok"
}
```

---

### Pipeline 2: Control Replica Count

**Location:** `Jenkins/Control_K8s_Replica_Count/Jenkinsfile`

This pipeline allows you to dynamically scale the application by adjusting replica count and image tag.

#### Create the Pipeline

1. **New Item** → Name: `scale-application` → **Pipeline** → **OK**

2. **This project is parameterized:** ✅ Check

3. **Add Parameters:**

   **String Parameter 1:**
   - Name: `REPLICAS`
   - Default Value: `3`
   - Description: `Number of replicas`

   **String Parameter 2:**
   - Name: `IMAGE_TAG`
   - Default Value: `latest`
   - Description: `Docker image tag`

4. **Pipeline Definition:** Pipeline script from SCM

5. **Repository URL:** `https://github.com/Danielashkenazy/multi-stage-ci-cd-k8s.git`

6. **Script Path:** `Jenkins/Control_K8s_Replica_Count/Jenkinsfile`

7. **Save**

#### Run the Pipeline

1. Click **Build with Parameters**

2. Enter desired values:
   - **REPLICAS:** `5` (scale up to 5 pods)
   - **IMAGE_TAG:** `ci-abc123` (use specific build)

3. Click **Build**

4. Verify scaling:
```bash
kubectl get pods -n devops -l app=rickandmorty
# Should show 5 pods
```

**Note:** The HPA (Horizontal Pod Autoscaler) is also active and may override manual scaling based on CPU utilization (target: 70%).

---

### Pipeline 3: File Injection

**Location:** `Jenkins/File_Injection/Jenkinsfile`

This pipeline allows you to inject configuration files into running pods without redeploying.

#### Create the Pipeline

1. **New Item** → Name: `inject-config-file` → **Pipeline** → **OK**

2. **This project is parameterized:** ✅ Check

3. **Add Parameters:**

   **String Parameter 1:**
   - Name: `FILE_PATH`
   - Default Value: `Jenkins/example.txt`
   - Description: `Path to file in the repo`

   **String Parameter 2:**
   - Name: `TARGET_PATH`
   - Default Value: `/app/config/app-config.yaml`
   - Description: `Destination path inside the pod`

4. **Pipeline Definition:** Pipeline script from SCM

5. **Repository URL:** `https://github.com/Danielashkenazy/multi-stage-ci-cd-k8s.git`

6. **Script Path:** `Jenkins/File_Injection/Jenkinsfile`

7. **Save**

#### Use Case Example

Inject a new configuration file without restarting pods:

1. Add your config file to the repository: `config/new-settings.yaml`

2. Run pipeline with parameters:
   - **FILE_PATH:** `config/new-settings.yaml`
   - **TARGET_PATH:** `/app/config/settings.yaml`

3. Pipeline will:
   - Find a running pod with label `app=rickandmorty`
   - Copy the file from repo to pod
   - Verify the file exists inside the pod

4. Verify:
```bash
POD=$(kubectl get pod -n devops -l app=rickandmorty -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n devops $POD -- cat /app/config/settings.yaml
```

---

## 📊 Pipeline Descriptions

### Main CI/CD Pipeline Features

**Hybrid Agent Strategy:**
- Automatically detects if Kubernetes dynamic agents are available
- Falls back to EC2 static agent if K8s pods can't be spawned
- Optimizes resource usage by using K8s for lightweight tasks (tests, linting)
- Uses EC2 for Docker builds (requires Docker socket access)

**Quality Gates:**
1. **Secrets Detection (TruffleHog):**
   - Scans entire codebase for leaked credentials
   - Excludes virtual environments and build artifacts
   - Runs in Docker container for consistency

2. **Code Linting (Flake8):**
   - Enforces PEP 8 Python style guide
   - Catches syntax errors and code smells
   - Excludes virtual environments

3. **Security Scanning (Bandit):**
   - Identifies common security issues in Python code
   - Skips low-severity issues (B104, B113)
   - Generates reports for review

4. **Unit Testing (Pytest):**
   - Runs all tests in `test_*.py` files
   - Generates coverage reports (HTML + XML)
   - Publishes JUnit test results to Jenkins
   - Fails build if tests don't pass

**Deployment Strategy:**
- Uses Helm for declarative deployments
- Rolling updates with zero downtime
- Automatic rollback on failure
- Health checks via liveness probes

**Smart Agent Selection:**
```groovy
def USE_K8S = false

// Try K8s agent first
try {
    node('tools-agent') {
        sh "echo 'K8S works'"
    }
    USE_K8S = true
} catch (err) {
    USE_K8S = false  // Fallback to EC2
}

// Later in pipeline:
if (USE_K8S) {
    node('tools-agent') {
        container('tools') {
            // Run in K8s pod
        }
    }
} else {
    // Run on EC2 agent
}
```

---

## 📈 Monitoring & Observability

### Prometheus Metrics

Prometheus is deployed in the `monitoring` namespace and collects metrics from:
- Kubernetes nodes
- Application pods
- Jenkins (via Prometheus plugin)

#### Access Prometheus

```bash
# Port-forward to Prometheus server
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Open browser: http://localhost:9090
```

#### Useful Queries

**Pod CPU Usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="devops"}[5m])
```

**Pod Memory Usage:**
```promql
container_memory_usage_bytes{namespace="devops"} / 1024 / 1024
```

**HTTP Request Rate:**
```promql
rate(flask_http_request_total[5m])
```

### Application Logs

```bash
# View logs from all application pods
kubectl logs -n devops -l app=rickandmorty --tail=100 -f

# View logs from specific pod
kubectl logs -n devops <pod-name> -f

# View logs from previous crashed container
kubectl logs -n devops <pod-name> --previous
```

### Kubernetes Events

```bash
# Watch events in devops namespace
kubectl get events -n devops --watch

# Get events sorted by timestamp
kubectl get events -n devops --sort-by='.lastTimestamp'
```

---

## 🔒 Security Considerations

### Secrets Management

**Current Implementation:**
- Docker registry credentials stored as Jenkins credentials
- Kubernetes secrets for image pull (`regcred`)
- Service account tokens for API access

**Recommendations for Production:**
1. Use AWS Secrets Manager or HashiCorp Vault
2. Implement IRSA (IAM Roles for Service Accounts) for AWS API access
3. Rotate service account tokens regularly
4. Use encrypted secrets in etcd

### Network Security

**Implemented:**
- Security groups with least-privilege access
- Private subnets for workloads
- NAT Gateway for controlled outbound access
- Jenkins accessible only from allowed IP (variable `own_ip`)

**Recommendations:**
1. Enable VPC Flow Logs for traffic analysis
2. Implement WAF rules on ALB
3. Use AWS PrivateLink for AWS service access

### RBAC

**Current Service Account Permissions:**

The `jenkins-deployer` service account can:
- ✅ Create/delete/modify pods, services, deployments in `devops` namespace
- ✅ Execute commands in pods
- ✅ Manage secrets and configmaps


**Review RBAC:**
```bash
# Check what jenkins-deployer can do
kubectl auth can-i --list --as=system:serviceaccount:devops:jenkins-deployer -n devops

# Specific permission check
kubectl auth can-i delete deployment --as=system:serviceaccount:devops:jenkins-deployer -n devops
```

### Container Security

**Best Practices Applied:**
- ✅ Using official base images (Ubuntu 22.04, Python 3.11)
- ✅ Non-root user execution where possible
- ✅ Minimal attack surface in tools container

**Recommendations:**
1. Scan images with Trivy or Snyk
2. Use distroless or Alpine base images
3. Implement Pod Security Standards (PSS)
4. Set resource limits and quotas

---

Keep building! 🚀

---

## 📝 License

This project is open source and available under the MIT License.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

## 📧 Contact

Daniel Ashkenazy - [GitHub](https://github.com/Danielashkenazy)

---

## 🙏 Acknowledgments

- AWS EKS team for excellent managed Kubernetes
- Jenkins community for robust automation
- Terraform community for powerful IaC
- HashiCorp for amazing tooling

---

**Built with ❤️ and lots of ☕**

