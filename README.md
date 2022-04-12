[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]


# Pi-hole and WireGuard with Terraform in OCI

## About The Project

This project uses [Terraform](https://www.terraform.io/intro) to install/deploy [Pi-hole](https://pi-hole.net/) and [WireGuard](https://www.wireguard.com/) VPN, for private access, on an **always-free tier** instance in the [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/free/) (OCI).

My motivation was to make a simpler or easier-to-read code for more people to understand and trust.

With a few parameters, you can apply the Terraform project to create a VCN, subnet, routing table, security list, and instance in OCI. The server will run the `bootstrap.tftpl` script on boot. This script will update the server, create a dot-env file with environment variables, clone this project, and run WireGuard and Pi-hole as Docker containers.

I look forward to your feedback to make this as easy to read and replicate as possible.

The OCI always-free tier covers what you need to run this project for free when I created it. I would expect charges if outbound traffic from OCI is large enough. In any case, **proceed with caution** and monitor your bill. Also, make sure that adding these new resources to your OCI account does not exceed the free tier or incur unexpected charges.


## Table of Contents

- [About The Project](#about-the-project)
- [Table of Contents](#table-of-contents)
- [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Setup](#setup)
    - [Installation](#installation)
        - [Local Terraform](#local-terraform)
        - [Terraform Cloud](#terraform-cloud)
    - [Destroy Resources](#destroy-resources)
- [Usage](#usage)
    - [Connect to WireGuard](#connect-to-wireguard)
    - [SSH to the Server](#ssh-to-the-server)
    - [Access Pi-hole Web Console](#access-pi-hole-web-console)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)


## Getting Started

The goal will be to run an OCI instance with two containers, Pi-hole and WireGuard, so you can install WireGuard on your device (laptop, phone) and access the Pi-hole service privately from anywhere.

### Prerequisites

You will need the following:

- Install [Docker Engine](https://docs.docker.com/engine/install/) in your machine/desktop/laptop/PC/workstation.
- Install [Git](https://git-scm.com/downloads) in your machine/desktop/laptop/PC/workstation.
- Understand `<foo>` is a placeholder, and you must delete from `<` to `>` and write the correct value of `foo` when needed, e.g.:
    - if `for=bar`; then `<for>` &rarr; `bar`
    - `"<'region' of the OCI account>"` &rarr; `"us-ashburn-1"`
    - `<DNS IP>` &rarr; `1.1.1.1`
- Know how to open the terminal in your machine and run commands.


### Setup

Here we will create the `terraform/terraform.tfvars` file and explain how to obtain all the needed values.

*It is important you do not share these parameters and files for recurity reasons.*
&nbsp;  

1. Create an OCI account. Follow this [link](https://signup.cloud.oracle.com/?sourceType=_ref_coc-asset-opcSignIn&language=en_US) to sign up.

2. Create an API KEY in Oracle.

    i. Log in to **OCI** > click on the profile icon (in the upper-right corner) and select your user.
        <kbd>![Select OCI profile](https://i.imgur.com/gI45oCg.jpg)</kbd>
        &nbsp;  

    ii. Go to **API Keys** at the end of the page and create a new one.
        <kbd>![Add keys](https://i.imgur.com/R1Wu89c.jpeg)</kbd>
        &nbsp;  

    iii. Select **Generate API Key Pair** and download the private key.
        <kbd>![Download kwys](https://i.imgur.com/iNIZ7eV.jpeg)</kbd>
        &nbsp;  

    iv. Copy the **Configuration File** for later.
        <kbd>![Copy profile configuration](https://i.imgur.com/1pk4zPM.jpeg)</kbd>
        &nbsp;  

3. Convert the private key downloaded in step 2.iii to a **one-line** base64 string.

    i. If you have a Linux terminal, you may use this approach. Make sure the output is one line; otherwise, remove the new lines manually (leave no spaces) or use the second method.

        ```shell
        base64 <path to the private key file>
        # save this output for later
        ```

    ii. Launch a Docker container to convert the file into a base64 string (run lines one by one):

        ```shell
        docker run --rm -it --name temp ubuntu:latest bash

        # open and run in a new terminal
        docker container cp <path to the private key file> temp:/tmp/private-key.pem
        exit

        # back to the first terminal
        base64 /tmp/private-key.pem -w 0; echo
        # save this output for later
        exit
        ```

4. Clone this project to your machine.

    ```shell
    git clone https://github.com/OscarB7/pihole-terraform.git
    ```

5. Create WireGuard key pairs.

    Here you will build our WireGuard container, generate two WireGuard key pairs (`server.privatekey`, `server.publickey`, `client.privatekey`, and `client.publickey`), and copy those files to your machine.

    **Note** WireGuard does not differentiate between `server` and `client`; instead, all devices are `peers`. This document will refer to the WireGuard peer installed in the OCI instance as the `WireGuard server` and `WireGuard client` to the one installed in your device, e.g., phone or laptop.

    Run the following lines one by one to create the keys.

    ```shell
    # build container
    docker build --tag wg:latest .

    # run the container and access it
    docker run -it --name temp wg:latest sh

    # create the keys inside the container
    umask 077; wg genkey | tee server.privatekey | wg pubkey > server.publickey
    umask 077; wg genkey | tee client.privatekey | wg pubkey > client.publickey
    exit

    # copy the keys from the container to your machine
    docker container cp temp:/etc/wireguard/server.privatekey .
    docker container cp temp:/etc/wireguard/server.publickey .
    docker container cp temp:/etc/wireguard/client.privatekey .
    docker container cp temp:/etc/wireguard/client.publickey .

    docker rm -f temp
    ```

6. Create SSH keys.

    You need these to SSH to the server. Here you will launch an Ubuntu container, install OpenSSH, generate a SSH key pair (`id_rsa` and `id_rsa.pub`), and copy those files to your machine (run lines one by one).

    ```shell
    # run the container and access it
    docker run -it --name temp --user root ubuntu:latest bash
    
    # install openssh
    apt update && apt install -y openssh-client

    # create ssh keys
    ssh-keygen -t rsa -b 4096
    # accept default values by using 'enter' (no password/passphrase)

    exit

    # copy the keys from the container to your machine
    docker container cp temp:/root/.ssh/id_rsa .
    docker container cp temp:/root/.ssh/id_rsa.pub .

    docker rm -f temp
    ```

7. Get your home public IP address.

    Connect to your WiFi at home, go to [this](https://ifconfig.co/ip) page, and copy the IP value.

    This location/network will be allowed to access (1) the Pi-hole DNS service directly without WireGuard connection, (2) the Pi-hole web console, and (3) the OCI instance via SSH.
    &nbsp;  

8. Create the `terraform/terraform.tfvars` file.

    ```shell
    oci_region                   = "<'region' field of the Configuration File in step 2.iv>"
    oci_user_ocid                = "<'user' field of the Configuration File in step 2.iv>"
    oci_tenancy_ocid             = "<'tenancy' field of the Configuration File in step 2.iv>"
    oci_fingerprint              = "<'fingerprint' field of the Configuration File in step 2.iv>"
    oci_private_key_base64       = "<base64 one-line string obained in step 3>"
    your_home_public_ip          = "<public IP address of your home obtained in step 7>"
    ssh_public_key               = "<the content of the file 'id_rsa.pub' created in step 6>"
    docker_compose_version       = "2.1.1"
    docker_network_range         = "10.7.0.0/16"
    docker_compose_network_range = "10.7.107.0/24"
    pihole_ip                    = "10.7.107.101"
    pihole_dns_port              = "53"
    pihole_web_port              = "80"
    wg_port                      = "51820"
    wg_server_private_key        = "<the content of the file 'server.privatekey' created in step 5>"
    wg_server_ip                 = "10.6.0.1/24"
    wg_server_port               = "51820"
    wg_client_public_key         = "<the content of the file 'client.publickey' created in step 5>"
    wg_client_ip                 = "10.6.0.2/32"
    tz                           = "America/New_York"
    pihole_webpassword           = "<generate a strong password. Avoid these characters: '=' and ';'>"
    pihole_dns_ip                = "1.1.1.1"
    
    # Base/Shared resources (OPTIONAL)
    oci_vcn_id              = "<ID of an already existing VCN in case you want to use it; otherwise, a new one will be created>"
    oci_internet_gateway_id = "<ID of an already existing internet gateway in case you want to use it; otherwise, a new one will be created>"
    oci_route_table_id      = "<ID of an already existing route table in case you want to use it; otherwise, a new one will be created>"
    oci_security_list_id    = "<ID of an already existing security list in case you want to use it; otherwise, a new one will be created>"
    oci_subnet_id           = "<ID of an already existing subnet in case you want to use it; otherwise, a new one will be created>"
    oci_image_id            = "<ID of an already existing image in case you want to use it; otherwise, a new one will be created>"

    ```

    Parameters:

    - **oci_region**: [*REQUIRED*]  
        Region of your OCI account.  
        `region` parameter from the Configuration File in step 2.iv.
    - **oci_user_ocid**: [*REQUIRED*]  
        User ID of your OCI account.  
        `user` parameter from the Configuration File in step 2.iv.
    - **oci_tenancy_ocid**: [*REQUIRED*]  
        Tenancy ID of your OCI account.  
        `tenancy` parameter from the Configuration File in step 2.iv.
    - **oci_fingerprint**: [*REQUIRED*]  
        The fingerprint of your OCI API Key.  
        `region` parameter from the Configuration File in step 2.iv.
    - **oci_private_key_base64**: [*REQUIRED*]  
        One-line base64 string of the OCI private key downloaded in step 2.iii.  
        This value comes from step 3.
    - **your_home_public_ip**: [*REQUIRED*]  
        Public IP of your home.  
        This value comes from step 6.
    - **ssh_public_key**: [*REQUIRED*]  
        SSH public key.  
        This value comes from the content of the `id_rsa.pub` file created in step 5.
    - **docker_compose_version**: [*Default:* `2.1.1`]  
        Docker Compose version to be installed in the OCI instance.
    - **docker_network_range**: [*Default:* `10.7.0.0/16`]  
        IP range of Docker in the OCI instance.
    - **docker_compose_network_range**: [*Default:* `10.7.107.0/24`]  
        IP range of the Docker Compose network, where the containers will run.
    - **pihole_ip**: [*Default:* `10.7.107.101`]  
        Private IP of the Pi-hole container.
    - **pihole_dns_port**: [*Default:* `53`]  
        Published port for DNS service of Pi-hole.
    - **pihole_web_port**: [*Default:* `80`]  
        Published port for web console of Pi-hole.
    - **wg_port**: [*Default:* `51820`]  
        Published port for WireGuard port to the instance.
    - **wg_server_private_key**: [*REQUIRED*]  
        The private key of the WireGuard server in OCI.  
        This value comes from the content of the `server.privatekey` file created in step 4.
    - **wg_server_ip**: [*Default:* `10.6.0.1/24`]  
        IP of the WireGuard private network and mask.
    - **wg_server_port**: [*Default:* `51820`]  
        WireGuard port inside the container.
    - **wg_client_public_key**: [*REQUIRED*]  
        The public key of the WireGuard client.  
        This value comes from the content of the `client.publickey` file created in step 4.
    - **wg_client_ip**: [*Default:* `10.6.0.2/32`]  
        The IP address of the WireGuard client assigned within the VPN network.
    - **tz**: [*Default:* `America/New_York`]  
        Time zone. You can see valid values for this variable by running this command in Linux/Mac `timedatectl list-timezones` or on [this](https://gist.github.com/adamgen/3f2c30361296bbb45ada43d83c1ac4e5#file-timedatectl-list-timezones) page.
    - **pihole_webpassword**: [*REQUIRED*]  
        Password to access the Pi-hole web console.  
        Generate a strong password. Avoid these characters: `=`, `$`, and `;`
    - **pihole_dns_ip**: [*Default:* `1.1.1.1`]  
        DNS server sed by Pi-hole.
        You can set more than one by separating DNS servers with `,` and leaving no spaces around it.
        You can specify the port of the DNS service by adding `#<port>` after the IP, e.g., `10.7.107.111#5053;1.1.1.1`

    &nbsp;  
    The default values will work fine unless the IP ranges overlap with your existing network.
    &nbsp;  

    Example (**do not use these values**):

    ```shell
    oci_region             = "us-ashburn-1"
    oci_user_ocid          = "ocid1.user.oc1..aaa...wmpxt"
    oci_tenancy_ocid       = "ocid1.tenancy.oc1..aaa...dnkxd"
    oci_fingerprint        = "17:a8:...:01:c4"
    oci_private_key_base64 = "AS0tZS2CR3dJT4BQUkl...ZAS3tLS4="
    your_home_public_ip    = "123.123.123.123/32"
    ssh_public_key         = "ssh-rsa AAAAB3NzaC1...Elzyar4w== root@c14cb235dae5"
    wg_server_private_key  = "0GYGZzW1tIxNGattbKmBA6Y9WV/nc/kod6OP245qiF8="
    wg_client_public_key   = "e2C16gOS/M4C6+o6X7HFwnW6jWT2XlgMf39HaMvMhDo="
    pihole_webpassword     = "6V5!B6J!2FxM*$PJ#KP*aEN^%"
    ```

### Installation

Now that you have completed the [prerequisites](#prerequisites) and [setup](#setup), you can deploy the project to OCI with Terraform.

#### Local Terraform

Run the following commands one by one from the root folder of this project.

```shell
docker run --rm -it --name tf --mount type=bind,source="$(pwd)"/terraform,target=/tf --entrypoint sh hashicorp/terraform:1.1.4
cd /tf
terraform init
terraform apply
# read the output from terraform and respond 'yes' to confirm you want to create the resources
exit
```

After finishing the deployment, you can read the public IP of the OCI instance from `instance_public_ip` and the Pi-hole DNS and web console ports, `port_pihole_dns` and `port_pihole_web` (we will refer to this information later). Here is an example of the output:

```shell
...
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

availability_domains = "TSJZ:US-ASHBURN-AD-1"
image_id = "ocid1.image.oc1.iad.aaaaaaaa2tex34yxzqunbwnfnat6pkh2ztqchvfyygnnrhfv7urpbhozdw2a"
image_name = "Canonical-Ubuntu-20.04-aarch64-2021.12.01-0"
instance_public_ip = "157.157.157.157"
port_pihole_dns = 53
port_pihole_web = 80
/tf # 
```

You will see new files created in the project directory, which have the current state of the infrastructure. Do not delete those files because you need them for [destroying the resources](#destroy-resources).

#### Terraform Cloud

Here you will use the free tier of [Terraform Cloud](https://cloud.hashicorp.com/products/terraform) as an alternative to the local solution. Why use this instead? Because it will keep track of the Terraform state for you; otherwise, you have to save those files if you want to update or destroy the deployment later. Check the previous link for a full explanation of the benefits.

You can follow this [tutorial](https://learn.hashicorp.com/tutorials/terraform/cloud-sign-up?in=terraform/cloud-get-started), get familiar with it, and repeat the steps for this project.

### Destroy Resources

You can destroy/remove the resources you created with Terraform at any moment. Note you should not edit those resources using the OCI console since it may interfere with this step.

Below is the process if you deployed using [local Terraform](#local-terraform).

```shell
# in case the tf container is still running
docker rm -f tf

docker run --rm -it --name tf --mount type=bind,source="$(pwd)"/terraform,target=/tf --entrypoint sh hashicorp/terraform:1.1.4

cd /tf
terraform destroy
# read the output from terraform and respond 'yes' to confirm you want to delete the resources
exit
```

If you deployed this project using [Terraform Cloud](#terraform-cloud), the tutorial linked in that section explains how to destroy the resources.


## Usage

With this project, you could achieve a similar result described in tutorials like [this](https://medium.com/@devinjaystokes/automating-the-deployment-of-your-forever-free-pihole-and-wireguard-server-dce581f71b7) one with the benefits of Terraform.

At this point, you have created the instance in OCI with Pi-hole and WireGuard configured. Now you can use these services and access the OCI instance.

### Connect to WireGuard

Download [WireGuard](https://www.wireguard.com/install/) on your device(s) and configure it as the `client`.

Create a new empty tunnel (peer connection) with the following template and update it with the values from the [setup](#Setup) section:

```shell
[Interface]
PrivateKey = <content of the file 'client.privatekey'>
Address = <'wg_client_ip' value from 'terraform/terraform.tfvars' without the network size ('/32')>/<network size of the 'wg_server_ip' value from 'terraform/terraform.tfvars'>
DNS = <'pihole_ip' value from 'terraform/terraform.tfvars'>

[Peer]
PublicKey = <content of the file server.publickey>
AllowedIPs = <'wg_server_ip' value from 'terraform/terraform.tfvars'>, <'docker_compose_network_range' value from 'terraform/terraform.tfvars'>
Endpoint = <'instance_public_ip' from the 'installation' section>:<'wg_port' value from 'terraform/terraform.tfvars'>
```

Example:

```shell
[Interface]
PrivateKey = eE6nf2phCWbIAOw+7w9fft61+k+MdM8Ce1eEuV5jg2g=
Address = 10.6.0.2/24
DNS = 10.7.107.101

[Peer]
PublicKey = BT3njAHyTQFNujOKIqHhpeCrHTjlbsvoBvwhsAiai0o=
AllowedIPs = 10.6.0.1/24, 10.7.107.0/24
Endpoint = 157.157.157.157:51820
```

The value of AllowedIPs defines what traffic is sent through the VPN. Your device will send only the traffic for the WireGuard and Docker Compose networks through the VPN if you use the example's values. You can set it to `0.0.0.0/0` to send all traffic through the VPN.

### SSH to the Server

You can SSH to the server if you are curious or need to troubleshoot. Use the following credentials from your home.


```shell
Hostname: <'instance_public_ip' from the 'installation' section>
Username: ubuntu
Private key: <use 'id_rsa', created in step 6 from the 'setup' section>
```

**Note** there is no `password` since it authenticates with a private key.

You can use [Putty](https://www.putty.org/) on Windows or these commands on a Linux terminal:

```shell
chmod 0600 id_rsa
ssh ubuntu@<'instance_public_ip' from the 'installation' section> -i id_rsa
```

Example:

```shell
chmod 0600 id_rsa
ssh ubuntu@157.157.157.157 -i id_rsa
```

### Access Pi-hole Web Console

Use these URLs to access the Pi-hole web console to manage it.

```shell
URL from your home: http://<'instance_public_ip' from the 'installation' section>:<'port_pihole_web' from the 'installation' section>/admin
URL when connected to WireGuard: http://<'pihole_ip' value from 'terraform/terraform.tfvars'>:80/admin
Password: <'pihole_webpassword' value from 'terraform/terraform.tfvars'>
```

Example:

```shell
URL from your home: http://157.157.157.157:80/admin
URL connected to WireGuard: http://10.7.107.101:80/admin
Password: 6V5!B6J!2FxM*$PJ#KP*aEN^%
```

**Note** you can use `http://pi.hole/admin/` as the URL if Pi-hole is your DNS when connected to WireGuard or configured otherwise.

## Roadmap

- Save Pi-hole configuration in an object-storage service, like S3, to recover the settings if the instance has issues or needs maintenance. The server should access the object storage privately with a service gateway.
- Run instance in an autoscaling group to recover from some problem with the hardware.
- Add more than one client to the WireGuard server.
- Add budget or spending limit for OCI in case of unexpected charges.
- Run process in the containers as non-root.
- Add Cloudflare container for Pi-hole to use DNS over HTTPS.
- Create a key to encrypt boot volume. kmsKeyId

See the [open issues](https://github.com/OscarB7/pihole-terraform/issues) for a complete list of proposed features (and known issues).


## Contributing

Contributions make the open-source community a great place to learn, inspire, and create. Any improvement you add is greatly appreciated.

Please fork this repo and create a pull request if you have any suggestions. You can also open an issue with the tag `enhancement`.
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


## License

Distributed under the MIT License. See `LICENSE.txt` for more information.


## Contact

Oscar Blanco - [Twitter @OsBlancoB](https://twitter.com/OsBlancoB) - [LinkedIn][linkedin-url]

Project Link: [https://github.com/OscarB7/pihole-terraform](https://github.com/OscarB7/pihole-terraform)



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/OscarB7/pihole-terraform.svg?style=for-the-badge
[contributors-url]: https://github.com/OscarB7/pihole-terraform/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/OscarB7/pihole-terraform.svg?style=for-the-badge
[forks-url]: https://github.com/OscarB7/pihole-terraform/network/members
[stars-shield]: https://img.shields.io/github/stars/OscarB7/pihole-terraform.svg?style=for-the-badge
[stars-url]: https://github.com/OscarB7/pihole-terraform/stargazers
[issues-shield]: https://img.shields.io/github/issues/OscarB7/pihole-terraform.svg?style=for-the-badge
[issues-url]: https://github.com/OscarB7/pihole-terraform/issues
[license-shield]: https://img.shields.io/github/license/OscarB7/pihole-terraform.svg?style=for-the-badge
[license-url]: https://github.com/OscarB7/pihole-terraform/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/oscar-blanco-b75842132
