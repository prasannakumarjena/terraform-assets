variable "region" {}
variable "amis" {
  default = {}
}
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "cluster_id" {}
variable "kube_user" {}
variable "kube_pass" {}
variable "ssh_key_name" {
  default = "gossamer-kube-admin"
}
variable "instance_class" {
  default = "m4"
}
variable "vpc_cidr" {
  default = "172.20.0.0/16"
}
variable "public_subnet_cidr" {
  default = "172.20.0.0/24"
}
variable "availability_zone" {}
variable "s3_bucket" {
  default = "kubernetes-1-1-7-artifacts"
}
