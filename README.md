# README #

### [DEPRECATION NOTICE] ###
Functionbeat has been deprecated in favor to the new [Elastic Serverless Forwarder](https://www.elastic.co/guide/en/esf/current/aws-elastic-serverless-forwarder.html). Fortunately, Elastic Serverless Forwarder ships with a [Terraform deployment capability](https://www.elastic.co/guide/en/esf/current/aws-deploy-elastic-serverless-forwarder.html#aws-serverless-forwarder-deploy-terraform).  
This module will **stay maintained, but no additional features** will be added.

> INFO: AWS deprecated the golang runtime. This module now uses the alternative way to run go binaries using `provided.al2` runtime. This requires a Functionbeat version of at least `8.12.1`.
If you need to run a prior version you must use module version < 3.x. The full `provided.al2` runtime was heavily supported by [lutz108](https://github.com/lutz108)!

## What is this module for? ##

Terraform wrapper module to ship Cloudwatch Logs to Kibana via Functionbeat. See [official Docs](https://www.elastic.co/guide/en/beats/functionbeat/current/index.html). <br/>
The official Functionbeat is based on Cloudformation and also ships with a deployment CLI. If you prefer to stick to Terraform you cannot use Functionbeat alongside your infrastructure code base. This module wrapps the base function to package the Functionbeat lambda and actually deploys via Terraform. 

## Requirements ##
Since this module executes a script ensure your machine has the following software available:
* jq
* curl
* tar
* zip
* unzip
* openssl

### Running under Alpine ###
:information_source: 
The Functionbeat installer is not compatible with Alpine, due to missing libc. To be able to use this module on Alpine,
eg. in a CI pipeline, you need to provide the missing dependencies. 
You can install libc6-compat using ``apk add --no-cache libc6-compat``. 

## Simple example ##

For detailed example please refer to this [blog post](https://medium.com/@pascal-euhus/terraform-functionbeat-e481554d729e) using Elasticsearch output
Please note that output to Logstash is also possible, but in this example we
use Elasticsearch.

````terraform
resource "aws_security_group" "functionbeat_securitygroup" {
  name   = "Functionbeat"
  vpc_id = data.aws_vpc.vpc.id

  egress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    description = "HTTPS"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "functionbeat" {
  source = "git::ssh://git@github.com:PacoVK/functionbeat.git"

  application_name     = "crazy-test-application"
  functionbeat_version = "7.17.1"
  lambda_config = {
    name = "my-kibana-exporter"

    vpc_config = {
      vpc_id             = data.aws_vpc.vpc.id
      subnet_ids         = data.aws_subnets.private.ids
      security_group_ids = [aws_security_group.functionbeat_securitygroup.id]
    }

    output_elasticsearch = {
      hosts : ["https://your-endpoint:443"]
      protocol : "https"
      username : "elastic"
      password : "mysupersecret"
    }
  }
}
````

## Advanced example ##

Head over to `example/elasticsearch/elasticsearch.tf`  or `example/logstash/logstash.tf` to get an more advanced example.

## Usage ##

| Parameter                            | Required | Description                                                                                                                          |
|--------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------|
| application_name                     |     X    | Name of the application to ship the logs from                                                                                        |
| functionbeat_version                 |     X    | Version to download and deploy of Functionbeat                                                                                       |
| lambda_config                        |     X    | Functionbeat and Lambda config (see below)                                                                                           |
| tags                                 |     -    | Tags to add to all created AWS resources (see below)                                                                                 |
| lambda_reserved_concurrent_execution |     -    | Reserved concurrency (default: 5)                                                                                                    |
| lambda_memory_size                   |     -    | Memory size (default: 128MB)                                                                                                         |
| lambda_timeout                       |     -    | Timeout (default: 3s)                                                                                                                |
| lambda_description                   |     -    | Description added to the Lambda (default: "Lambda function to ship cloudwatch logs to Kibana")                                       |
| lambda_write_arn_to_ssm              |     -    | Switch to control weather the actual Lambda ARN should be written to SSM (default:true)                                              |
| lambda_runtime                       |     -    | Runtime for the Lambda function (default: "provided.al2023")                                                                         |
| lambda_architecture                  |     -    | Architecture for the Lambda function (default: "x86_64")                                                                             |
| functionbeat_cache_dir               |     -    | Directory used to cache the Functionbeat archive and config files (default: `${path.root}/.terraform/functionbeat`)                  |
| fb_log_level                         |     -    | Functionbeat loglevel, will be set as an ENV on the Lambda level for easy adjustion (default: info)                                  |
| fb_extra_configuration               |     -    | HCL-Map with actual Functionbeat config (default: {})                                                                                |
| fb_extra_tags                        |     -    | The tags of the shipper are included in their own field with each transaction published (default: [])                                |
| loggroup_name                        |     -    | Name of the Cloudwatch log group to be added as trigger for the function (default: null)                                             |
| loggroup_filter_pattern              |     -    | Regex pattern to filter logs which trigger the Lambda (default: "")                                                                  |

#### lambda_config (required) ####

You configure your lambda here.

````
  lambda_config = {
    name = "<NAME-OF-YOUR-LAMBDA>"
    vpc_config = {
      vpc_id = <TARGET-VPC>
      subnet_ids = <TARGET-SUBNET-IDS>
      security_group_ids = [<A-SECURITYGROUP-ID>]
    }
    # You can put any HCL-Map with valid Functionbeat config for Elasticsearch Output 
    output_elasticsearch = {
      hosts = ["https://your-endpoint:443"]
      protocol = "https"
      username = "elastic"
      password = "mysupersecret"
    }
  }
````

## Converting YAML into HCL ##

You easily extend the Functionbeat reference by setting `fb_extra_configuration`. Just head over to the [official Documentation](https://www.elastic.co/guide/en/beats/functionbeat/7.17/functionbeat-reference-yml.html). To ease you life make use of the online [YAML to HCL](https://www.hcl2json.com/) converter to translate from YAML to valid HCL.

Example:
```yaml
processors:
    - add_fields:
        target: project
        fields:
          name: myproject
          id: '574734885120952459'
```
becomes
```terraform
processors = [
  {
    add_fields = {
      fields = {
        id = "574734885120952459"
        name = "myproject"
      }
      target = "project"
    }
  }
]
```
which results in the following module configuration
```terraform
fb_extra_configuration = {
  processors = [
    {
      add_fields = {
        fields = {
          id = "574734885120952459"
          name = "myproject"
        }
        target = "project"
      }
    }
  ]
}
```

## Outputs ##
This module exposes: 
* the functionbeat lambda ARN
* if `lambda_write_arn_to_ssm` is set to `true`, the name of the actual created SSM parameter

## Just get ahead for quick test ## 

*Requirement*
* Setup AWS config locally
* Setup Terraform cli

In ``examples/`` there is an advanced example.
Simply checkout the module source and
```shell
cd examples/elasticsearch
terrafrom init
terraform apply -auto-approve
```
Clean up after you're done
```shell
terraform destroy -auto-approve
```

## Integrate with serverless framework ##
You can easily attach cloudwatchlog groups of your [serverless](https://www.serverless.com/) application, just by using the [serverless-plugin-log-subscription](https://www.serverless.com/plugins/serverless-plugin-log-subscription).
1. Use this module and install the Lambda, ensure `lambda_write_arn_to_ssm` is set to `true`, which is default.
```terraform
module "functionbeat" {
  lambda_config = {
    name = "my-kibana-log-shipper"
  ...
}
```
2. To attach all your Lambdas logs for your Serverless application add the following plugin config into your `serverless.yml`
```yaml
custom:
  logSubscription:
    enabled: true
    destinationArn: '${ssm:my-kibana-log-shipper_arn}'
```
