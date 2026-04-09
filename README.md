# az-deployment

End-to-end Azure deployment demonstrating AKS with Workload Identity, a private ACR, hub-spoke networking, and a GitHub Actions CI/CD pipeline. All infrastructure is managed with Terraform, the app is deployed via a Helm chart stored in ACR, and the application itself is a Python Flask service.

---

## Repository layout

```
.
├── infra/               # Terraform — Azure infrastructure
├── app/                 # Python app + Dockerfile
├── helm/get-acr/        # Helm chart pushed to ACR as an OCI artifact
└── .github/workflows/   # GitHub Actions CI/CD pipeline
```

---

## infra/ — Terraform

Provisions all Azure resources in a single resource group (`rg-az-deployment`).

| File | What it creates |
|---|---|
| `providers.tf` | AzureRM provider pin |
| `variables.tf` | Input variables (location, SSH public key, etc.) |
| `rg.tf` | Resource group |
| `vnet.tf` | Hub VNet + Spoke VNet + bidirectional peering; `jump-subnet`, `aks-subnet`, `apiserver-subnet` |
| `vm.tf` | Jump VM in `jump-subnet` — public IP, SSH open (no source restriction), Ubuntu 22.04 |
| `aks.tf` | AKS cluster `hsunaks` — private cluster, API-server VNet integration into `apiserver-subnet`, CNI Overlay, Workload Identity, 3 nodepools (`agent` / `app` / `gh`, 2 nodes each, manual scale) |
| `acr.tf` | ACR `hsunacr` (Premium), private endpoint in `aks-subnet`, private DNS zones linked to both VNets |
| `identity.tf` | User-assigned MI `app` — `AcrPull` on ACR + `Reader` on RG + federated credential binding `serviceaccount:app/app` |
| `outputs.tf` | Useful outputs (AKS name, ACR login server, jump IP, app MI client ID, OIDC issuer URL) |

### Usage

```bash
cd infra
terraform init
terraform apply \
  -var="jump_vm_ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
```

Copy `app_mi_client_id` from the output — it is required for the Helm release.

---

## app/ — Python + Docker

`app.py` is a Flask application that:

- **`GET /healthz`** — Lists all repositories in ACR using the Azure Container Registry SDK with Workload Identity (`DefaultAzureCredential`). Returns `200` and the repository list on success, or the upstream HTTP status code and error body on failure.
- **Background thread** — Appends `[timestamp] | Hello` to `/log/log.csv` every 20 seconds.

`/log` is created in the `Dockerfile` with `RUN mkdir -p /log` so the Azure File PVC mount point always exists.

### Build locally

```bash
cd app
docker build -t app:dev .
```

### Dependencies (`requirements.txt`)

- `flask` — HTTP server
- `azure-containerregistry` — ACR SDK
- `azure-identity` — Workload Identity via `DefaultAzureCredential`

---

## helm/get-acr/ — Helm chart

Stored in ACR as an OCI artifact (`oci://hsunacr.azurecr.io/helm/get-acr`).

| Template | What it creates |
|---|---|
| `namespace.yaml` | Namespace `app` |
| `serviceaccount.yaml` | ServiceAccount `app` in namespace `app`, annotated with the app MI client ID for Workload Identity |
| `pvc.yaml` | `ReadWriteMany` Azure File PVC (`azurefile-csi`) mounted at `/log` |
| `deployment.yaml` | Deployment `app` — 1 replica, scheduled on the `app` nodepool, `serviceAccountName: app` |

### Key values (`values.yaml`)

| Key | Description |
|---|---|
| `workloadIdentity.clientId` | Client ID of the `app` managed identity (from Terraform output `app_mi_client_id`) |
| `image.repository` / `image.tag` | Container image in ACR |
| `acrUrl` | Full ACR URL passed as `ACR_URL` env var to the app |

### Install manually

```bash
helm upgrade --install get-acr \
  oci://hsunacr.azurecr.io/helm/get-acr \
  --namespace app --create-namespace \
  --set workloadIdentity.clientId=<app_mi_client_id>
```

---

## .github/workflows/deploy.yaml — CI/CD

Runs on push to `main` using the self-hosted `gh` AKS nodepool (actions-runner-controller).

**Steps:**
1. **Azure login** via GitHub App (federated OIDC — no long-lived secrets).
2. **Build + push image** — `az acr build` sends the `app/` context to ACR and tags with both `<sha>` and `latest`.
3. **Push Helm chart** — `helm package` + `helm push` to `oci://hsunacr.azurecr.io/helm`.
4. **Set AKS context** — fetches kubeconfig for `hsunaks`.
5. **Helm upgrade** — installs or upgrades the `get-acr` release, pinned to the commit SHA image tag.

### Required GitHub secrets

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | GitHub App / App registration client ID |
| `AZURE_TENANT_ID` | Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `APP_MI_CLIENT_ID` | `app_mi_client_id` from Terraform output |

---

## Network architecture

```
Internet
    │
    ▼
jump VM (hub-vnet / jump-subnet) ──────────── public IP (SSH)
    │
    │  VNet peering
    ▼
spoke-vnet
  ├── aks-subnet        AKS nodes + ACR private endpoint
  └── apiserver-subnet  AKS API server (VNet integration, private cluster)
```

The `gh` nodepool pods (GitHub Actions runners) reach the private API server through the `apiserver-subnet` route inside the spoke VNet. The jump VM reaches it via the hub-to-spoke VNet peering. No NSG restrictions are applied at this stage.
