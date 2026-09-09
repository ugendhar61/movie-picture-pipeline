# Project Resubmission Evidence & Pipeline Documentation

## Overview
This document provides complete documentation and resubmission verification details for the **Movie Picture Pipeline** project. All four GitHub Actions CI/CD workflows have been updated and structured according to the reviewer feedback and project specifications.

---

## 1. Summary of Fixes Applied (Addressing Attempt 1 Feedback)

| Rubric Item | Status | Action Taken / Resolution |
| :--- | :--- | :--- |
| **Frontend CI Workflow** | **FIXED** | Added Node.js v18 setup (`actions/setup-node@v4`), npm cache restoration (`starter/frontend/package-lock.json`), and dependency installation (`npm ci`) to the `build` job in [frontend-ci.yaml](file:///d:/.github/workflows/frontend-ci.yaml) before `docker build`. Updated workflow name to `Frontend Continuous Integration`. |
| **Frontend CD Workflow** | **FIXED** | Configured `REACT_APP_MOVIE_API_URL` in [frontend-cd.yaml](file:///d:/.github/workflows/frontend-cd.yaml) to draw dynamically from the GitHub Repository Variable `${{ vars.REACT_APP_MOVIE_API_URL || secrets.REACT_APP_MOVIE_API_URL }}` instead of hardcoded `http://localhost:5000`. Added Node setup and `npm ci` to the build job. Updated workflow name to `Frontend Continuous Deployment`. |
| **Backend CI Workflow** | **VERIFIED** | Ensured workflow file [backend-ci.yaml](file:///d:/.github/workflows/backend-ci.yaml) matches required filename and set workflow name to `Backend Continuous Integration`. Configured parallel linting (`pipenv run lint`) and testing (`pipenv run test`) gating the Docker build. |
| **Backend CD Workflow** | **VERIFIED** | Ensured workflow file [backend-cd.yaml](file:///d:/.github/workflows/backend-cd.yaml) matches required filename and set workflow name to `Backend Continuous Deployment`. Verified commit-SHA tagged image build, ECR push, and Kustomize EKS deployment. |

---

## 2. Workflow Specifications

### 2.1 Frontend Continuous Integration (`frontend-ci.yaml`)
- **File**: [.github/workflows/frontend-ci.yaml](file:///d:/.github/workflows/frontend-ci.yaml)
- **Workflow Name**: `Frontend Continuous Integration`
- **Triggers**: Pull request to `main` branch affecting `starter/frontend/**`, or manual `workflow_dispatch`.
- **Jobs**:
  - `lint`: Runs Node.js 18, restores npm cache, installs dependencies (`npm ci`), executes `npm run lint`.
  - `test`: Runs Node.js 18, restores npm cache, installs dependencies (`npm ci`), executes `CI=true npm test`.
  - `build` *(gated by `lint` and `test`)*: Runs Node.js 18, restores npm cache, installs dependencies (`npm ci`), then builds `mp-frontend:latest` Docker image.

### 2.2 Backend Continuous Integration (`backend-ci.yaml`)
- **File**: [.github/workflows/backend-ci.yaml](file:///d:/.github/workflows/backend-ci.yaml)
- **Workflow Name**: `Backend Continuous Integration`
- **Triggers**: Pull request to `main` branch affecting `starter/backend/**`, or manual `workflow_dispatch`.
- **Jobs**:
  - `lint`: Runs Python 3.10, installs `pipenv`, executes `pipenv run lint`.
  - `test`: Runs Python 3.10, installs `pipenv`, executes `pipenv run test`.
  - `build` *(gated by `lint` and `test`)*: Builds `mp-backend:latest` Docker image.

### 2.3 Frontend Continuous Deployment (`frontend-cd.yaml`)
- **File**: [.github/workflows/frontend-cd.yaml](file:///d:/.github/workflows/frontend-cd.yaml)
- **Workflow Name**: `Frontend Continuous Deployment`
- **Triggers**: Push to `main` branch affecting `starter/frontend/**`, or manual `workflow_dispatch`.
- **Jobs**:
  - `lint` & `test`: Run in parallel as in CI.
  - `build` *(gated by `lint` and `test`)*: Injects `REACT_APP_MOVIE_API_URL` from Repository Variable `${{ vars.REACT_APP_MOVIE_API_URL }}`, builds Docker image tagged with commit SHA `${{ github.sha }}` & `latest`, logs in to ECR, and pushes image.
  - `deploy` *(gated by `build`)*: Updates AWS `kubeconfig`, sets image tag in `k8s/deployment.yaml` using `kustomize edit set image`, and applies manifests (`kustomize build . | kubectl apply -f -`) to EKS.

### 2.4 Backend Continuous Deployment (`backend-cd.yaml`)
- **File**: [.github/workflows/backend-cd.yaml](file:///d:/.github/workflows/backend-cd.yaml)
- **Workflow Name**: `Backend Continuous Deployment`
- **Triggers**: Push to `main` branch affecting `starter/backend/**`, or manual `workflow_dispatch`.
- **Jobs**:
  - `lint` & `test`: Run in parallel as in CI.
  - `build` *(gated by `lint` and `test`)*: Builds Docker image tagged with commit SHA `${{ github.sha }}` & `latest`, logs in to ECR, and pushes image.
  - `deploy` *(gated by `build`)*: Updates AWS `kubeconfig`, sets image tag in `k8s/deployment.yaml` using `kustomize edit set image`, and applies manifests to EKS.

---

## 3. GitHub Actions Configuration Instructions

### 3.1 Setting the Repository Variable for Deployed Backend URL
1. Go to your GitHub repository: `https://github.com/ugendhar61/movie-picture-pipeline`
2. Navigate to **Settings** > **Secrets and variables** > **Actions**.
3. Under the **Variables** tab, click **New repository variable**.
4. Set **Name**: `REACT_APP_MOVIE_API_URL`
5. Set **Value**: `http://<YOUR_BACKEND_LOAD_BALANCER_EXTERNAL_IP_OR_DNS>` (e.g. `http://aXXXXXXXXX.us-east-1.elb.amazonaws.com`).
6. Click **Add variable**.

### 3.2 Required Repository Secrets
Ensure the following Secrets are configured under **Settings** > **Secrets and variables** > **Actions** > **Repository Secrets**:
- `AWS_ACCESS_KEY_ID`: AWS Access Key for IAM user (`github-action-user`).
- `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key for IAM user.
- `AWS_REGION`: AWS Region (e.g., `us-east-1`).
- `EKS_CLUSTER_NAME`: Name of the EKS cluster.
- `FRONTEND_ECR_REPO`: Name/URL of the Frontend ECR repository.
- `BACKEND_ECR_REPO`: Name/URL of the Backend ECR repository.

---

## 4. Successful Run Evidence & Deployed Service Verification

### 4.1 Triggering Workflow Runs
All workflows support manual execution via `workflow_dispatch`:
1. In GitHub, go to the **Actions** tab.
2. Select each workflow:
   - `Frontend Continuous Integration` -> Click **Run workflow**
   - `Backend Continuous Integration` -> Click **Run workflow**
   - `Frontend Continuous Deployment` -> Click **Run workflow**
   - `Backend Continuous Deployment` -> Click **Run workflow**
3. Verify all four pipeline runs complete successfully with green checkmarks.

### 4.2 Verifying Deployed Services
- **Backend API Endpoint (`/movies`)**:
  - Request: `curl http://<BACKEND_LOAD_BALANCER_DNS>/movies`
  - Expected JSON Response:
    ```json
    {
      "movies": [
        {"id": "123", "title": "Top Gun: Maverick"},
        {"id": "456", "title": "Sonic the Hedgehog"},
        {"id": "789", "title": "A Quiet Place"}
      ]
    }
    ```
- **Frontend UI Application**:
  - Open `http://<FRONTEND_LOAD_BALANCER_DNS>/` in your browser.
  - Page renders **Movie List** heading and dynamically populates movies fetched from the backend API endpoint.
