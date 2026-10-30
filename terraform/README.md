# Terraform

One virtual machine per environment runs the Compose stack. Dev, UAT, and production each have their own resource group, their own state, and their own apply. The module in `modules/stack` is the same one every time. The differences are `environments/dev.tfvars`, `environments/uat.tfvars`, and `environments/prod.tfvars`.

Terraform does not create the resource group and does not delete it. Create these empty groups before the first apply, or change the names in the tfvars to groups you already have:

| Environment | Resource group | Branch that applies it |
| --- | --- | --- |
| dev | `rg-shared-infra-dev` | `dev` |
| uat | `rg-shared-infra-uat` | `uat` |
| prod | `rg-shared-infra-prod` | `main` |

A pull request from a collaborator plans that environment. A merge into the branch applies it. Format and validate run on every pull request. Apply runs in GitHub Actions, not on a laptop.

## Sizes

Dev is the smallest size that still has the 32 GiB the stack needs. UAT sits between dev and production. Production is the full size.

| | dev | uat | prod |
| --- | --- | --- | --- |
| Virtual machine | `Standard_E4s_v5` (4 vCPU, 32 GiB) | `Standard_D8s_v5` (8 vCPU, 32 GiB) | `Standard_E8s_v5` (8 vCPU, 64 GiB) |
| Data disk | 256 GiB | 512 GiB | 1024 GiB |
| Registry | Basic | Standard | Premium, zone redundant |
| Backup | 7 daily copies, local | 14 daily copies, local | 30 daily copies, geo-redundant |
| Log storage | LRS | LRS | GRS |
| Key Vault | 7-day soft delete | 7-day soft delete | 90-day soft delete and purge protection |
| Night window | 20:00 to 08:00 UTC | 20:00 to 08:00 UTC | stays on |
| Monthly budget | 200 USD | 400 USD | 800 USD |

Change `operator_cidrs`, `alert_email`, `timezone`, and `monthly_budget_usd` in the tfvars before the first apply. Replace `203.0.113.10/32` with your public address. The budget warns at 80 percent and again at 100 percent.

`acr_zone_redundancy` on production needs a region with availability zones. Turn it off in `prod.tfvars` when the resource group is somewhere else.

## What the apply creates

Inside the resource group:

- A virtual network, a subnet, a network security group, a public IP, and one Ubuntu 24.04 virtual machine.
- A data disk mounted at `/var/lib/docker`. Replacing the virtual machine reattaches this disk.
- A storage account, the `app-logs` queue, and the `app-logs-poison` queue.
- A container registry. The registry username and password go to Key Vault and to the GitHub environment.
- Key Vault, with the storage connection string, the registry password, and the SSH private key.
- A user-assigned identity on the virtual machine. It can read those secrets, pull from the registry, and use the queue.
- Log Analytics, an action group, a virtual-machine availability alert, and storage availability and server-error alerts.
- A daily backup of the virtual machine, including the data disk.
- A monthly budget on the resource group.
- On dev and UAT, a stop at 20:00 and a Logic App that starts the machine at 08:00. Production has neither.
- An app registration whose federated credential trusts `https://token.actions.githubusercontent.com` for this repository and that environment's branch. A second credential trusts pull requests so a plan can sign in.

GitHub environments `dev`, `uat`, and `prod` receive `AZURE_STORAGE_CONNECTION_STRING`, `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, and `VM_SSH_PRIVATE_KEY`.

## The virtual machine

Cloud-init starts `shared-infra-boot.service`. The service waits for the data disk, formats it once, installs Docker, clones this repository, reads the connection string from Key Vault, and runs `scripts/up.sh`. Passwords for Grafana and the other UIs are generated on the machine by `scripts/init-env.sh`. Read them with `scripts/print-credentials.sh` after you SSH in.

The clone uses the branch that applies the environment (`dev`, `uat`, or `main`). Create `dev` and `uat` from `main` before the first apply of those environments.

A change to the boot script replaces the virtual machine. The data disk stays.

## Sign-in

The workflow signs in with OpenID Connect.

Set these repository variables before the first run:

- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID_DEV`
- `AZURE_CLIENT_ID_UAT`
- `AZURE_CLIENT_ID_PROD`

The first value of each client id is an identity that can already sign in from that branch. It needs permission to register applications, to assign the Application Administrator directory role, and Owner on that resource group. The apply creates the app this environment keeps. The output `github_client_id` is the client id to put in `AZURE_CLIENT_ID_<ENV>` for the next run.

That app is Application Administrator in the tenant so the next plan can read its own registration. It is Contributor and User Access Administrator on the resource group. The directory role is tenant wide.

## State

`terraform/bootstrap` creates a storage account in the same resource group and a private container named `tfstate`. Blob versioning and 30 days of soft delete are on. Production state is geo-redundant. Dev and UAT state are locally redundant. The workflow runs `terraform/init.sh`, which creates that account on the first run and then points this root at it. The state lock is the Azure blob lease.
