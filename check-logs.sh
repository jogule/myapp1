#!/bin/bash

# Script to check ECS service status and logs

set -e

AWS_REGION="us-east-1"
CLUSTER_NAME="myapp1-cluster"
SERVICE_NAME="myapp1-service"
LOG_GROUP="/ecs/myapp1"

echo "🔍 Checking ECS Service Status..."
echo "=================================="

# Check service status
echo "📊 Service Overview:"
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,TaskDefinition:taskDefinition,Deployments:deployments[0].status}' \
    --output table

echo ""
echo "📋 Task Details:"
# Get running tasks
TASK_ARNS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'taskArns' \
    --output text)

if [ ! -z "$TASK_ARNS" ]; then
    echo "Tasks found: $TASK_ARNS"
    
    # Describe tasks
    aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARNS \
        --region $AWS_REGION \
        --query 'tasks[].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,StoppedReason:stoppedReason,Containers:containers[].{Name:name,LastStatus:lastStatus,Reason:reason,ExitCode:exitCode}}' \
        --output table
else
    echo "No tasks currently running"
    
    # Check stopped tasks for debugging
    echo ""
    echo "🔍 Checking recent stopped tasks:"
    STOPPED_TASKS=$(aws ecs list-tasks \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --desired-status STOPPED \
        --region $AWS_REGION \
        --query 'taskArns[0:3]' \
        --output text)
    
    if [ ! -z "$STOPPED_TASKS" ] && [ "$STOPPED_TASKS" != "None" ]; then
        aws ecs describe-tasks \
            --cluster $CLUSTER_NAME \
            --tasks $STOPPED_TASKS \
            --region $AWS_REGION \
            --query 'tasks[].{TaskArn:taskArn,LastStatus:lastStatus,StoppedReason:stoppedReason,StoppedAt:stoppedAt,Containers:containers[].{Name:name,LastStatus:lastStatus,Reason:reason,ExitCode:exitCode}}' \
            --output table
    fi
fi

echo ""
echo "📝 Recent CloudWatch Logs:"
echo "==========================="

# Get recent logs
aws logs tail $LOG_GROUP \
    --since 30m \
    --region $AWS_REGION \
    --format short || echo "No logs found or log group doesn't exist"

echo ""
echo "🔧 Service Events (last 10):"
echo "============================"

# Get service events
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION \
    --query 'services[0].events[0:10].{CreatedAt:createdAt,Message:message}' \
    --output table

echo ""
echo "💡 Health Check Info:"
echo "===================="

# Check target group health
TG_ARN=$(aws elbv2 describe-target-groups \
    --names "myapp1-tg" \
    --region $AWS_REGION \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "Target group not found")

if [ "$TG_ARN" != "None" ] && [ ! -z "$TG_ARN" ]; then
    echo "Target Group: $TG_ARN"
    aws elbv2 describe-target-health \
        --target-group-arn $TG_ARN \
        --region $AWS_REGION \
        --query 'TargetHealthDescriptions[].{Target:Target.Id,HealthStatus:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}' \
        --output table || echo "Could not retrieve target health"
else
    echo "Target group not accessible"
fi
