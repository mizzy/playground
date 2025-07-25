local tfstate = std.native('tfstate');
{
  containerDefinitions: [
    // main container
    {
      name: 'sheets',
      image: 'mizzy/sheets:latest',
      cpu: 256,
      memoryReservation: 512,
      essential: true,
      links: [],
      logConfiguration: {
        logDriver: 'awslogs',
        options: {
          'awslogs-group': tfstate('aws_cloudwatch_log_group.httpd.name'),
          'awslogs-region': 'ap-northeast-1',
          'awslogs-stream-prefix': 'sample',
        },
      },
      portMappings: [],
      environment: [
        {
          name: 'GCP_PROJECT_NUMBER',
          value: '376742608836',
        },
        {
          name: 'WORKLOAD_IDENTITY_POOL_ID',
          value: 'mizzy-pool',
        },
        {
          name: 'WORKLOAD_IDENTITY_PROVIDER_ID',
          value: 'mizzy-aws-provider',
        },
        {
          name: 'SERVICE_ACCOUNT_EMAIL',
          value: 'spreadsheet-service-account@service-account-466904.iam.gserviceaccount.com',
        },
        {
          name: 'SPREADSHEET_ID',
          value: '1wq9mrX9-FrXhFaHnf-jx1MsRwbGVMzrxyNpTlkJJ3g4',
        },
      ],
    },
  ],
  cpu: '512',
  memory: '1024',
  executionRoleArn: tfstate('aws_iam_role.httpd.arn'),
  taskRoleArn: tfstate('aws_iam_role.task_role.arn'),
  family: 'sheets',
  networkMode: 'awsvpc',
  placementConstraints: [],
  requiresCompatibilities: ['FARGATE'],
  volumes: [],
  runtimePlatform: {
    operatingSystemFamily: 'LINUX',
    cpuArchitecture: 'ARM64',
  },
}
