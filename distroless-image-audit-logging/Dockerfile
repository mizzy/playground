# distroless:debug-nonroot イメージを使用
# debug バリアントには busybox シェルが含まれている
#
# ビルド方法:
#   audit logging 無効（デフォルト）: docker build --target base -t <image> .
#   audit logging 有効: docker build --target with-audit -t <image> .

# ビルドステージ: /etc/passwd と /sbin/nologin を準備
FROM busybox:latest AS builder

# /etc/passwd を作成（シェルを /busybox/sh に設定）
# ECS Exec の audit logging は script コマンドを使用し、
# /etc/passwd のシェルを起動するため、有効なシェルが必要
RUN printf 'root:x:0:0:root:/root:/busybox/sh\n\
nobody:x:65534:65534:nobody:/nonexistent:/busybox/sh\n\
nonroot:x:65532:65532:nonroot:/home/nonroot:/busybox/sh\n' > /etc/passwd

# /sbin/nologin を作成
RUN mkdir -p /sbin && printf '#!/busybox/sh\nexit 1\n' > /sbin/nologin && chmod +x /sbin/nologin

# ベースイメージ（audit logging 無効）
FROM gcr.io/distroless/base-debian12:debug-nonroot AS base
ENTRYPOINT ["/busybox/sleep", "infinity"]

# audit logging 有効イメージ
FROM gcr.io/distroless/base-debian12:debug-nonroot AS with-audit

# /etc/passwd を上書きコピー（シェルを /busybox/sh に変更）
COPY --from=builder /etc/passwd /etc/passwd

# /sbin/nologin スクリプトをコピー
COPY --from=builder /sbin/nologin /sbin/nologin

# ECS Exec でシェルにアクセスするため、エントリポイントを設定
ENTRYPOINT ["/busybox/sleep", "infinity"]
