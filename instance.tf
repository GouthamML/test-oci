// Copyright (c) 2017, 2019, Oracle and/or its affiliates. All rights reserved.
// added a comment
variable "tenancy_ocid" {
}

variable "user_ocid" {
}

variable "fingerprint" {
}

variable "private_key_path" {
}

variable "region" {
}

variable "compartment_ocid" {
}

variable "ssh_public_key" {
}

variable "ssh_private_key" {
}

variable "vcn_ocid" {
}

variable "subnet_ocid" {
}

variable "ssh_user" {
  description = "SSH user name to connect to your instance."
  default     = "opc"
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# Defines the number of instances to deploy
variable "num_instances" {
  default = "2"
}

variable "instance_shape" {
  default = "VM.Standard1.1"
}

variable "instance_image_ocid" {
  type = map(string)

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaaoqj42sokaoh42l76wsyhn3k2beuntrh5maj3gmgmzeyr55zzrwwa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa"
  }
}

variable "db_size" {
  default = "10" # size in GBs
}

resource "oci_core_instance" "test_instance" {
  count               = var.num_instances
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "TestInstance${count.index}"
  shape               = var.instance_shape
  subnet_id           = var.subnet_ocid
  source_details {
    source_type = "image"
    source_id   = var.instance_image_ocid[var.region]
  }

  # Apply the following flag only if you wish to preserve the attached boot volume upon destroying this instance
  # Setting this and destroying the instance will result in a boot volume that should be managed outside of this config.
  # When changing this value, make sure to run 'terraform apply' so that it takes effect before the resource is destroyed.
  #preserve_boot_volume = true

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("./userdata/bootstrap"))
  }

  timeouts {
    create = "60m"
  }

}

resource "null_resource" "example_provisioner" {
  /*triggers = {
	public_ip = "${oci_core_instance.test_instance.*.public_ip}"
  }*/
//count = "${var.num_instances}"
  
provisioner "file" {
   source      = "play.yaml"
   destination = "/home/${var.ssh_user}/play.yaml"

   connection {
     type        = "ssh"
     host = "${oci_core_instance.test_instance.*.public_ip[0]}"
     user        = var.ssh_user
     private_key = var.ssh_private_key
   }
}
	
provisioner "file" {
   source      = "ansible.cfg"
   destination = "/home/${var.ssh_user}/ansible.cfg"

   connection {
     type        = "ssh"
     host = "${oci_core_instance.test_instance.*.public_ip[0]}"
     user        = var.ssh_user
     private_key = var.ssh_private_key
   }
}
	
provisioner "file" {
   source      = "id_rsa"
   destination = "/home/${var.ssh_user}/.ssh/id_rsa"

   connection {
     type        = "ssh"
     host = "${oci_core_instance.test_instance.*.public_ip[0]}"
     user        = var.ssh_user
     private_key = var.ssh_private_key
   }
}
	
	
  provisioner "remote-exec" {
    connection {
	type = "ssh"
	host = "${oci_core_instance.test_instance.*.public_ip[0]}"
	user = var.ssh_user
	private_key = var.ssh_private_key
    }
	  
	inline = ["sudo yum update -y",
		"sudo yum install -y ansible",
		"mkdir -p ansible_automation ; cd ansible_automation",
		"touch hosts",
		"echo [servers] >> hosts ; echo ${oci_core_instance.test_instance.*.public_ip[1]} ansible_ssh_private_key_file=/home/opc/.ssh/id_rsa >> hosts",
		"mv ../play.yaml play.yaml",
		"mv ../ansible.cfg ansible.cfg",
		"sudo chmod 600 /home/${var.ssh_user}/.ssh/id_rsa",
		"ansible-playbook play.yaml"
		]
  }
}

/*data "oci_core_instance_devices" "test_instance_devices" {
  count       = var.num_instances
  instance_id = oci_core_instance.test_instance[count.index].id
}*/

# Output the private and public IPs of the instance

output "instance_private_ips_checking_pipeline" {
  value = [oci_core_instance.test_instance.*.private_ip]
}

output "instance_public_ips" {
  value = [oci_core_instance.test_instance.*.public_ip]
}
/*
output "check_value_private_key" {
  value = ${"var.ssh_private_key"}
}

output "check_value_oci_user" {
  value = ${"var.ssh_user"}
}
*/
# Output all the devices for all instances
/*
output "instance_devices" {
  value = [data.oci_core_instance_devices.test_instance_devices.*.devices]
}
*/

data "oci_identity_availability_domain" "ad" {
  compartment_id = var.tenancy_ocid
  ad_number      = "1"
}

data "oci_core_vcn" "test_vcn" {
  #Required
  vcn_id = var.vcn_ocid
}

data "oci_core_subnet" "test_subnet" {
  #Required
  subnet_id = var.subnet_ocid
}

