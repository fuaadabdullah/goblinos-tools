#!/usr/bin/env bash
# Test and Monitor Forge Lite API ECS Deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-staging}"
CLUSTER_NAME="forge-lite-${ENVIRONMENT}"
SERVICE_NAME="forge-lite-api-${ENVIRONMENT}"

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
        log_error "AWS CLI is not installed."
        exit 1
    fi

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS credentials are not configured."
        exit 1
    fi

    log_success "AWS credentials validated"
}

# Check ECS cluster status
check_cluster_status() {
    log_info "Checking ECS cluster status: $CLUSTER_NAME"

    CLUSTER_STATUS=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query "clusters[0].status" \
        --output text)

    if [[ "$CLUSTER_STATUS" == "ACTIVE" ]]; then
        log_success "ECS cluster is active"
    else
        log_error "ECS cluster status: $CLUSTER_STATUS"
        return 1
    fi
}

# Check ECS service status
check_service_status() {
    log_info "Checking ECS service status: $SERVICE_NAME"

    SERVICE_INFO=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query "services[0].[status,desiredCount,runningCount,pendingCount]" \
        --output text)

    read -r STATUS DESIRED RUNNING PENDING <<< "$SERVICE_INFO"

    echo "Service Status: $STATUS"
    echo "Desired Count: $DESIRED"
    echo "Running Count: $RUNNING"
    echo "Pending Count: $PENDING"

    if [[ "$STATUS" == "ACTIVE" && "$RUNNING" -eq "$DESIRED" && "$PENDING" -eq 0 ]]; then
        log_success "ECS service is healthy"
    else
        log_warning "ECS service may not be fully healthy"
        return 1
    fi
}

# Get service endpoint
get_service_endpoint() {
    log_info "Getting service endpoint..."

    # Get load balancer DNS name
    LB_DNS=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query "services[0].loadBalancers[0].targetGroupArn" \
        --output text)

    if [[ "$LB_DNS" != "None" && -n "$LB_DNS" ]]; then
        # Extract load balancer ARN and get DNS name
        LB_ARN=$(aws elbv2 describe-target-groups \
            --target-group-arns "$LB_DNS" \
            --region "$AWS_REGION" \
            --query "targetGroups[0].loadBalancerArns[0]" \
            --output text)

        if [[ "$LB_ARN" != "None" && -n "$LB_ARN" ]]; then
            ENDPOINT=$(aws elbv2 describe-load-balancers \
                --load-balancer-arns "$LB_ARN" \
                --region "$AWS_REGION" \
                --query "loadBalancers[0].DNSName" \
                --output text)

            log_info "Service endpoint: http://$ENDPOINT"
            return 0
        fi
    fi

    log_warning "Could not determine service endpoint (no load balancer configured)"
    return 1
}

# Test API health endpoint
test_api_health() {
    local ENDPOINT="$1"

    log_info "Testing API health endpoint: $ENDPOINT/health"

    if command -v curl >/dev/null 2>&1; then
        RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" "$ENDPOINT/health" || echo "HTTPSTATUS:000")

        HTTP_CODE=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

        if [[ "$HTTP_CODE" -eq 200 ]]; then
            log_success "API health check passed"
            echo "Response: $(echo "$RESPONSE" | sed -e 's/HTTPSTATUS.*//')"
        else
            log_error "API health check failed (HTTP $HTTP_CODE)"
            return 1
        fi
    else
        log_warning "curl not available, skipping health check"
    fi
}

# Show recent deployment events
show_deployment_events() {
    log_info "Recent deployment events:"

    aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query "services[0].events[0:5].[createdAt,message]" \
        --output table
}

# Show CloudWatch logs
show_logs() {
    local LINES="${1:-50}"

    log_info "Showing last $LINES lines of CloudWatch logs:"

    aws logs tail "/ecs/forge-lite-api" \
        --region "$AWS_REGION" \
        --follow false \
        --format short \
        --since 1h \
        | tail -n "$LINES"
}

# Get task information
get_task_info() {
    log_info "Getting task information:"

    TASK_ARNS=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --query "taskArns[]" \
        --output text)

    if [[ -n "$TASK_ARNS" ]]; then
        aws ecs describe-tasks \
            --cluster "$CLUSTER_NAME" \
            --tasks $TASK_ARNS \
            --region "$AWS_REGION" \
            --query "tasks[].{TaskARN:taskArn,LastStatus:lastStatus,DesiredStatus:desiredStatus,StartedAt:startedAt}" \
            --output table
    else
        log_warning "No tasks found"
    fi
}

# Force deployment
force_deployment() {
    log_info "Forcing new deployment..."

    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --region "$AWS_REGION" \
        --force-new-deployment

    log_success "Deployment triggered"
}

# Scale service
scale_service() {
    local COUNT="$1"

    log_info "Scaling service to $COUNT tasks..."

    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count "$COUNT" \
        --region "$AWS_REGION"

    log_success "Service scaled to $COUNT tasks"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    status          Show cluster and service status
    health          Test API health endpoint
    logs [LINES]    Show CloudWatch logs (default: 50 lines)
    events          Show recent deployment events
    tasks           Show running tasks
    deploy          Force new deployment
    scale COUNT     Scale service to COUNT tasks
    endpoint        Get service endpoint URL
    all             Run all checks

Environment variables:
    AWS_REGION      AWS region (default: us-east-1)
    ENVIRONMENT     Environment (staging/production, default: staging)

Examples:
    $0 status
    $0 logs 100
    $0 scale 2
    ENVIRONMENT=production $0 all

EOF
}

# Main execution
main() {
    local COMMAND="${1:-all}"

    check_aws_setup

    case "$COMMAND" in
        status)
            check_cluster_status
            check_service_status
            get_task_info
            ;;
        health)
            if get_service_endpoint; then
                ENDPOINT_VAR=$(get_service_endpoint 2>/dev/null || echo "")
                if [[ -n "$ENDPOINT_VAR" ]]; then
                    test_api_health "http://$ENDPOINT_VAR"
                fi
            fi
            ;;
        logs)
            show_logs "${2:-50}"
            ;;
        events)
            show_deployment_events
            ;;
        tasks)
            get_task_info
            ;;
        deploy)
            force_deployment
            ;;
        scale)
            if [[ -z "${2:-}" ]]; then
                log_error "Please specify task count: $0 scale COUNT"
                exit 1
            fi
            scale_service "$2"
            ;;
        endpoint)
            get_service_endpoint
            ;;
        all)
            log_info "Running all checks..."
            check_cluster_status
            check_service_status
            get_task_info
            show_deployment_events
            if get_service_endpoint 2>/dev/null; then
                ENDPOINT_VAR=$(get_service_endpoint 2>/dev/null || echo "")
                if [[ -n "$ENDPOINT_VAR" ]]; then
                    test_api_health "http://$ENDPOINT_VAR"
                fi
            fi
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"