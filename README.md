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

The prerequisites are listed [here](https://github.com/OscarB7/terraform-oci-base-resources#prerequisites).


### Setup

Here we will create the `terraform/terraform.tfvars` file and explain how to obtain all the needed values.

*It is important you do not share these parameters and files for security reasons.*
&nbsp;  

1. OCI authentication.

    Follow these [instructions](https://github.com/OscarB7/terraform-oci-base-resources#setup) to get the value of the variables `oci_region`, `oci_user_ocid`, `oci_tenancy_ocid`, `oci_fingerprint`, `oci_private_key_base64`, and `your_home_public_ip`.

2. Clone this project to your machine.

    ```shell
    git clone https://github.com/OscarB7/pihole-terraform.git
    ```

3. Create WireGuard key pairs.

    Here you will build our WireGuard container, generate two WireGuard key pairs (`server.privatekey`, `server.publickey`, `client.privatekey`, and `client.publickey`), and copy those files to your machine.

    **Note** WireGuard does not differentiate between `server` and `client`; instead, all devices are `peers`. This document will refer to the WireGuard peer installed in the OCI instance as the `WireGuard server` and `WireGuard client` to the one installed in your device, e.g., phone or laptop.

    Run the following lines one by one to create the keys manually or see option below using the script.

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

    You can use the `create_wg_keys.sh` script to create multiple WireGuard key pairs:

    ```shell
    # change file permission. needed if you get the following error:
    #   exec: "/opt/tools/create_wg_keys.sh": permission denied: unknown.
    chmod 0750 tools/create_wg_keys.sh

    # build WireGuard container
    docker build --tag wg:latest .

    # create keys with the following command
    # docker run --rm -it --name temp -v ./tools/create_wg_keys.sh:/opt/tools/create_wg_keys.sh wg:latest /opt/tools/create_wg_keys.sh <number of clients> <IP of first client>
    # change <number of clients> with the number of clients you will need
    # change <IP of first client> with the address you prefer or leave it empty to use the default value
    # example:
    docker run --rm -it --name temp -v ./tools/create_wg_keys.sh:/opt/tools/create_wg_keys.sh wg:latest /opt/tools/create_wg_keys.sh 2 10.6.0.2/32

    # copy the line below "base64 string with all keys" from the script output
    ```

4. Create SSH keys.

    You need these to SSH to the server.  
    You probably can run this commands in your own machine. Here, for the sake of simplicity, you will launch an Ubuntu container, install OpenSSH, generate a SSH key pair (`id_rsa` and `id_rsa.pub`), and copy those files to your machine (run lines one by one).

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

5. Get your home public IP address.

    Connect to your WiFi at home, go to [this](https://ifconfig.co/ip) page, and copy the IP value.

    This location/network will be allowed to access (1) the Pi-hole DNS service directly without WireGuard connection, (2) the Pi-hole web console, and (3) the OCI instance via SSH.
    &nbsp;  

6. Create the `terraform/terraform.tfvars` file.

    ```shell
    oci_region                   = "<'region' field of the Configuration File in step 2.iv>"
    oci_user_ocid                = "<'user' field of the Configuration File in step 2.iv>"
    oci_tenancy_ocid             = "<'tenancy' field of the Configuration File in step 2.iv>"
    oci_fingerprint              = "<'fingerprint' field of the Configuration File in step 2.iv>"
    oci_private_key_base64       = "<base64 one-line string obained in step 1>"
    your_home_public_ip          = "<public IP address of your home obtained in step 5>"
    ssh_public_key               = "<the content of the file 'id_rsa.pub' created in step 4>"
    use_reserved_public_ip       = true
    docker_compose_version       = "2.1.1"
    docker_network_range         = "10.7.0.0/16"
    docker_compose_network_range = "10.7.107.0/24"
    pihole_ip                    = "10.7.107.101"
    pihole_dns_port              = "53"
    pihole_web_port              = "8080"
    wg_port                      = "51820"
    wg_keys_base64               = "<base64 one-line string obained in step 1>"
    wg_server_private_key        = "<the content of the file 'server.privatekey' created in step 3>"
    wg_server_ip                 = "10.6.0.1/24"
    wg_server_port               = "51820"
    wg_client_public_key         = "<the content of the file 'client.publickey' created in step 3>"
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
        This value comes from step 1.
    - **your_home_public_ip**: [*REQUIRED*]  
        Public IP of your home.  
        This value comes from step 6.
    - **ssh_public_key**: [*REQUIRED*]  
        SSH public key.  
        This value comes from the content of the `id_rsa.pub` file created in step 4.
    - **use_reserved_public_ip**: [*Default:* `false`]  
        Create a reserved public IP, which is an independent resource from the instance.  
        If set to `true`, this IP will be attached to the instance; therefore, if the instance is recreated, the public IP will not change.  
        If set to `false`, the public IP will be created with the instance.
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
    - **pihole_web_port**: [*Default:* `8080`]  
        Published port for web console of Pi-hole.
    - **wg_port**: [*Default:* `51820`]  
        Published port for WireGuard port to the instance.
    - **wg_keys_base64**: [*Default:* `Null`]  
        Base64 string with the WireGuard keys of the server and clients needed to configure the server.  
        This value comes from step 3.
    - **wg_server_private_key**: [*REQUIRED*]  
        The private key of the WireGuard server in OCI.  
        This value comes from the content of the `server.privatekey` file created in step 4.
    - **wg_server_ip**: [*Default:* `10.6.0.1/24`]  
        IP of the WireGuard private network and mask.
    - **wg_server_port**: [*Default:* `51820`]  
        WireGuard port inside the container.
    - **wg_client_public_key**: [*REQUIRED, unless wg_keys_base64 is passed*]  
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

    &nbsp;  
    Example (**do not use these values**):

    ```shell
    # from step 1
    oci_region             = "us-ashburn-1"
    oci_user_ocid          = "ocid1.user.oc1..aaa...wmpxt"
    oci_tenancy_ocid       = "ocid1.tenancy.oc1..aaa...dnkxd"
    oci_fingerprint        = "17:a8:...:01:c4"
    oci_private_key_base64 = "AS0tZS2CR3dJT4BQUkl...ZAS3tLS4="
    your_home_public_ip    = "123.123.123.123/32"

    ssh_public_key         = "ssh-rsa AAAAB3NzaC1...Elzyar4w== root@c14cb235dae5"
    use_reserved_public_ip = true

    wg_server_private_key  = "0GYGZzW1tIxNGattbKmBA6Y9WV/nc/kod6OP245qiF8="
    wg_client_public_key   = "e2C16gOS/M4C6+o6X7HFwnW6jWT2XlgMf39HaMvMhDo="
    pihole_webpassword     = "6V5!B6J!2FxM*$PJ#KP*aEN^%"

    # Base/Shared resources (OPTIONAL)
    # in case you created the base resources already with the project terraform-oci-base-resources,
    # see the local_variables from output, e.g., local_oci_vcn_id
    oci_vcn_id              = "ocid1.vcn.oc1.iad.am...wa"
    oci_internet_gateway_id = "ocid1.internetgateway.oc1.iad.aa...ea"
    oci_route_table_id      = "ocid1.routetable.oc1.iad.aa...xq"
    oci_security_list_id    = "ocid1.securitylist.oc1.iad.aa...da"
    oci_subnet_id           = "ocid1.subnet.oc1.iad.aa...pq"
    ```

### Installation

Now that you have completed the [setup](#setup), you can deploy the project to OCI with Terraform.

Follow these [instructions](https://github.com/OscarB7/terraform-oci-base-resources#installation) to create the resources in OCI with Nefertiti running in an instance.

After applying the project, you will see the public IP of your instance in the variable `instance_public_ip` and the Pi-hole DNS and web console ports, `port_pihole_dns`, `port_pihole_web`, `port_proxy_http`, and `port_proxy_https` (we will refer to this information later) in the Terraform output. For example:

```shell
...
Apply complete! Resources: ...

Outputs:
...
instance_public_ip = "157.157.157.157"
port_pihole_dns = 53
port_pihole_web = 8080
...
```


### Destroy Resources

Follow these [instructions](https://github.com/OscarB7/terraform-oci-base-resources#destroy-resources) to destroy the resources created in the [installation](#installation) step.


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

You can SSH to the server if you need to troubleshoot. Use the following credentials from your home.

```shell
Hostname: <'instance_public_ip' from the 'installation' section>
Username: ubuntu
Private key: <use 'id_rsa', created in 'setup' section>
```

**Note** there is no `password` since it authenticates with a private key.

You can use [Putty](https://www.putty.org/) on Windows or these commands on a Linux terminal where you saved the `id_rsa` file:

```shell
chmod 0600 id_rsa
ssh ubuntu@<'instance_public_ip'> -i id_rsa
```

Example:

```shell
chmod 0600 id_rsa
ssh ubuntu@157.157.157.157 -i id_rsa
```

### Access Pi-hole Web Console

Use these URLs to access the Pi-hole web console to manage it.

```shell
URL from your home using HTTPS: http://<'instance_public_ip' from the 'installation' section>:<'port_proxy_https' from the 'installation' section>/admin
URL from your home: http://<'instance_public_ip' from the 'installation' section>:<'port_pihole_web' from the 'installation' section>/admin
URL when connected to WireGuard: http://<'pihole_ip' value from 'terraform/terraform.tfvars'>:8080/admin
Password: <'pihole_webpassword' value from 'terraform/terraform.tfvars'>
```

Example:

```shell
URL from your home: http://157.157.157.157
URL from your home: https://157.157.157.157/admin
URL from your home: http://157.157.157.157:8080/admin
URL connected to WireGuard: http://10.7.107.101:8080/admin
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

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a pull request


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
