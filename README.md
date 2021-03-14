Prerequisite:
1. Terraform Version: 0.12 or higher
2. AWS Credentials: Export AWS Access/Secret/Token before deployment

Architecture Diagram:
![AWS Architecture - Webserver + Autoscaling + EFS + Secure By Pranav Joshi](https://user-images.githubusercontent.com/10628719/111072772-0da0c180-8502-11eb-9b41-297d0cb83ed6.png)

Workflow using Terraform:

Network: 
1. Created a custom VPC
2. It includes 4 subnets - 2 Public and 2 Private
3. Internet Gateway for Public Subnet
4. Nat Gateways for Private Subnet
	- I have created 2 Nat gateways to provide internet connectivity to resources from private subnets.
5. Route table for Public and Private Subnets
6. Security Group for Webserver and EFS
	- Webserver-SG: Attached to ALB and EC2, only allowed port 80
	- EFS-SG: Attached to EFS, only allowed traffic from Webserver-sg on NFS port (TCP 2049)

Compute: 
1. Used Latest Ubuntu image
2. Created Application load balancer using all public subnets
3. Launch Configuration: This configuration will use latest ubuntu image, instance type, security group and gp2 storage.
4. Auto Scaling Group: Provided minimum / maximum / desired EC2 instances and healthcheck options. Also, all webservers will be created from private subnet in different Availability Zones.
5. Auto Scaling Policy: I have used Target tracking policy, this will add/remove instances to maintain CPU utilization at 50%
6. Userdata script: This script will update all packages from server.
	- It will install amazon-efs-utils
	- Create directories for logs and application storage
	- Mount EFS for logs and application storage
	- Add an entry in fstab to mount EFS on ec2 reboot
	- Install Apache2 webserver
	- Created a text file to print hostname in index.html file


Storage: 
1. Created 2 EFS for centralized storage and scaling
	- Webroot - To store application files
	- logs - To store apache server logs
