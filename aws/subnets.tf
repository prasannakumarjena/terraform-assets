resource "aws_subnet" "public" {
	vpc_id            = "${aws_vpc.kube_cluster.id}"
	cidr_block        = "${var.public_subnet_cidr}"
	availability_zone = "${var.availability_zone}"

	tags {
		KubernetesCluster = "${var.cluster_id}"
	}
}

resource "aws_route_table" "public" {
	vpc_id = "${aws_vpc.kube_cluster.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}
  route {
    cidr_block = "10.246.0.0/24"
    instance_id = "${aws_instance.kube_master.id}"
  }

	tags {
		KubernetesCluster = "${var.cluster_id}"
	}
}

resource "aws_route_table_association" "public" {
	subnet_id      = "${aws_subnet.public.id}"
	route_table_id = "${aws_route_table.public.id}"
}
