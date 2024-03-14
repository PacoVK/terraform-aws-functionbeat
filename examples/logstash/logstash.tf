provider "aws" {
  max_retries = 1337
  region      = "eu-central-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/16"
  tags = {
    Name = "Test-VPC"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, 10)
  availability_zone = "eu-central-1a"
  tags = {
    Name = "Private"
  }
}

resource "aws_cloudwatch_log_group" "example_logs" {
  name              = "MyExampleService"
  retention_in_days = 1
}

resource "aws_security_group" "functionbeat_securitygroup" {
  name   = "Functionbeat"
  vpc_id = aws_vpc.vpc.id

  egress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    description = "HTTPS"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "functionbeat" {
  source = "../.."

  application_name     = "crazy-test-module"
  functionbeat_version = "8.12.1"

  lambda_config = {
    name = "my-kibana-exporter"

    vpc_config = {
      vpc_id             = aws_vpc.vpc.id
      subnet_ids         = [aws_subnet.subnet.id]
      security_group_ids = [aws_security_group.functionbeat_securitygroup.id]
    }

    output_logstash = {
      hosts         = ["10.0.0.1:5044", "10.0.0.2:5044"]
      "ssl.enabled" = false
    }
  }

  loggroup_name = aws_cloudwatch_log_group.example_logs.name

  fb_extra_configuration = {
    fields = {
      env = "test",
      foo = "bar"
    }
    setup = {
      "template.settings" = {
        "index.number_of_shards" : 1
      }
      ilm = {
        enabled : true
        rollover_alias : "my-alias"
        pattern : "{now/d}-000001"
        policy_name : "index_curation"
      }
    }
    logging = {
      to_syslog : false
      to_eventlog : false
    }
    processors = [
      {
        add_cloud_metadata : null
      },
      {
        add_fields = {
          fields = {
            id   = "574734885120952459"
            name = "myproject"
          }
          target = "project"
        }
      }
    ]
  }
  fb_extra_tags = ["webserver", "testme"]
}
