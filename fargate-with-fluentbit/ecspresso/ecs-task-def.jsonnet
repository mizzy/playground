local tfstate = std.native('tfstate');
{
  containerDefinitions: [
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
      environment: [],
      links: [],
      logConfiguration: {
        logDriver: 'awsfirelens',
        options: {
          Name: 'stdout',
        },
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
    {
      name: 'log_router',
      image: 'amazon/aws-for-fluent-bit:latest',
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
          'awslogs-stream-prefix': 'log_router',
        },
      },
    },
  ],
  cpu: '512',
  memory: '1024',
  executionRoleArn: '{{ tfstate `aws_iam_role.httpd.arn` }}',
  family: 'httpd',
  networkMode: 'awsvpc',
  placementConstraints: [],
  requiresCompatibilities: ['FARGATE'],
  volumes: [],
}
