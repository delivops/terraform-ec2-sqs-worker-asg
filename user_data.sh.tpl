#!/usr/bin/env bash
set -euxo pipefail

region="${region}"
repo="${repo}"
tag="${tag}"
command="${worker_command}"
workers=${workers_per_instance}
secrets="${worker_secret_ids}"

systemctl enable --now docker

mkdir -p /opt/app
if [ -n "$secrets" ]; then
  : > /opt/app/secrets.env
  for sid in $secrets; do
    aws secretsmanager get-secret-value --region ${region} --secret-id "$sid" \
      --query SecretString --output text | \
      python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(f"{k}={v}" for k,v in d.items()))' >> /opt/app/secrets.env
  done
fi
cat >/opt/app/docker-compose.yml <<YML
version: "3.9"
services:
  worker:
    image: ${repo}:${tag}
%{ if enable_gpu }
    runtime: nvidia
%{ endif }
%{ if worker_command != "" }
    command: ${worker_command}
%{ endif }
    environment:
%{ for k, v in worker_env }
      - ${k}=${v}
%{ endfor }
%{ if length(worker_secret_ids) > 0 }
    env_file:
      - /opt/app/secrets.env
%{ endif }
    deploy:
      replicas: ${workers_per_instance}
YML
%{ if enable_gpu }
export CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=$((100 / workers))
nvidia-cuda-mps-control -d || true
%{ endif }

cat >/etc/systemd/system/app.service <<UNIT
[Unit]
Description=Queue worker stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/aws ecr get-login-password --region ${region} | \
             /usr/bin/docker login --username AWS --password-stdin ${repo}
ExecStartPre=/usr/bin/docker compose -f /opt/app/docker-compose.yml pull
ExecStart=/usr/bin/docker compose -f /opt/app/docker-compose.yml up -d --scale worker=${workers_per_instance}
ExecStop=/usr/bin/docker compose -f /opt/app/docker-compose.yml down
UNIT

systemctl daemon-reload
systemctl enable --now app.service
EOF
