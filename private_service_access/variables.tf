variable "project" {
  description = "The project to use"
  type        = string
}

variable "region" {
  description = "Region to set as default"
  type        = string
  default     = "europe-west3"
}
