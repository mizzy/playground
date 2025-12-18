data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_sfn_state_machine" "restart_oldest_task" {
  name     = "restart-oldest-ecs-task"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment       = "Restart the oldest running ECS task"
    QueryLanguage = "JSONata"
    StartAt       = "ListTasks"

    States = {
      ListTasks = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:listTasks"
        Arguments = {
          Cluster       = var.ecs_cluster_name
          ServiceName   = var.ecs_service_name
          DesiredStatus = "RUNNING"
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
        Next = "GetOldestTask"
      }

      GetOldestTask = {
        Type   = "Pass"
        Output = "{% $sort($states.input.Tasks, function($a, $b) { $a.StartedAt < $b.StartedAt })[0].TaskArn %}"
        Next   = "StopTask"
      }

      StopTask = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ecs:stopTask"
        Arguments = {
          Cluster = var.ecs_cluster_name
          Task    = "{% $states.input %}"
          Reason  = "Scheduled restart by Step Functions to prevent memory leak"
        }
        End = true
      }
    }
  })
}
