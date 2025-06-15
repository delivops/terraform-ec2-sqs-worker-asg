#!/usr/bin/env bash
set -euxo pipefail

region="${region}"
repo="${repo}"
tag="${tag}"
command="${worker_command}"
workers=${workers_per_instance}
secrets="${join(" ", worker_secret_ids)}"
fluentbit_config="${fluentbit_config_ssm_path}"

# Detect OS version and install Docker accordingly
if command -v dnf &> /dev/null; then
    echo "Detected Amazon Linux 2023, using dnf"
    dnf update -y
    dnf install -y docker
elif command -v yum &> /dev/null; then
    echo "Detected Amazon Linux 2, using yum"
    yum update -y
    yum install -y docker
else
    echo "Unsupported OS - neither yum nor dnf found"
    exit 1
fi

systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Wait for Docker to be ready
sleep 10

mkdir -p /opt/app
mkdir -p /opt/fluent-bit
# Prepare environment variables for the worker
if [ -n "$fluentbit_config" ]; then
  aws ssm get-parameter --region ${region} --name "$fluentbit_config" --with-decryption --query Parameter.Value --output text > /opt/fluent-bit/fluent-bit.conf
fi
if [ -n "$secrets" ]; then
  : > /opt/app/secrets.env
  for sid in $secrets; do
    aws secretsmanager get-secret-value --region ${region} --secret-id "$sid" \
      --query SecretString --output text | \
      python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(f"{k}={v}" for k,v in d.items()))' >> /opt/app/secrets.env
  done
fi

# Create docker-compose.yml
cat >/opt/app/docker-compose.yml <<YML
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
%{ if fluentbit_config_ssm_path != "" }
  fluent-bit:
    image: fluent/fluent-bit:latest
    volumes:
      - /opt/fluent-bit/fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    environment:
      - ENVIRONMENT=${environment_name}
      - APPLICATION=${application_name}
%{ endif }
YML

# GPU (optional)
%{ if enable_gpu }
export CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=$((100 / workers))
nvidia-cuda-mps-control -d || true
%{ endif }

# Docker auth
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${repo}
docker-compose -f /opt/app/docker-compose.yml pull

# Create systemd unit
cat >/etc/systemd/system/app.service <<'EOF'
[Unit]
Description=Queue worker stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/bash -c '/usr/bin/aws ecr get-login-password --region ${region} | /usr/bin/docker login --username AWS --password-stdin ${repo}'
ExecStartPre=/usr/bin/docker-compose -f /opt/app/docker-compose.yml pull
ExecStart=/usr/bin/docker-compose -f /opt/app/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f /opt/app/docker-compose.yml down
EOF

systemctl daemon-reload
systemctl enable --now app.service