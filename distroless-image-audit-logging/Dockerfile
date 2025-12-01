# distroless:debug-nonroot イメージを使用
# debug バリアントには busybox シェルが含まれている
FROM gcr.io/distroless/base-debian12:debug-nonroot

# ECS Exec でシェルにアクセスするため、エントリポイントを設定
# distroless:debug には /busybox/sh が含まれている
ENTRYPOINT ["/busybox/sleep", "infinity"]
