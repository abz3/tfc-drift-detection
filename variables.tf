variable "addr_space" {
  description = "address space for cidr_block of virtual private cloud"
  default     = "10.0.0.0/16"
}

variable "addr_subnet" {
  description = "address space for cidr_block of subnet"
  default     = "10.0.10.0/24"
}

variable "ami_id" {
  description = "Amazon machine image id"
  default     = ""
}