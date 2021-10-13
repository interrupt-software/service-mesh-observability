variable "key_name" {
  default = "interrupt-tmp-key"
}

variable "tags" {
  type = map(any)

  default = {
    Organization = "Solutions Engineering"
    DoNotDelete  = "True"
    Keep         = "True"
    Owner        = "Gilberto Castillo"
    Region       = "US-EAST-2"
    Purpose      = "Grafana Demo, Oct 12, 2021"
    TTL          = "168"
    Terraform    = "true"
  }
}
