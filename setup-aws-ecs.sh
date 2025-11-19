#!/usr/bin/env bash
# AWS ECS Infrastructure Setup Script for Forge Lite API
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Update these values for your environment
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-staging}"
CLUSTER_NAME="forge-lite-${ENVIRONMENT}"
SERVICE_NAME="forge-lite-api-${ENVIRONMENT}"
REPO_NAME="forge-lite-api"
VPC_ID="${VPC_ID:-}"  # Set this if you have an existing VPC
SUBNET_IDS="${SUBNET_IDS:-}"  # Set these if you have existing subnets
SECURITY_GROUP_ID="${SECURITY_GROUP_ID:-}"  # Set this if you have an existing SG

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check AWS CLI and credentials
check_aws_setup() {
    log_info "Checking AWS CLI and credentials..."

    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI is not installed. Please install it first."
        log_info "Installation instructions: https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials are not configured or invalid."
        log_info "Please run: aws configure"
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_success "AWS credentials validated for account: $ACCOUNT_ID"
}

# Create ECR repository
create_ecr_repo() {
    log_info "Creating ECR repository: $REPO_NAME"

    if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_warning "ECR repository $REPO_NAME already exists"
    else
        aws ecr create-repository \
            --repository-name "$REPO_NAME" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --image-tag-mutability MUTABLE

        log_success "Created ECR repository: $REPO_NAME"
    fi

    # Get the full repository URI
    ECR_URI=$(aws ecr describe-repositories \
        --repository-names "$REPO_NAME" \
        --region "$AWS_REGION" \
        --query "repositories[0].repositoryUri" \
        --output text)

    log_info "ECR Repository URI: $ECR_URI"
}

# Create VPC and networking resources (if not provided)
create_vpc_resources() {
    if [[ -n "$VPC_ID" && -n "$SUBNET_IDS" && -n "$SECURITY_GROUP_ID" ]]; then
        log_info "Using existing VPC resources"
        return
    fi

    log_info "Creating VPC and networking resources..."

    # Create VPC
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 \
        --region "$AWS_REGION" \
        --query 'Vpc.VpcId' \
        --output text)

    log_success "Created VPC: $VPC_ID"

    # Create subnets
    SUBNET_1=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.1.0/24 \
        --availability-zone "${AWS_REGION}a" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)

    SUBNET_2=$(aws ec2 create-subnet \
        --vpc-id "$VPC_ID" \
        --cidr-block 10.0.2.0/24 \
        --availability-zone "${AWS_REGION}b" \
        --region "$AWS_REGION" \
        --query 'Subnet.SubnetId' \
        --output text)

    SUBNET_IDS="$SUBNET_1,$SUBNET_2"
    log_success "Created subnets: $SUBNET_IDS"

    # Create security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "forge-lite-api-${ENVIRONMENT}" \
        --description "Security group for Forge Lite API" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text)

    # Add inbound rule for port 8000
    aws ec2 authorize-security-group-ingress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 8000 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION"

    log_success "Created security group: $SECURITY_GROUP_ID"

    # Create Internet Gateway
    IGW_ID=$(aws ec2 create-internet-gateway \
        --region "$AWS_REGION" \
        --query 'InternetGateway.InternetGatewayId' \
        --output text)

    aws ec2 attach-internet-gateway \
        --internet-gateway-id "$IGW_ID" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION"

    # Create route table
    RT_ID=$(aws ec2 create-route-table \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'RouteTable.RouteTableId' \
        --output text)

    aws ec2 create-route \
        --route-table-id "$RT_ID" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$IGW_ID" \
        --region "$AWS_REGION" >/dev/null

    # Associate route table with subnets
    aws ec2 associate-route-table \
        --route-table-id "$RT_ID" \
        --subnet-id "$SUBNET_1" \
        --region "$AWS_REGION" >/dev/null

    aws ec2 associate-route-table \
        --route-table-id "$RT_ID" \
        --subnet-id "$SUBNET_2" \
        --region "$AWS_REGION" >/dev/null

    log_success "Created networking resources"
}

