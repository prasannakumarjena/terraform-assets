resource "aws_launch_configuration" "kubernetes-minions-4xlarge" {
  image_id = "${lookup(var.amis, var.region)}"
  instance_type = "${var.instance_class}.4xlarge"
  associate_public_ip_address = true
  ebs_optimized = true
  key_name = "${var.ssh_key_name}"
  security_groups = ["${aws_security_group.kubernetes_sg.id}"]
  user_data = "${file("./minion_userdata.tpl")}"
  iam_instance_profile = "kubernetes-minion"
  root_block_device {
    volume_type = "gp2"
    volume_size = 100
  }
  ebs_block_device = {
    device_name = "/dev/xvdb"
    volume_type = "gp2"
    volume_size = 80
    delete_on_termination = true
  }
  connection {
    user = "ubuntu"
    agent = true
  }
}

resource "aws_autoscaling_group" "kubernetes-minions-4xlarge" {
  vpc_zone_identifier = ["${aws_subnet.public.id}"]
  name = "${var.cluster_id}-4xlarge"
  max_size = 0
  min_size = 0
  desired_capacity = 0
  health_check_grace_period = 100
  health_check_type = "EC2"
  force_delete = false
  launch_configuration = "${aws_launch_configuration.kubernetes-minions-4xlarge.name}"
  tag {
    key = "Name"
    value = "${var.cluster_id}-minion"
    propagate_at_launch = true
  }
  tag {
    key = "KubernetesCluster"
    value = "${var.cluster_id}"
    propagate_at_launch = true
  }
  tag {
    key = "Role"
    value = "${var.cluster_id}-minion"
    propagate_at_launch = true
  }
  depends_on = ["aws_launch_configuration.kubernetes-minions-4xlarge", "aws_instance.kube_master"]
 }
