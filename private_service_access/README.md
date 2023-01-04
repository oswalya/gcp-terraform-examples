# Example private service access

This is an example terraform code snippet that will setup private service access with multiple IP ranges attached.

```terraform
terraform init \
terraform apply -var project=<my-project-id>
```

<!-- BEGIN_TF_DOCS -->
## Documentation with terraform-docs

Terraform documentation automated with: [terraform-docs](https://github.com/terraform-docs/terraform-docs)
Configuration: [config file](../.terraform-docs.yml)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.2, < 2 |
| google | 4.47.0 |
| google-beta | 4.47.0 |

## Providers

| Name | Version |
|------|---------|
| google | 4.47.0 |
| random | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_compute_global_address.private_ip_alloc_1](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/compute_global_address) | resource |
| [google_compute_global_address.private_ip_alloc_2](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/compute_global_address) | resource |
| [google_compute_network.default](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/compute_network) | resource |
| [google_compute_network_peering_routes_config.peering_routes](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/compute_network_peering_routes_config) | resource |
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/compute_subnetwork) | resource |
| [google_service_networking_connection.default](https://registry.terraform.io/providers/hashicorp/google/4.47.0/docs/resources/service_networking_connection) | resource |
| [random_id.default](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project | The project to use | `string` | n/a | yes |
| region | Region to set as default | `string` | `"europe-west3"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->