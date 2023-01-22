
#========================================================
# common
#========================================================

variable "project_id_main" {
  description = "main project id"
}

variable "project_id_service" {
  description = "service project id"
}

variable "machine_type" {
  description = "vm instance size"
  type        = string
  default     = "e2-micro"
}

variable "image_debian" {
  description = "vm instance image"
  type        = string
  default     = "debian-cloud/debian-10"
}

variable "image_ubuntu" {
  description = "vm instance image"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-1804-lts"
}

variable "image_cos" {
  description = "container optimized image"
  type        = string
  default     = "cos-cloud/cos-stable"
}

variable "disk_type" {
  description = "disk type"
  type        = string
  default     = "pd-ssd"
}

variable "disk_size" {
  description = "disk size"
  type        = string
  default     = "10"
}

variable "shielded_config" {
  description = "Shielded VM configuration of the instances."
  default = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}
/*
#========================================================
# onprem
#========================================================

variable "onprem_asn" {
  description = "onprem asn"
  type        = string
  default     = "65010"
}


#========================================================
# vpc1
#========================================================

variable "vpc1_asn" {
  description = "vpc1 asn"
  type        = string
  default     = "65001"
}


#========================================================
# vpc2
#========================================================

variable "vpc2_asn" {
  description = "vpc2 asn"
  type        = string
  default     = "65002"
}

variable "vpc2_subnets" {
  description = "vpc2 supernet"
  type        = string
  default     =  = "10.20.0.0/16"
}


#========================================================
# vpc3
#========================================================

variable "vpc3_asn" {
  description = "vpc3 asn"
  type        = string
  default     = "65003"
}

variable "vpc3_subnets" {
  description = "vpc2 supernet"
  type        = string
  default     =  = "10.30.0.0/16"
}


#========================================================
# vpc4
#========================================================

variable "vpc4_asn" {
  description = "vpc4 asn"
  type        = string
  default     = "65004"
}
*/
