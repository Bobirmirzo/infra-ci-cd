# Automating Terraform in Github Actions with self-host runner in AWS

This repository aims to create Infra-CI-CD pipeline by using Github Actions with Self-host runner in ECS for the infrastructure in AWS

## Introduction

Figure below represents Diagram of Infra-CI-CD we are going to build in this article. The diagram consists of following features:

![](Infra-CI-CD-diagram.png)

Feature                       | Role
----------------------------- | -------------
Main application environment  | This is the environment where our application runs. For the simplicity. I only included some services including RDS and EC2 instance in Private Subnets. This infrastructure will be built with Terraform and be target of our CI-CD pipeline: we are going to build CI-CD to change the services in this environment.
Self-host runner environment  | This is the environment where our self-host runners for Github actions run and make changes to the application environment. Note that instead of self-host runners, you can also run default runners of Github Actions. However, in this case security problem arises: you should give this runner very strong "AWS Admin role" in order to change services. Furthermore, in order to access to AWS, this default runner should get AWS Secret Access Keys and IDs. I found that submitting these secrets and role to Github Actions and Runner is dangerous and decided to use self-host runners in AWS ECS with Admin Role which is located safely in private subnet under my control and get any secrets (e.g. github tokens) from Secrets Manager. If you want, you can reduce permissions for the runner. For example, if it is required to change ECS, you can give the runner only ECS Admin. This environment for self-host runner is also built with Terraform which I am going to show later.
Github Actions               | When a code is committed to Github and Pull request is created, Github Actions are run with self-host runner and CI is started. There are following steps in CI: Lint check, Terraform code format check, Security check (checks if there is any security issue in the changed application Terraform file), Terraform code validation check, Terraform plan (to see what changes will occur), Create notification to Github Comment about changes in AWS services in application environment. <br /> If you merge the code to the master branch, CD starts in self-host runner. CD includes following steps: <br /> 1. Terraform apply: apply the code and make changes to the infrastructure environment　<br /> 2. Send notification to Slack channel about changes in services so that your team can see what services have been added, removed or changed. <br />
S3 bucket | In order to keep terraform state file, S3 bucket is used. Self-host runner accesses to this bucket and understands the current state of the application environment and conducts CI-CD.

## Building Infra-CI-CD

## Environment setup

Setting environment variables:
```
export PAT={YOUR_GITHUB_PERSONAL_TOKEN_HERE}
export ORG={YOUR_GITHUB_ORG_HERE}
export REPO={YOUR_GITHUB_REPO_NAME_HERE}
export AWS_DEFAULT_REGION={YOUR_AWS_DEFAULT_REGION_HERE}
export AWS_SECRET_ACCESS_KEY={YOUR_AWS_SECRET_ACCESS_KEY_HERE}
export AWS_ACCESS_KEY_ID={YOUR_AWS_ACCESS_KEY_ID_HERE}
export AWS_ACCOUNT_ID={YOUR_AWS_ACCOUNT_ID_HERE}
```

## Create S3 buckets used as backend

We should create two S3 buckets as backend: one for "Terraform state-file used to create Application environment" and another for "Terraform state-file used to create self-host-runner environment". The settings of the backends have already been done in backend files:

1. [Application environment Terraform backend file](backend.tf)<br />
2. [Self-host runner environment Terraform backend file](self-host-runner-ECS/backend.tf)

You should create manually buckets with the names "self-host-runner-bucket" and "app-infra-state-bucket" as defined in the files. If your default region is different from "ap-northeast-1", do not forget to change default region in the files to your region.

## Creating application environment

Let us create application environment. Pull the source code from the Github and run following codes:

```
# Initiate terraform
terraform init
# Check which resources will be created
terraform plan
# Create environment
terraform apply
```

## Creating self-host runner

After creating application environment above, we switch to creating self-host runner and its running environment in the same AWS account. The code to create the runner and its running environment have already been written in "self-host-runner-ECS" folder in the same Github repository above. Enter the folder and run following codes:

```
# Initiate terraform
terraform init
# Create environment
./tf_apply.sh
```

The above code creates an environment for self-host runner to run and ECR repository for us to push runner's container. Now, we should create container and push it to ECR as follows:

```
# Login to registry
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com
# Create a container
docker build -f Dockerfile -q -t ecs-runner .
docker tag ecs-runner $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-runner
# Push the container to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/ecs-runner
# Start the runner
aws ecs update-service --cluster ecs-runner-cluster --service ecs-runner-ecs-service --force-new-deployment
```

After running the above code, the self-host runners in AWS for github-actions starts in the form of Fargate instances (autoscaling: max=2 and min=1) and you should see it running in Github.

## Setting Github Actions

Before creating workflow files, save below secrets to your Repository's Github Secrets:

```
1. SLACK_TOKEN
2. SLACK_CHANNEL_ID
3. SLACK_BOT_NAME
4. AWS_ACCOUNT_ID
5. GITHUB_TOKEN
```

Furthermore, enter .tfnotify folder and fill in below points in github.yml file:

```
.......
owner: "{your org}"
name: "{your repo name}"
........
```

In order github actions to run, you need workflow files. I have created workflow files for both CI and CD in ".github" folder. There you can see all of the jobs done in CI-CD pipeline. Just include these files as they are along with above run terraform files and push to your repository.

YOUR PIPELINE IS READY. THAT IS IT!!!!
