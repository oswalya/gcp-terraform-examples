# Example GKE private cluster

This example creates a fully private GKE cluster with private nodes and private master access.
In order to get access to this sample setup following components will also be setup:

- Cloud NAT
- Bastion Host
- IAP
- OSLogin
- Private VPC
- FW rules

Some of the modules used in this example are in use to simplify the code and understand the required workflows easier. I tried to avoid to use too much features of a module and just use it for plain installation purposes. Instead the resources are within this example.
In a real world scenario the used google modules can also roll out permissions and further configurations like VPC and FW. Its up to you to decide if you want to use full blown template modules or not.

## Precondition

This will not setup the project itself nor any guardrails / policies on the organizational part. This needs to be in place beforehand.

## Installation

```bash
terraform apply -var project_id=<YOUR_PROJECT_ID> --auto-approve
```

NOTE: if you are not the OWNER of the project you apply this code and use least privilege access (recommended if not on a playground) you need to specify the variable for `tunnel_user` as well as this will set required permissions for tunneling.

After the successfull rollout of the TF code you should be able to use IAP tunneling to connect to the bastion host.

```bash
gcloud compute ssh --zone "europe-west3-a" "<BASTION_NAME>"  --tunnel-through-iap --project "<YOUR_PROJECT_ID>"
```

<!-- BEGIN_TF_DOCS -->
## Documentation with terraform-docs

Terraform documentation automated with: [terraform-docs](https://github.com/terraform-docs/terraform-docs)
Configuration: [config file](../.terraform-docs.yml)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.2, < 2 |
| google | ~> 4.47 |
| google-beta | ~> 4.47 |

## Providers

| Name | Version |
|------|---------|
| google | 4.47.0 |
| random | 3.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| gke | terraform-google-modules/kubernetes-engine/google//modules/beta-private-cluster | n/a |
| instance\_template | terraform-google-modules/vm/google//modules/instance_template | n/a |

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.allow_from_iap_to_instances](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.intra_egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.master_webhooks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_instance_from_template.tunnelvm](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_from_template) | resource |
| [google_compute_network.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_iap_tunnel_instance_iam_binding.enable_iap](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam_binding) | resource |
| [google_project_iam_member.cluster_service_account-artifact-registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_service_account-gcr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_service_account-log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_service_account-metric_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_service_account-monitoring_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.cluster_service_account-resourceMetadata-writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.os_login_bindings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_service_account.bastion_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.cluster_service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.bastion_service_account_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project\_id | The project\_id to use | `string` | n/a | yes |
| region | Region to set as default | `string` | `"europe-west3"` | no |
| tunnel\_user | IAM identities that are allowed to use IAP tunneling | `list(string)` | `[]` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->