#!/bin/bash

exec > /var/log/user-data.log 2>&1
set -euxo pipefail

EFS_ENDPOINT="<seu_efs_endpoint>" 
DB_HOST="<seu_db_host>"           
DB_USER="<seu_db_user>"
DB_PASSWORD="<sua_db_password>"
DB_NAME="<seu_db_name>"
DOCKER_COMPOSE_VERSION="v2.23.0"  

dnf update -y
dnf install -y docker amazon-efs-utils 

systemctl enable --now docker
usermod -aG docker ec2-user

mkdir -p /usr/libexec/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

mkdir -p /mnt/efs
mount -t efs ${EFS_ENDPOINT}:/ /mnt/efs
echo "${EFS_ENDPOINT}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab 

while ! mountpoint -q /mnt/efs; do
  echo "EFS não montado, aguardando..."
  sleep 5
done

mkdir -p /mnt/efs/wordpress
chown -R 33:33 /mnt/efs/wordpress


sudo -u ec2-user bash -c "cat > /home/ec2-user/docker-compose.yaml <<EOF
version: \"3.8\"
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - \"80:80\"
    environment:
      WORDPRESS_DB_HOST: ${DB_HOST}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: ${DB_NAME}
    volumes:
      - /mnt/efs/wordpress:/var/www/html
EOF"

sudo -u ec2-user bash -c "cd /home/ec2-user && docker compose up -d"