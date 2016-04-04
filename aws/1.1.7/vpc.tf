resource "aws_vpc" "kube_cluster" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_support  = true
    enable_dns_hostnames  = true

    tags {
        Name = "kubernetes-vpc"
        KubernetesCluster = "${var.cluster_id}"
    }
}

resource "aws_internet_gateway" "default" {
    vpc_id = "${aws_vpc.kube_cluster.id}"
}
