#!/bin/bash

# Fix and redeploy script for myapp1 to AWS ECS Fargate

set -e

echo "🔧 Fixing and redeploying myapp1 to AWS ECS Fargate..."

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "📍 Using AWS Account: $AWS_ACCOUNT_ID"
echo "📍 Using AWS Region: $AWS_REGION"

# Apply Terraform configuration updates (for health check and security group fixes)
echo "🔧 Updating Terraform configuration..."
terraform plan -var="aws_region=$AWS_REGION"
terraform apply -var="aws_region=$AWS_REGION" -auto-approve

# Get ECR repository URL
ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
echo "📦 ECR Repository: $ECR_REPO_URL"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build Docker image with the fixed code
echo "🐳 Building Docker image with fixes..."
docker build -t myapp1 .

# Tag image for ECR
echo "🏷️  Tagging image for ECR..."
docker tag myapp1:latest $ECR_REPO_URL:latest

# Push image to ECR
echo "⬆️  Pushing fixed image to ECR..."
docker push $ECR_REPO_URL:latest

# Force ECS service to update with new image
echo "🔄 Updating ECS service with fixed image..."
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

aws ecs update-service \
    --cluster $ECS_CLUSTER \
    --service $ECS_SERVICE \
    --force-new-deployment \
    --region $AWS_REGION

echo "⏳ Waiting for deployment to complete..."
aws ecs wait services-stable \
    --cluster $ECS_CLUSTER \
    --services $ECS_SERVICE \
    --region $AWS_REGION

# Get load balancer URL
LB_URL=$(terraform output -raw load_balancer_url)
echo "✅ Fixed deployment completed!"
echo "🌐 Your application is available at: $LB_URL"
echo "🩺 Health check endpoint: $LB_URL/health"
echo ""

# Test the health endpoint
echo "🔍 Testing health endpoint..."
if curl -s -o /dev/null -w "%{http_code}" "$LB_URL/health" | grep -q "200"; then
    echo "✅ Health check passed!"
else
    echo "⚠️  Health check may still be initializing. Check logs with: ./check-logs.sh"
fi

echo ""
echo "📊 To check the status:"
echo "   ./check-logs.sh"
echo ""
echo "📝 To view logs:"
echo "   aws logs tail /ecs/myapp1 --follow --region $AWS_REGION"
