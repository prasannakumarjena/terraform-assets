resource "aws_security_group" "kubernetes_sg" {
    name = "${var.cluster_id}_sg"
    description = "Allow traffic to pass over any port internal to the VPC"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 30000
        to_port = 40000
        protocol = "tcp"
        cidr_blocks = ["${aws_security_group.elb_sg.id}"]
    }

    ingress {
        from_port = 10250
        to_port = 10250
        protocol = "tcp"
        cidr_blocks = ["${aws_security_group.elb_sg.id}"]
    }

    vpc_id = "${aws_vpc.kube_cluster.id}"

    tags {
        KubernetesCluster = "${var.cluster_id}"
    }
}

resource "aws_security_group" "elb_sg" {
    name = "${var.cluster_id}_elb_sg"
    description = "Allow traffic to pass over any port internal to the VPC"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 30000
        to_port = 40000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 10250
        to_port = 10250
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    vpc_id = "${aws_vpc.kube_cluster.id}"

    tags {
        KubernetesCluster = "${var.cluster_id}"
    }
}
