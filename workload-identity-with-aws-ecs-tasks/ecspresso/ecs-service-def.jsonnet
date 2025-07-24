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
  loadBalancers: [],
  networkConfiguration: {
    awsvpcConfiguration: {
      assignPublicIp: 'DISABLED',
      securityGroups: [tfstate('aws_security_group.httpd.id')],
      subnets: [
        tfstate('module.vpc.aws_subnet.private["ap-northeast-1a"].id'),
        tfstate('module.vpc.aws_subnet.private["ap-northeast-1c"].id'),
        tfstate('module.vpc.aws_subnet.private["ap-northeast-1d"].id'),
      ],
    },
  },
  placementConstraints: [],
  placementStrategy: [],
  platformVersion: 'LATEST',
  schedulingStrategy: 'REPLICA',
  serviceRegistries: [],
}
