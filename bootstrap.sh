#!/bin/bash

# bootstrap script for an EKS cluster using AWS terraform modules
# requires kubectl, terraform, jq
#TODO
# ARN for nginx ingress is specified in env variable AWS_CERT_ARN=

function test_command {
    $1 2&>1 > /dev/null
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error with $2, please verify that this is installed" >&2
	exit 1
    else
	echo "$2 found..."
    fi
    return $status
}

# test for required binaries: test_command "command" "name"

test_command "aws --version" "aws cli"
test_command "aws-iam-authenticator help" "aws-iam-authenticator"
test_command "kubectl version" "kubectl"
test_command "jq --version" "jq"
test_command "helm home" "helm"


: ${AWS_REGION="us-east-1"}
export TF_VAR_aws_region=$AWS_REGION

#cluster name variable
: ${CLUSTER_NAME="eks-cluster"}
export TF_VAR_cluster_name=$CLUSTER_NAME

#external DNS name variable
: ${ELB_INGRESS_DOMAIN="gigantor.be"}

#external ingress host, wildcard by default
ELB_INGRESS_HOST="*"
ELB_HOST=$ELB_INGRESS_HOST.$ELB_INGRESS_DOMAIN

#pull hosted zone from domain and validate
AWS_ZONE_OUTPUT=`aws route53 list-hosted-zones --query "HostedZones[?Name=='${ELB_INGRESS_DOMAIN}.'] | [].Id" | grep hostedzone | cut -d "/" -f 3 | sed s/\"//`

if [ -z "$AWS_ZONE_OUTPUT" ]; then
    echo "The domain ${ELB_INGRESS_DOMAIN} is not an AWS hosted zone."
    exit 1
fi

ELB_DOMAIN_HOSTED_ZONE=$AWS_ZONE_OUTPUT

echo "AWS region: ${AWS_REGION}"
echo "cluster name: ${CLUSTER_NAME}"
echo "ingress domain: ${ELB_INGRESS_DOMAIN}"
echo "ingress hostname: ${ELB_HOST}"
echo "hosted domain (${ELB_INGRESS_DOMAIN}): ${ELB_DOMAIN_HOSTED_ZONE}"

#initialize tf and apply to build the cluster
#terraform init
#terraform apply

# apply nginx ingest yaml files to create ingress controller and ELB
#kubectl apply -f yaml/mandatory.yaml
#kubectl apply -f yaml/service-l7.yaml
#kubectl apply -f yaml/patch-configmap-l7.yaml

# create route53 DNS alias for ELB

# get ELB DNS name from cluster
ELB_DNS=`kubectl get svc -n ingress-nginx -o json | jq '.items | .[] | .status.loadBalancer.ingress | .[] | .hostname' | sed s/\"//g`

#AWS ELB hosted zone to add DNS, computed
ELB_AWS_HOSTED_ZONE=`aws elb describe-load-balancers --query "LoadBalancerDescriptions[?DNSName=='${ELB_DNS}'] | [].CanonicalHostedZoneNameID" | egrep -v -e "\[|\]" | sed s/\"//g | sed -e 's/^[[:space:]]*//'`

#output json file with ELB target, hosted zone, and hostname

cat <<EOF >dns.json
          {
            "Comment": "create route53 DNS alias for ELB",
            "Changes": [
              {
                "Action": "CREATE",
                "ResourceRecordSet": {
                  "Name": "${ELB_HOST}",
                  "Type": "A",
                  "AliasTarget": {
                    "HostedZoneId": "${ELB_AWS_HOSTED_ZONE}",
                    "DNSName": "${ELB_DNS}",
                    "EvaluateTargetHealth": false
                  }
                }
              }
            ]
          }
EOF

# create actual DNS entry via aws cli
#aws route53 change-resource-record-sets --hosted-zone-id ${ELB_DOMAIN_HOSTED_ZONE} --change-batch file://dns.json
