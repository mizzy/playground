local tfstate = std.native('tfstate');
{
  containerDefinitions: [
    {
      command: [
        "/bin/sh -c \"echo '<html> <head> <title>Amazon ECS Sample App</title> <style>body {margin-top: 40px; background-color: #333;} </style> </head><body> <div style=color:white;text-align:center> <h1>Amazon ECS Sample App</h1> <h2>Congratulations!</h2> <p>Your application is now running on a container in Amazon ECS.</p> </div></body></html>' >  /usr/local/apache2/htdocs/index.html && httpd-foreground\"",
      ],
      entryPoint: [
        'sh',
        '-c',
      ],
      cpu: 256,
      environment: [],
      essential: true,
      image: 'httpd:2.4',
      links: [],
      logConfiguration: {
        logDriver: 'awslogs',
        options: {
          'awslogs-group': tfstate('aws_cloudwatch_log_group.httpd.name'),
          'awslogs-region': 'ap-northeast-1',
          'awslogs-stream-prefix': 'ecs',
        },
      },
      memoryReservation: 512,
      mountPoints: [],
      name: 'httpd',
      portMappings: [
        {
          containerPort: 80,
          hostPort: 80,
          protocol: 'tcp',
        },
      ],
      volumesFrom: [],
    },
  ],
  cpu: '256',
  executionRoleArn: '{{ tfstate `aws_iam_role.httpd.arn` }}',
  family: 'httpd',
  memory: '512',
  networkMode: 'awsvpc',
  placementConstraints: [],
  requiresCompatibilities: ['FARGATE'],
  volumes: [],
}
