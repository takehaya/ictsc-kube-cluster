terraform {
  required_version = ">= 0.12.5"
}

# ubuntu archive
data sakuracloud_archive "ubuntu-archive" {
  os_type = "ubuntu"
}

# pub key
resource sakuracloud_ssh_key_gen "key" {
  name = "k8s_pubkey"

  provisioner "local-exec" {
    command = "echo \"${self.private_key}\" > id_rsa; chmod 0600 id_rsa"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -f id_rsa"
  }
}

// # VPCルータ本体の定義(スタンダードプランの場合)
resource sakuracloud_vpc_router "vpc-router" {
  name = "vpc-router"
  plan = "standard"

}
resource sakuracloud_switch "external-switch" {
  name = "external-switch"
}

resource sakuracloud_vpc_router_interface "eth1" {
  vpc_router_id = "${sakuracloud_vpc_router.vpc-router.id}"
  index         = 1
  switch_id     = "${sakuracloud_switch.external-switch.id}"
  ipaddress     = ["172.20.100.1"]
  nw_mask_len   = 24
}

resource sakuracloud_switch "k8s-internal-switch" {
  name = "k8s-internal-switch"
}

# disks
resource sakuracloud_disk "k8s-master-disk" {
  count             = "${lookup(var.master, terraform.workspace)}"
  name              = "k8s-master-${count.index + 1}-${terraform.workspace}"
  source_archive_id = "${data.sakuracloud_archive.ubuntu-archive.id}"
  size              = tonumber("${lookup(var.master_disk, terraform.workspace)}")
  tags              = ["k8s", "${terraform.workspace}"]
}

resource sakuracloud_disk "k8s-node-disk" {
  count             = "${lookup(var.node, terraform.workspace)}"
  name              = "k8s-node-${count.index + 1}-${terraform.workspace}"
  source_archive_id = "${data.sakuracloud_archive.ubuntu-archive.id}"
  size              = tonumber("${lookup(var.node_disk, terraform.workspace)}")
  tags              = ["k8s", "${terraform.workspace}"]
}

resource sakuracloud_disk "k8s-lb-disk" {
  count             = "${lookup(var.lb, terraform.workspace)}"
  name              = "k8s-lb-${count.index + 1}-${terraform.workspace}"
  source_archive_id = "${data.sakuracloud_archive.ubuntu-archive.id}"
  size              = tonumber("${lookup(var.lb_disk, terraform.workspace)}")
  tags              = ["k8s", "${terraform.workspace}"]
}
# servers
resource sakuracloud_server "k8s-master-server" {
  count                          = "${lookup(var.master, terraform.workspace)}"
  name                           = "k8s-master-${count.index + 1}-server-${terraform.workspace}"
  hostname                       = "k8s-master-${count.index + 1}-server-${terraform.workspace}"
  core                           = "${lookup(var.master_cpu, terraform.workspace)}"
  memory                         = "${lookup(var.master_mem, terraform.workspace)}"
  disks                          = ["${sakuracloud_disk.k8s-master-disk[count.index].id}"]
  nic                            = "${sakuracloud_switch.external-switch.id}"
  additional_nics                = ["${sakuracloud_switch.k8s-internal-switch.id}"]
  additional_display_ipaddresses = ["192.168.100.1${count.index}"]
  ssh_key_ids                    = ["${sakuracloud_ssh_key_gen.key.id}"]
  password                       = "PUT_YOUR_PASSWORD_HERE"
  tags                           = ["k8s", "${terraform.workspace}"]
  ipaddress                      = "172.20.100.1${count.index}"
  gateway                        = "${sakuracloud_vpc_router_interface.eth1.ipaddress[0]}"
  nw_mask_len                    = "24"
  disable_pw_auth                = true
  // connection {
  //   type        = "ssh"
  //   user        = "ubuntu"
  //   host        = "${sakuracloud_vpc_router.vpc-router.global_address}"
  //   port        = "1010${count.index}"
  //   private_key = "${sakuracloud_ssh_key_gen.key.private_key}"
  // }
  // provisioner "remote-exec" {
  //   # write password mean for the sake of ansible used
  //   # todo: must better use cloudinit or packer initialize.
  //   inline = [
  //     "echo ${self.password} |sudo -S sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config",
  //     "sudo systemctl restart sshd.service",
  //     "echo Success",
  //     "sudo ip link set eth1 up",
  //     "sudo ip addr add ${self.additional_display_ipaddresses[0]}/24 dev eth1"
  //   ]
  // }
}

resource sakuracloud_server "k8s-node-server" {
  count                          = "${lookup(var.node, terraform.workspace)}"
  name                           = "k8s-node-${count.index + 1}-server-${terraform.workspace}"
  hostname                       = "k8s-node-${count.index + 1}-server-${terraform.workspace}"
  core                           = "${lookup(var.node_cpu, terraform.workspace)}"
  memory                         = "${lookup(var.node_mem, terraform.workspace)}"
  disks                          = ["${sakuracloud_disk.k8s-node-disk[count.index].id}"]
  nic                            = "${sakuracloud_switch.external-switch.id}"
  additional_nics                = ["${sakuracloud_switch.k8s-internal-switch.id}"]
  additional_display_ipaddresses = ["192.168.100.2${count.index}"]
  ssh_key_ids                    = ["${sakuracloud_ssh_key_gen.key.id}"]
  password                       = "PUT_YOUR_PASSWORD_HERE"
  tags                           = ["k8s", "${terraform.workspace}"]
  ipaddress                      = "172.20.100.2${count.index}"
  gateway                        = "${sakuracloud_vpc_router_interface.eth1.ipaddress[0]}"
  nw_mask_len                    = "24"
  disable_pw_auth                = true
  // connection {
  //   type        = "ssh"
  //   user        = "ubuntu"
  //   host        = "${sakuracloud_vpc_router.vpc-router.global_address}"
  //   port        = "1020${count.index}"
  //   private_key = "${sakuracloud_ssh_key_gen.key.private_key}"
  // }
  // provisioner "remote-exec" {
  //   # write password mean for the sake of ansible used
  //   # todo: must better use cloudinit or packer initialize.
  //   inline = [
  //     "echo ${self.password} |sudo -S sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config",
  //     "sudo systemctl restart sshd.service",
  //     "echo Success",
  //     "sudo ip link set eth1 up",
  //     "sudo ip addr add ${self.additional_display_ipaddresses[0]}/24 dev eth1"
  //   ]
  // }
}

