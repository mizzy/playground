data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_sfn_state_machine" "restart_oldest_task" {
  name     = "restart-oldest-ecs-task"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment       = "Restart the oldest running ECS task while maintaining desired count"
    QueryLanguage = "JSONata"
    StartAt       = "GetCurrentService"

    States = {
      GetCurrentService = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:describeServices"
        Arguments = {
          Cluster  = var.ecs_cluster_name
          Services = [var.ecs_service_name]
        }
        Next = "ListTasks"
      }

      ListTasks = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:listTasks"
        Arguments = {
          Cluster       = var.ecs_cluster_name
          ServiceName   = var.ecs_service_name
          DesiredStatus = "RUNNING"
        }
        Output = {
          "CurrentDesiredCount" = "{% $states.input.Services[0].DesiredCount %}"
          "TaskArns"            = "{% $states.result.TaskArns %}"
        }
        Next = "CheckTasksExist"
      }

      CheckTasksExist = {
        Type = "Choice"
        Choices = [
          {
            Condition = "{% $count($states.input.TaskArns) > 0 %}"
            Next      = "DescribeTasks"
          }
        ]
        Default = "NoTasksFound"
      }

      NoTasksFound = {
        Type    = "Succeed"
        Comment = "No running tasks found"
      }

      DescribeTasks = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:describeTasks"
        Arguments = {
          Cluster = var.ecs_cluster_name
          Tasks   = "{% $states.input.TaskArns %}"
        }
        Output = {
          "CurrentDesiredCount" = "{% $states.input.CurrentDesiredCount %}"
          "Tasks"               = "{% $states.result.Tasks %}"
        }
        Next = "GetOldestTask"
      }

      GetOldestTask = {
        Type = "Pass"
        Output = {
          "CurrentDesiredCount" = "{% $states.input.CurrentDesiredCount %}"
          "OldestTaskArn"       = "{% $sort($states.input.Tasks, function($a, $b) { $a.StartedAt > $b.StartedAt })[0].TaskArn %}"
        }
        Next = "IncreaseDesiredCount"
      }

      IncreaseDesiredCount = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:updateService"
        Arguments = {
          Cluster      = var.ecs_cluster_name
          Service      = var.ecs_service_name
          DesiredCount = "{% $states.input.CurrentDesiredCount + 1 %}"
        }
        Output = {
          "CurrentDesiredCount" = "{% $states.input.CurrentDesiredCount %}"
          "OldestTaskArn"       = "{% $states.input.OldestTaskArn %}"
        }
        Next = "WaitForNewTask"
      }

      WaitForNewTask = {
        Type    = "Wait"
        Seconds = 60
        Next    = "CheckNewTaskRunning"
      }

      CheckNewTaskRunning = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:describeServices"
        Arguments = {
          Cluster  = var.ecs_cluster_name
          Services = [var.ecs_service_name]
        }
        Output = {
          "CurrentDesiredCount" = "{% $states.input.CurrentDesiredCount %}"
          "OldestTaskArn"       = "{% $states.input.OldestTaskArn %}"
          "RunningCount"        = "{% $states.result.Services[0].RunningCount %}"
          "DesiredCount"        = "{% $states.result.Services[0].DesiredCount %}"
        }
        Next = "IsNewTaskReady"
      }

      IsNewTaskReady = {
        Type = "Choice"
        Choices = [
          {
            Condition = "{% $states.input.RunningCount >= $states.input.DesiredCount %}"
            Next      = "StopTask"
          }
        ]
        Default = "WaitForNewTask"
      }

      StopTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:stopTask"
        Arguments = {
          Cluster = var.ecs_cluster_name
          Task    = "{% $states.input.OldestTaskArn %}"
          Reason  = "Scheduled restart by Step Functions to prevent memory leak"
        }
        Output = {
          "CurrentDesiredCount" = "{% $states.input.CurrentDesiredCount %}"
        }
        Next = "DecreaseDesiredCount"
      }

      DecreaseDesiredCount = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:updateService"
        Arguments = {
          Cluster      = var.ecs_cluster_name
          Service      = var.ecs_service_name
          DesiredCount = "{% $states.input.CurrentDesiredCount %}"
        }
        End = true
      }
    }
  })
}
