local tfstate = std.native('tfstate');
{
  containerDefinitions: [
    // main container
    {
      name: 'httpd',
      image: 'httpd:2.4',
      command: [
        "/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' > /usr/local/apache2/htdocs/index.html && httpd-foreground\"",
      ],
      entryPoint: ['sh', '-c'],
      cpu: 256,
      memoryReservation: 512,
      essential: true,
      links: [],
      logConfiguration: {
        logDriver: 'awsfirelens',
      },
      mountPoints: [],
      volumesFrom: [],
      portMappings: [
        {
          containerPort: 80,
          hostPort: 80,
          protocol: 'tcp',
        },
      ],
    },

    // log-router container
    {
      name: 'log-router',
      image: 'public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest',
      essential: true,
      cpu: 32,
      memoryReservation: 50,
      firelensConfiguration: {
        type: 'fluentbit',
      },
      logConfiguration: {
        logDriver: 'awslogs',
        options: {
          'awslogs-group': tfstate('aws_cloudwatch_log_group.httpd.name'),
          'awslogs-region': 'ap-northeast-1',
          'awslogs-stream-prefix': 'log-router',
        },
      },
      environment: [
        {
          name: 'aws_fluent_bit_init_s3_1',
          value: tfstate('aws_s3_bucket.fluentbit.arn') + '/datadog-output.conf',
        },
      ],
      secrets: [
        {
          name: 'DD_API_KEY',
          valueFrom: tfstate('aws_ssm_parameter.datadog_api_key.arn'),
        },
      ],
    },

  ],
  cpu: '512',
  memory: '1024',
  executionRoleArn: tfstate('aws_iam_role.httpd.arn'),
  taskRoleArn: tfstate('aws_iam_role.task_role.arn'),
  family: 'httpd',
  networkMode: 'awsvpc',
  placementConstraints: [],
  requiresCompatibilities: ['FARGATE'],
  volumes: [],
}
