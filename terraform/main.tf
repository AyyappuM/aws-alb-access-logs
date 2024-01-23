variable "profile" {
  type    = string
  default = "a2"
}

variable "resource_prefix" {
  type    = string
  default = "ayyappu"
}

variable "account_number" {
  type    = string
}

variable "elb_account_id_for_mumbai" {
  type    = string
  default = "718504428378"
}

provider "aws" {
  region  = "ap-south-1"
  profile = "${var.profile}"
}

# Data block to retrieve default VPC ID
data "aws_vpc" "default" {
  default = true
}

# Use the default VPC ID
# subnet_1
resource "aws_subnet" "subnet_1" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.0/27"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.resource_prefix}-subnet-1"
  }
}

# subnet_2
resource "aws_subnet" "subnet_2" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.0.32/27"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.resource_prefix}-subnet-2"
  }
}

# ALB SG
resource "aws_security_group" "alb_sg" {
  name        = "${var.resource_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "my_alb" {
  name               = "${var.resource_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs_bucket.bucket
    prefix  = "alb-logs"
    enabled = true
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs_bucket" {
  bucket = "${var.resource_prefix}-test-bucket"
  force_destroy = true
}

# S3 bucket policy for ALB access logs
resource "aws_s3_bucket_policy" "alb_logs_bucket_policy" {
  bucket = aws_s3_bucket.alb_logs_bucket.bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.account_number}:root"
        },
        Action = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.alb_logs_bucket.bucket}/*"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id_for_mumbai}:root"
        },
        Action = "s3:PutObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.alb_logs_bucket.bucket}/*"
      }
    ]
  })
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-test-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS-managed policy AWSLambdaBasicExecutionRole to the Lambda Execution Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# Lambda Function
resource "aws_lambda_function" "lambda_function" {
  function_name    = "${var.resource_prefix}-test-function"
  filename         = "function.zip"
  handler          = "index.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_role.arn
  source_code_hash = filebase64("function.zip")
}

# Lambda Function Permission
resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "GiveELBPermissionToAccessLambdaFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
}

# Lambda Target Group
resource "aws_lb_target_group" "lambda_target_group" {
  name     = "${var.resource_prefix}-test-target-group"
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  target_type = "lambda"
}

# Register Targets in the Lambda Target Group
resource "aws_lb_target_group_attachment" "lambda_target_attachment" {
  depends_on = [aws_lambda_permission.lambda_permission]
  target_group_arn = aws_lb_target_group.lambda_target_group.arn
  target_id        = aws_lambda_function.lambda_function.arn
}

# ALB Listener
resource "aws_lb_listener" "lambda_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda_target_group.arn
  }
}

# --------------------------------------- ATHENA ---------------------------------------

# Create S3 Bucket
resource "aws_s3_bucket" "athena_bucket" {
  bucket = "${var.resource_prefix}-test-bucket-athena"
  force_destroy = true
}

# Update Athena Workgroup
resource "null_resource" "update_primary_workgroup" {
  depends_on = [aws_s3_bucket.athena_bucket]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "./update_workgroup.sh"
  }
}

# --------------------------------------- OUTPUT ---------------------------------------

# Output the subnet ID 1
output "subnet_1_id" {
  value = aws_subnet.subnet_1.id
}

# Output the subnet ID 2
output "subnet_2_id" {
  value = aws_subnet.subnet_2.id
}

output "alb_dns_name" {
  value = aws_lb.my_alb.dns_name
}

output "alb_logs_bucket_name" {
  value = aws_s3_bucket.alb_logs_bucket.bucket
}
