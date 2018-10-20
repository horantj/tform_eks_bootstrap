#!/bin/bash

# bootstrap script for an EKS cluster using AWS terraform modules
# requires kubectl, terraform, jq
#TODO
# ARN for nginx ingress is specified in env variable AWS_CERT_ARN=

#cluster name variable
: ${TF_VAR_cluster_name="eks-cluster"}

#external DNS name variable
ELB_HOST="*.gigantor.be"
HOSTED_ZONE="Z2D252C5RIIP8I"
ELB_ZONE="Z35SXDOTRQ7X7K"

#initialize tf and apply to build the cluster
#terraform init
#terraform apply

# apply nginx ingest yaml files to create ingress controller and ELB
#kubectl apply -f yaml/mandatory.yaml
#kubectl apply -f yaml/service-l7.yaml
#kubectl apply -f yaml/patch-configmap-l7.yaml

# create route53 DNS alias for ELB

# get ELB DNS name from cluster
ELB_DNS=`kubectl get svc -n ingress-nginx -o json | jq '.items | .[] | .status.loadBalancer.ingress | .[] | .hostname'`

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
                    "HostedZoneId": "${ELB_ZONE}",
                    "DNSName": ${ELB_DNS},
                    "EvaluateTargetHealth": false
                  }
                }
              }
            ]
          }
EOF

# create actual DNS entry via aws cli
aws route53 change-resource-record-sets --hosted-zone-id ${HOSTED_ZONE} --change-batch file://dns.json
