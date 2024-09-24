
Use below terraform .tf file to create EKS cluster with node-groups and bastion server:


# main.tf


provider "aws" {
 region = "us-west-2" # Specify your region
}


# VPC creation with public and private subnets
resource "aws_vpc" "eks_vpc" {
 cidr_block           = "10.0.0.0/16"
 enable_dns_support   = true
 enable_dns_hostnames = true
 tags = {
   Name = "eks-vpc"
 }
}


resource "aws_subnet" "public_subnet_a" {
 vpc_id                  = aws_vpc.eks_vpc.id
 cidr_block              = "10.0.4.0/24"
 availability_zone       = "us-west-2a"
 map_public_ip_on_launch = true
 tags = {
   Name = "eks-public-subnet-a"
 }
}


resource "aws_subnet" "public_subnet_b" {
 vpc_id                  = aws_vpc.eks_vpc.id
 cidr_block              = "10.0.5.0/24"
 availability_zone       = "us-west-2b"
 map_public_ip_on_launch = true
 tags = {
   Name = "eks-public-subnet-b"
 }
}


resource "aws_subnet" "private_subnet_a" {
 vpc_id            = aws_vpc.eks_vpc.id
 cidr_block        = "10.0.1.0/24"
 availability_zone = "us-west-2a"
 tags = {
   Name = "eks-private-subnet-a"
 }
}


resource "aws_subnet" "private_subnet_b" {
 vpc_id            = aws_vpc.eks_vpc.id
 cidr_block        = "10.0.2.0/24"
 availability_zone = "us-west-2b"
 tags = {
   Name = "eks-private-subnet-b"
 }
}


# Internet Gateway for public access
resource "aws_internet_gateway" "eks_igw" {
 vpc_id = aws_vpc.eks_vpc.id
 tags = {
   Name = "eks-igw"
 }
}


# Route Table for Public Subnets
resource "aws_route_table" "public_route_table" {
 vpc_id = aws_vpc.eks_vpc.id
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.eks_igw.id
 }


 tags = {
   Name = "eks-public-route-table"
 }
}


# Associate public subnets with public route table
resource "aws_route_table_association" "public_subnet_a_association" {
 subnet_id      = aws_subnet.public_subnet_a.id
 route_table_id = aws_route_table.public_route_table.id
}


resource "aws_route_table_association" "public_subnet_b_association" {
 subnet_id      = aws_subnet.public_subnet_b.id
 route_table_id = aws_route_table.public_route_table.id
}


# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
 #vpc = true


}


resource "aws_nat_gateway" "eks_nat_gw" {
 allocation_id = aws_eip.nat_eip.id
 subnet_id     = aws_subnet.public_subnet_a.id
 tags = {
   Name = "eks-nat-gateway"
 }
}


# Route Table for Private Subnets
resource "aws_route_table" "private_route_table" {
 vpc_id = aws_vpc.eks_vpc.id


 route {
   cidr_block     = "0.0.0.0/0"
   nat_gateway_id = aws_nat_gateway.eks_nat_gw.id
 }


 tags = {
   Name = "eks-private-route-table"
 }
}


resource "aws_route_table_association" "private_subnet_a_association" {
 subnet_id      = aws_subnet.private_subnet_a.id
 route_table_id = aws_route_table.private_route_table.id
}


resource "aws_route_table_association" "private_subnet_b_association" {
 subnet_id      = aws_subnet.private_subnet_b.id
 route_table_id = aws_route_table.private_route_table.id
}


# Security Group for EKS cluster and nodes
resource "aws_security_group" "eks_security_group" {
 vpc_id = aws_vpc.eks_vpc.id


 ingress {
   from_port   = 443
   to_port     = 443
   protocol    = "tcp"
   cidr_blocks = ["0.0.0.0/0"]
 }


 egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }


 tags = {
   Name = "eks-security-group"
 }
}


# IAM Role for EKS cluster
resource "aws_iam_role" "eks_role" {
 name = "eks-cluster-role"


 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [{
     Action = "sts:AssumeRole"
     Effect = "Allow"
     Principal = {
       Service = "eks.amazonaws.com"
     }
   }]
 })


 tags = {
   Name = "eks-cluster-role"
 }
}


resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
 role       = aws_iam_role.eks_role.name
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_iam_role_policy_attachment" "eks_service_policy_attachment" {
 role       = aws_iam_role.eks_role.name
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}


# EKS Cluster creation
resource "aws_eks_cluster" "eks_cluster" {
 name     = "eks-cluster"
 role_arn = aws_iam_role.eks_role.arn


 vpc_config {
   subnet_ids = [
     aws_subnet.private_subnet_a.id,
     aws_subnet.private_subnet_b.id
   ]


   security_group_ids = [
     aws_security_group.eks_security_group.id
   ]
 }


 tags = {
   Name = "eks-cluster"
 }
}


# IAM Role for EKS worker nodes
resource "aws_iam_role" "eks_worker_role" {
 name = "eks-worker-role"


 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [{
     Action = "sts:AssumeRole"
     Effect = "Allow"
     Principal = {
       Service = "ec2.amazonaws.com"
     }
   }]
 })


 tags = {
   Name = "eks-worker-role"
 }
}


resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
 role       = aws_iam_role.eks_worker_role.name
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
 role       = aws_iam_role.eks_worker_role.name
 policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


resource "aws_iam_role_policy_attachment" "ec2_container_registry_policy" {
 role       = aws_iam_role.eks_worker_role.name
 policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# EKS Managed Node Group
resource "aws_eks_node_group" "eks_node_group" {
 cluster_name    = aws_eks_cluster.eks_cluster.name
 node_group_name = "eks-node-group"
 node_role_arn   = aws_iam_role.eks_worker_role.arn
 subnet_ids      = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]


 scaling_config {
   desired_size = 2
   max_size     = 3
   min_size     = 1
 }


 instance_types = ["t3.medium"]
 ami_type       = "AL2_x86_64"
}


# Security Group for Bastion Server
resource "aws_security_group" "bastion_sg" {
 name        = "bastion-sg"
 description = "Allow SSH inbound traffic"
 vpc_id      = aws_vpc.eks_vpc.id


 ingress {
   description = "SSH"
   from_port   = 22
   to_port     = 22
   protocol    = "tcp"
   cidr_blocks = ["0.0.0.0/0"] # Restrict this for production environments
 }


 egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
resource "aws_key_pair" "demo-key" {
 key_name   = "demo-key"
 public_key = file("/home/admin1/terraform/demo-key.pub")
}


output "private-key" {
 value     = aws_key_pair.demo-key
 sensitive = true
}


# Bastion EC2 Instance
resource "aws_instance" "bastion" {
 ami             = "ami-05134c8ef96964280" # Ubuntu 20.04 AMI
 instance_type   = "t3.micro"
 subnet_id       = aws_subnet.public_subnet_a.id
 key_name        = aws_key_pair.demo-key.key_name # Ensure you have this key pair created
 security_groups = [aws_security_group.bastion_sg.id]
}
 


