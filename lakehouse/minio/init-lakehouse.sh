#!/bin/sh
# Bootstraps the lakehouse bucket and a least-privilege service account used by
# Trino and delta-sink (the MinIO root account is reserved for administration).
set -eu

mc alias set lake http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
mc mb --ignore-existing lake/lakehouse

cat > /tmp/lakehouse-rw.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": ["arn:aws:s3:::lakehouse"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject",
                 "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
      "Resource": ["arn:aws:s3:::lakehouse/*"]
    }
  ]
}
EOF
mc admin policy create lake lakehouse-rw /tmp/lakehouse-rw.json
mc admin user add lake "$LAKEHOUSE_S3_ACCESS_KEY" "$LAKEHOUSE_S3_SECRET_KEY"
# The image ships no grep: match with a shell pattern (idempotent on re-runs).
case "$(mc admin user info lake "$LAKEHOUSE_S3_ACCESS_KEY" --json)" in
  *lakehouse-rw*) ;;
  *) mc admin policy attach lake lakehouse-rw --user "$LAKEHOUSE_S3_ACCESS_KEY" ;;
esac

echo "[minio-init] bucket 'lakehouse' + service account '$LAKEHOUSE_S3_ACCESS_KEY' (policy lakehouse-rw) ready"
