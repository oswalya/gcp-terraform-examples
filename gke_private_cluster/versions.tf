terraform {
  required_version = ">= 1.0.2, < 2"
  required_providers {
    google = {
      version = "~> 4.47"
    }
    google-beta = {
      version = "~> 4.47"
    }
  }
}
