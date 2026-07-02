variable "instance_type" {
  description = "Instance type for ec2 instance"
  type        = string
  default     = "c7i-flex.large"
}

variable "instance_name" {
  description = "name of the ec2 instance"
  type        = string
  default     = "ci-platform-server"
}

variable "github_app_id" {
  description = "App id given when creating github app"
  type        = string
}

variable "github_app_installation_id" {
  description = "Installation id given at the end of the app url"
  type        = string
}

variable "ssh_public_key" {
  type = string
}