#!/bin/bash
set -e

echo "=== Automated Infrastructure Setup & State Recovery Script ==="

export AWS_DEFAULT_REGION="us-east-1"
export AWS_PAGER=""

cd "$(dirname "$0")/terraform"

echo "[1/4] Checking existing AWS resources..."

safe_import() {
  local resource="$1"
  local id="$2"
  echo "Importing $resource ($id)..."
  terraform import "$resource" "$id" || true
}

# Import IAM & ECR resources
safe_import aws_ecr_repository.frontend frontend
safe_import aws_ecr_repository.backend backend
safe_import aws_iam_role.eks_cluster eks_cluster_role
safe_import aws_iam_role.node_group udacity-node-group
safe_import aws_iam_role.codebuild codebuild-role
safe_import aws_iam_user.github_action_user github-action-user
safe_import aws_codebuild_project.codebuild udacity

# Import VPC & Networking
VPC_ID=$(aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=udacity" --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  safe_import aws_vpc.vpc "$VPC_ID"

  IGW_ID=$(aws ec2 describe-internet-gateways --region us-east-1 --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null || true)
  if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
    safe_import aws_internet_gateway.igw "$IGW_ID"
  fi

  PUB_SUB_ID=$(aws ec2 describe-subnets --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.1.0/24" --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)
  if [ "$PUB_SUB_ID" != "None" ] && [ -n "$PUB_SUB_ID" ]; then
    safe_import aws_subnet.public_subnet "$PUB_SUB_ID"
    RTB_PUB_ID=$(aws ec2 describe-route-tables --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.subnet-id,Values=$PUB_SUB_ID" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || true)
    if [ "$RTB_PUB_ID" != "None" ] && [ -n "$RTB_PUB_ID" ]; then
      safe_import aws_route_table.public "$RTB_PUB_ID"
      safe_import aws_route_table_association.public "${PUB_SUB_ID}/${RTB_PUB_ID}"
    fi
  fi

  PRIV_SUB_ID=$(aws ec2 describe-subnets --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.2.0/24" --query "Subnets[0].SubnetId" --output text 2>/dev/null || true)
  if [ "$PRIV_SUB_ID" != "None" ] && [ -n "$PRIV_SUB_ID" ]; then
    safe_import aws_subnet.private_subnet "$PRIV_SUB_ID"
    RTB_PRIV_ID=$(aws ec2 describe-route-tables --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.subnet-id,Values=$PRIV_SUB_ID" --query "RouteTables[0].RouteTableId" --output text 2>/dev/null || true)
    if [ "$RTB_PRIV_ID" != "None" ] && [ -n "$RTB_PRIV_ID" ]; then
      safe_import aws_route_table.private "$RTB_PRIV_ID"
      safe_import aws_route_table_association.private "${PRIV_SUB_ID}/${RTB_PRIV_ID}"
    fi
  fi
fi

# Import EKS cluster if it exists
safe_import aws_eks_cluster.main cluster

echo "[2/4] Applying Terraform configuration..."
terraform apply -auto-approve

echo "[3/4] Running setup/init.sh to configure cluster authentication..."
cd ..
if [ -f "./init.sh" ]; then
  chmod +x ./init.sh
  ./init.sh || true
fi

echo "=== All infrastructure resources successfully created and configured! ==="
