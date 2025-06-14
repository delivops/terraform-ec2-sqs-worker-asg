#!/usr/bin/env bash
set -euxo pipefail

region="${region}"
repo="${repo}"
queue_name="${queue_name}"
workers=${workers_per_instance}

systemctl enable --now docker

mkdir -p /opt/app
cat >/opt/app/docker-compose.yml <<YML
version: "3.9"
services:
  worker:
    image: ${repo}:latest
    runtime: nvidia
    environment:
      - QUEUE_URL=${queue_name}
    deploy:
      replicas: ${workers_per_instance}
YML

export CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=$((100 / workers))
nvidia-cuda-mps-control -d || true

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
