variable "master" {
  type = "map"
  default = {
    tmp = "1"
    dev = "3"
    tra = "3"
    prd = "3"
  }
}
variable "master_cpu" {
  type = "map"
  default = {
    tmp = "2"
    dev = "8"
    tra = "3"
    prd = "4"
  }
}
variable "master_mem" {
  type = "map"
  default = {
    tmp = "2"
    dev = "16"
    tra = "16"
    prd = "8"
  }
}
variable "master_disk" {
  type = "map"
  default = {
    tmp = "20"
    dev = "100"
    tra = "100"
    prd = "100"
  }
}

variable "node" {
  type = "map"
  default = {
    tmp = "3"
    dev = "3"
    tra = "3"
    prd = "3"
  }
}
variable "node_cpu" {
  type = "map"
  default = {
    tmp = "2"
    dev = "8"
    tra = "8"
    prd = "4"
  }
}
variable "node_mem" {
  type = "map"
  default = {
    tmp = "2"
    dev = "16"
    tra = "16"
    prd = "8"
  }
}
variable "node_disk" {
  type = "map"
  default = {
    tmp = "20"
    dev = "100"
    tra = "100"
    prd = "100"
  }
}

variable "lb" {
  type = "map"
  default = {
    tmp = "0"
    dev = "2"
    tra = "2"
    prd = "2"
  }
}
variable "lb_cpu" {
  type = "map"
  default = {
    tmp = "0"
    dev = "2"
    tra = "4"
    prd = "2"
  }
}
variable "lb_mem" {
  type = "map"
  default = {
    tmp = "0"
    dev = "2"
    tra = "2"
    prd = "2"
  }
}
variable "lb_disk" {
  type = "map"
  default = {
    tmp = "0"
    dev = "20"
    tra = "20"
    prd = "20"
  }
}


variable "appliance" {
  type = "map"
  default = {
    tmp = "0"
    dev = "1"
    tra = "1"
    prd = "1"
  }
}
variable "appliance_cpu" {
  type = "map"
  default = {
    tmp = "0"
    dev = "2"
    tra = "2"
    prd = "2"
  }
}
variable "appliance_mem" {
  type = "map"
  default = {
    tmp = "0"
    dev = "2"
    tra = "2"
    prd = "2"
  }
}
variable "appliance_disk" {
  type = "map"
  default = {
    tmp = "0"
    dev = "20"
    tra = "20"
    prd = "20"
  }
}

variable "postgresql" {
  type = "map"
  default = {
    tmp = "0"
    dev = "1"
    tra = "1"
    prd = "1"
  }
}



// variable "nw_mask_len"{
//   type = "map"
//   default = {
//     tmp = "29"
//     dev = "28"
//     prd = "28"
//   }
// }

// variable "bgp" {
//   type = "map"
//   default = {
//     tmp = "0"
//     dev = "1"
//     prd = "1"
//   }
// }
// variable "bgp_cpu" {
//   type = "map"
//   default = {
//     tmp = "0"
//     dev = "4"
//     prd = "4"
//   }
// }
// variable "bgp_mem" {
//   type = "map"
//   default = {
//     tmp = "0"
//     dev = "8"
//     prd = "8"
//   }
// }
// variable "bgp_disk" {
//   type = "map"
//   default = {
//     tmp = "0"
//     dev = "20"
//     prd = "20"
//   }
// }