resource sakuracloud_server "k8s-lb-server" {
  count                          = "${lookup(var.lb, terraform.workspace)}"
  name                           = "k8s-lb-${count.index + 1}-server-${terraform.workspace}"
  hostname                       = "k8s-lb-${count.index + 1}-server-${terraform.workspace}"
  core                           = "${lookup(var.lb_cpu, terraform.workspace)}"
  memory                         = "${lookup(var.lb_mem, terraform.workspace)}"
  disks                          = ["${sakuracloud_disk.k8s-lb-disk[count.index].id}"]
  nic                            = "${sakuracloud_switch.external-switch.id}"
  additional_nics                = ["${sakuracloud_switch.k8s-internal-switch.id}"]
  additional_display_ipaddresses = ["192.168.100.3${count.index}"]
  ssh_key_ids                    = ["${sakuracloud_ssh_key_gen.key.id}"]
  password                       = "PUT_YOUR_PASSWORD_HERE"
  tags                           = ["k8s", "${terraform.workspace}"]
  ipaddress                      = "172.20.100.3${count.index}"
  gateway                        = "${sakuracloud_vpc_router_interface.eth1.ipaddress[0]}"
  nw_mask_len                    = "24"
  disable_pw_auth                = true
  // connection {
  //   type        = "ssh"
  //   user        = "ubuntu"
  //   host        = "${sakuracloud_vpc_router.vpc-router.global_address}"
  //   port        = "1030${count.index}"
  //   private_key = "${sakuracloud_ssh_key_gen.key.private_key}"
  // }
  // provisioner "remote-exec" {
  //   # write password mean for the sake of ansible used
  //   # todo: must better use cloudinit or packer initialize.
  //   inline = [
  //     "echo ${self.password} |sudo -S sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config",
  //     "sudo systemctl restart sshd.service",
  //     "echo Success",
  //     "sudo ip link set eth1 up",
  //     "sudo ip addr add ${self.additional_display_ipaddresses[0]}/24 dev eth1",
  //     "sudo sysctl net.ipv4.ip_nonlocal_bind=1"
  //   ]
  // }
}

// # global port 10100~10109
resource sakuracloud_vpc_router_port_forwarding "forward_master" {
  count                   = "${lookup(var.master, terraform.workspace)}"
  vpc_router_id           = "${sakuracloud_vpc_router.vpc-router.id}"
  vpc_router_interface_id = "sakuracloud_vpc_router_interface.eth1.id"
  protocol                = "tcp"
  global_port             = tonumber("1010${count.index}")
  private_address         = "172.20.100.1${count.index}"
  private_port            = 22
  depends_on = ["sakuracloud_server.k8s-master-server"]
}

# global port 10200~10209
resource sakuracloud_vpc_router_port_forwarding "forward_node" {
  count                   = "${lookup(var.node, terraform.workspace)}"
  vpc_router_id           = "${sakuracloud_vpc_router.vpc-router.id}"
  vpc_router_interface_id = "sakuracloud_vpc_router_interface.eth1.id"
  protocol                = "tcp"
  global_port             = tonumber("1020${count.index}")
  private_address         = "172.20.100.2${count.index}"
  private_port            = 22
  depends_on = ["sakuracloud_server.k8s-node-server"]
}

# global port 10300~10309
resource sakuracloud_vpc_router_port_forwarding "forward_lb" {
  count                   = "${lookup(var.lb, terraform.workspace)}"
  vpc_router_id           = "${sakuracloud_vpc_router.vpc-router.id}"
  vpc_router_interface_id = "sakuracloud_vpc_router_interface.eth1.id"
  protocol                = "tcp"
  global_port             = tonumber("1030${count.index}")
  private_address         = "172.20.100.3${count.index}"
  private_port            = 22
  depends_on = ["sakuracloud_server.k8s-lb-server"]
}

// # output

output "k8s_master_server_ipaddressport" {
  value = "${formatlist(
    "%s=%s", 
    (sakuracloud_vpc_router_port_forwarding.forward_master.*.private_address),
    (sakuracloud_vpc_router_port_forwarding.forward_master.*.global_port)
  )}"
}
output "k8s_node_server_ipaddressport" {
  value = "${formatlist(
    "%s=%s", 
    (sakuracloud_vpc_router_port_forwarding.forward_node.*.private_address),
    (sakuracloud_vpc_router_port_forwarding.forward_node.*.global_port)
  )}"
}
output "k8s_lb_server_ipaddressport" {
  value = "${formatlist(
    "%s=%s", 
    (sakuracloud_vpc_router_port_forwarding.forward_lb.*.private_address),
    (sakuracloud_vpc_router_port_forwarding.forward_lb.*.global_port)
  )}"
}
output "k8s_VPC_public_addr" {
  value = sakuracloud_vpc_router.vpc-router.global_address
}
