variable "aws_region" {
  default = "us-east-2"
}

variable "vpc_cidr" {
  default = "10.20.0.0/16"
}

variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(string)
  default = ["10.20.3.0/24", "10.20.4.0/24"]
}

variable "azs" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b"]
}

variable "instance_type" {
  default = "t3.micro"
}

variable "volume_size" {
  default = "10"
}

