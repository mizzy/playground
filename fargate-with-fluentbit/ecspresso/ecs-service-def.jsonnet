local tfstate = std.native('tfstate');
{
  deploymentConfiguration: {
    deploymentCircuitBreaker: {
      enable: false,
      rollback: false,
    },
    maximumPercent: 200,
    minimumHealthyPercent: 100,
  },
  desiredCount: 1,
  enableECSManagedTags: false,
  healthCheckGracePeriodSeconds: 0,
  launchType: 'FARGATE',
  loadBalancers: [
    {
      containerName: 'httpd',
      containerPort: 80,
      targetGroupArn: tfstate('aws_lb_target_group.httpd.arn'),
    },
  ],
  networkConfiguration: {
    awsvpcConfiguration: {
      assignPublicIp: 'DISABLED',
      securityGroups: [tfstate('aws_security_group.httpd.id')],
      subnets: [tfstate('aws_subnet.private_a.id'), tfstate('aws_subnet.private_c.id')],
    },
  },
  placementConstraints: [],
  placementStrategy: [],
  platformVersion: 'LATEST',
  schedulingStrategy: 'REPLICA',
  serviceRegistries: [],
}
