provider "aws" {
	region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.46.0"
  cidr = "10.0.0.0/16"
  name = "${var.cluster-name}"
  tags = "${
    map(
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"

  azs = ["us-east-1a", "us-east-1b"]
  public_subnets        = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_tags   = "${
    map(
     "Name", "${var.cluster-name}-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"

  enable_dns_hostnames = "true"
  enable_dns_support = "true"
  igw_tags =  "${
    map(
     "Name", "${var.cluster-name}",
    )
  }"  

}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "1.7.0"
  cluster_name          = "${var.cluster-name}"
  subnets               = ["${module.vpc.public_subnets}"]
  tags                  = {Environment = "test"}
  vpc_id                = "${module.vpc.vpc_id}"
}
