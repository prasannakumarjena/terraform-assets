
resource "template_file" "master_user_data" {
    template = "${file("master_userdata.tpl")}"
    vars {
      cluster_id = "${var.cluster_id}"
      availability_zone = "${var.availability_zone}"
      s3_bucket = "${var.s3_bucket}"
    }
}

resource "aws_instance" "kube_master" {
  ami = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_class}.large"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.public.id}"
  private_ip = "172.20.0.9"
  user_data = "${template_file.master_user_data.rendered}"
  key_name = "${var.ssh_key_name}"
  vpc_security_group_ids = ["${aws_security_group.kubernetes_sg.id}"]
  iam_instance_profile = "kubernetes-master"
  ebs_block_device = {
    device_name = "/dev/xvdb"
    volume_type = "gp2"
    volume_size = 20
    delete_on_termination = true
  }
  tags {
    KubernetesCluster = "${var.cluster_id}"
    Name = "${var.cluster_id}-master"
    Role = "${var.cluster_id}-master"
  }
}
