variable "instance_type" {
  description = "Instance type for ec2 instance"
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "name of the ec2 instance"
  type        = string
  default     = "ci-platform-server"
}