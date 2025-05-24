# AWS Architecture Diagram - MyApp1

## Architecture Overview

This diagram illustrates the AWS infrastructure for the MyApp1 application deployed using ECS Fargate.

```mermaid
graph TB
    %% Internet and Users
    Internet([Internet Users])
    
    %% AWS Cloud boundary
    subgraph AWS ["AWS Cloud (us-east-1)"]
        %% VPC boundary
        subgraph VPC ["VPC (10.0.0.0/16)"]
            %% Internet Gateway
            IGW[Internet Gateway<br/>myapp1-igw]
            
            %% Availability Zones
            subgraph AZ1 ["Availability Zone 1"]
                PubSub1[Public Subnet<br/>10.0.1.0/24]
                ECS1[ECS Task<br/>myapp1 container<br/>Port 8080]
            end
            
            subgraph AZ2 ["Availability Zone 2"]
                PubSub2[Public Subnet<br/>10.0.2.0/24]
                ECS2[ECS Task<br/>myapp1 container<br/>Port 8080]
            end
            
            %% Application Load Balancer
            ALB[Application Load Balancer<br/>myapp1-alb<br/>Port 80]
            
            %% Target Group
            TG[Target Group<br/>myapp1-tg<br/>Health Check: /health]
            
            %% Security Groups
            ALBSG[ALB Security Group<br/>Inbound: Port 80 from 0.0.0.0/0<br/>Outbound: All traffic]
            AppSG[App Security Group<br/>Inbound: Port 8080 from ALB SG<br/>Outbound: All traffic]
        end
        
        %% ECS Components
        subgraph ECS ["Amazon ECS"]
            Cluster[ECS Cluster<br/>myapp1-cluster]
            TaskDef[Task Definition<br/>myapp1<br/>Fargate, 256 CPU, 512 MB]
            Service[ECS Service<br/>myapp1-service<br/>Desired Count: 1]
        end
        
        %% ECR
        ECR[Amazon ECR<br/>myapp1 repository<br/>Docker images]
        
        %% CloudWatch
        CW[CloudWatch Logs<br/>/ecs/myapp1<br/>30 days retention]
        
        %% IAM
        IAM[IAM Role<br/>ECS Task Execution Role<br/>AmazonECSTaskExecutionRolePolicy]
    end
    
    %% CI/CD (GitHub Actions)
    subgraph CICD ["GitHub Actions CI/CD"]
        GHA[GitHub Actions<br/>Build & Deploy Pipeline]
        Docker[Docker Build<br/>linux/amd64]
    end
    
    %% Connections
    Internet --> ALB
    ALB --> TG
    TG --> ECS1
    TG --> ECS2
    
    IGW --> ALB
    ALB -.-> ALBSG
    ECS1 -.-> AppSG
    ECS2 -.-> AppSG
    
    Service --> ECS1
    Service --> ECS2
    TaskDef --> Service
    Cluster --> Service
    
    ECS1 --> CW
    ECS2 --> CW
    TaskDef -.-> IAM
    
    GHA --> Docker
    Docker --> ECR
    ECR --> TaskDef
    
    %% Styling
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef compute fill:#F58536,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef network fill:#8C4FFF,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef storage fill:#7AA116,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef security fill:#DD344C,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef external fill:#146EB4,stroke:#232F3E,stroke-width:2px,color:#fff
    
    class ALB,TG,IGW network
    class Cluster,Service,TaskDef,ECS1,ECS2 compute
    class ECR,CW storage
    class ALBSG,AppSG,IAM security
    class Internet,GHA,Docker external
```

## Component Details

### Networking Layer
- **VPC**: Custom VPC with CIDR 10.0.0.0/16
- **Subnets**: 2 public subnets across different AZs (10.0.1.0/24, 10.0.2.0/24)
- **Internet Gateway**: Provides internet access to public subnets
- **Route Table**: Routes traffic from public subnets to internet gateway

### Load Balancing
- **Application Load Balancer**: Internet-facing ALB listening on port 80
- **Target Group**: Routes traffic to ECS tasks on port 8080
- **Health Checks**: Configured to check `/health` endpoint

### Container Platform
- **ECS Cluster**: Fargate cluster for serverless container execution
- **Task Definition**: Defines container specifications (256 CPU, 512 MB memory)
- **ECS Service**: Manages desired count of tasks (currently 1)
- **Container**: .NET application running on port 8080

### Container Registry
- **ECR Repository**: Stores Docker images for the application
- **Image Scanning**: Enabled for security vulnerability scanning

### Security
- **ALB Security Group**: Allows inbound HTTP (port 80) from internet
- **App Security Group**: Allows inbound traffic (port 8080) only from ALB
- **IAM Role**: ECS task execution role with necessary permissions

### Monitoring & Logging
- **CloudWatch Logs**: Centralized logging with 30-day retention
- **Log Groups**: `/ecs/myapp1` for application logs

### CI/CD Pipeline
- **GitHub Actions**: Automated build and deployment
- **Docker Build**: Multi-platform build (linux/amd64)
- **ECR Push**: Pushes new images to ECR repository
- **ECS Update**: Updates service with new task definition

## Traffic Flow

1. **User Request**: Internet users access the application
2. **Load Balancer**: ALB receives requests on port 80
3. **Target Group**: Distributes traffic to healthy ECS tasks
4. **ECS Tasks**: Fargate tasks running in public subnets handle requests
5. **Logging**: Application logs sent to CloudWatch
6. **Health Checks**: ALB monitors task health via `/health` endpoint

## High Availability Features

- **Multi-AZ Deployment**: Tasks can run across multiple availability zones
- **Auto Scaling**: ECS service can scale based on demand (currently set to 1)
- **Health Monitoring**: Automatic replacement of unhealthy tasks
- **Rolling Updates**: Zero-downtime deployments via ECS service updates

## Security Features

- **Security Groups**: Network-level access control
- **Private Networking**: Tasks communicate via private IPs
- **IAM Roles**: Least privilege access for ECS tasks
- **ECR Scanning**: Vulnerability scanning for container images
