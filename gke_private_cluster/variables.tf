variable "project_id" {
  description = "The project_id to use"
  type        = string
}

variable "region" {
  description = "Region to set as default"
  type        = string
  default     = "europe-west3"
}

variable "tunnel_user" {
  description = "IAM identities that are allowed to use IAP tunneling"
  type        = list(string)
  default     = []
}