# Create ECS cluster
create_ecs_cluster() {
    log_info "Creating ECS cluster: $CLUSTER_NAME"

    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" \
        --query "clusters[?status=='ACTIVE']" | grep -q "$CLUSTER_NAME"; then
        log_warning "ECS cluster $CLUSTER_NAME already exists"
    else
        aws ecs create-cluster \
            --cluster-name "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --settings name=containerInsights,value=enabled

        log_success "Created ECS cluster: $CLUSTER_NAME"
    fi
}

# Create CloudWatch log group
create_log_group() {
    log_info "Creating CloudWatch log group: /ecs/forge-lite-api"

    if aws logs describe-log-groups \
        --log-group-name-prefix "/ecs/forge-lite-api" \
        --region "$AWS_REGION" | grep -q "/ecs/forge-lite-api"; then
        log_warning "CloudWatch log group /ecs/forge-lite-api already exists"
    else
        aws logs create-log-group \
            --log-group-name "/ecs/forge-lite-api" \
            --region "$AWS_REGION"

        log_success "Created CloudWatch log group: /ecs/forge-lite-api"
    fi
}

# Register task definition
register_task_definition() {
    log_info "Registering ECS task definition"

    # Use the task definition from the infra directory
    TASK_DEF_FILE="$REPO_ROOT/infra/deployments/ecs/task-definition.json"

    if [[ ! -f "$TASK_DEF_FILE" ]]; then
        log_error "Task definition file not found: $TASK_DEF_FILE"
        exit 1
    fi

    # Update the family name in the task definition
    sed -i.bak "s/\"family\": \"forge-lite-api-task\"/\"family\": \"forge-lite-api-${ENVIRONMENT}\"/" "$TASK_DEF_FILE"

    aws ecs register-task-definition \
        --cli-input-json "file://$TASK_DEF_FILE" \
        --region "$AWS_REGION"

    # Restore original file
    mv "$TASK_DEF_FILE.bak" "$TASK_DEF_FILE"

    log_success "Registered task definition: forge-lite-api-${ENVIRONMENT}"
}

# Create ECS service
create_ecs_service() {
    log_info "Creating ECS service: $SERVICE_NAME"

    # Get subnet IDs as array
    IFS=',' read -ra SUBNET_ARRAY <<< "$SUBNET_IDS"

    if aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query "services[?status=='ACTIVE']" | grep -q "$SERVICE_NAME"; then
        log_warning "ECS service $SERVICE_NAME already exists"
    else
        aws ecs create-service \
            --cluster "$CLUSTER_NAME" \
            --service-name "$SERVICE_NAME" \
            --task-definition "forge-lite-api-${ENVIRONMENT}" \
            --desired-count 1 \
            --launch-type FARGATE \
            --network-configuration "awsvpcConfiguration={subnets=[${SUBNET_ARRAY[0]},${SUBNET_ARRAY[1]}],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
            --region "$AWS_REGION" \
            --load-balancers "targetGroupArn=$TARGET_GROUP_ARN,containerName=forge-lite-api,containerPort=8000" \
            --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"

        log_success "Created ECS service: $SERVICE_NAME"
    fi
}

# Generate GitHub secrets documentation
generate_github_secrets() {
    log_info "Generating GitHub secrets setup instructions..."

    cat << EOF

# GitHub Repository Secrets Setup
# Go to: https://github.com/your-org/your-repo/settings/secrets/actions

## Required Secrets:

AWS_ACCESS_KEY_ID = $(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY = $(aws configure get aws_secret_access_key)
AWS_REGION = $AWS_REGION
ECR_REPOSITORY = $ECR_URI

## Copy these values to your GitHub repository secrets.

EOF
}

# Main execution
main() {
    log_info "Setting up AWS infrastructure for Forge Lite API deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Region: $AWS_REGION"

    check_aws_setup
    create_ecr_repo
    create_vpc_resources
    create_ecs_cluster
    create_log_group
    register_task_definition
    create_ecs_service
    generate_github_secrets

    log_success "AWS infrastructure setup complete!"
    log_info "Next steps:"
    log_info "1. Set up GitHub repository secrets (see above)"
    log_info "2. Push code to trigger deployment"
    log_info "3. Monitor logs: aws logs tail /ecs/forge-lite-api --region $AWS_REGION --follow"
}

# Run main function
main "$@"