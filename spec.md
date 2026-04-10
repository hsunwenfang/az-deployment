

# Infra

1. Github action (Gact)
    - GH account name : hsunwenfang
    - use the AKS gh agentpool as the self-hosted agent
    - use runner pod action runner
    - auth with Github App
2. Azure Vnet (Vnet)
    - spoke-vnet
        - aks-subnet
    - hub-vnet
        - jump-subnet
            - Azure vm named jump with opened ssh (no access restriction) with private key and public ip for aks control
    - spoke-vnet peers hub-vnet
3. Azure Kubernetes Services (AKS)
    - name : hsunaks
    - nodepools with 2 nodes per nodepool
        - 3 nodepools : agent, app, gh
        - manual scale
    - api-server vnet integration + private cluster
        - gh nodepool can reach api-server by inside subnet route
    - hub-spoke architect
        - hub can access api-server via vnet connection
        - donot block anything yet
    - network plugin == CNI overlay
    - enables Workload Identity
3. Azure Container Registry (ACR)
    - name : hsunacr
    - private endpoint in aks-subnet to serve AKS
    - Host container images and helm chart
4. Azure Identity
    - user-assigned MI named app used by app.py with service account and used by AKS for imagepull
    - With role Reader and AcrPull so imagepull and list repo are both OK

# Code and Manifest

1. app.py
    - returns 200 and repository list of ACR on /healthz if it can list acr repositories with az python sdk + workload identity
    - /healthz endpoint should return the ACR error response body/status code on failure
    - write "[timestamps] | Hello" every 20 secs to /log/log.csv
2. Deployment named app
    - scheduled on app nodepool
    - ns == app
    - serviceaccount:app:app
    - 1 replicas with app.py in the container image
    - mount a azure file pvc at /log for app.py to write logs (/log created in Dockerfile so mount always succeeds)
    - stores in helm chart named get-acr in ACR with oci:// 
