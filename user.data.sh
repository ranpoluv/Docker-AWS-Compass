#!/bin/bash

# EFS, DB e Docker Compose Configurações
# Substitua os valores abaixo pelos seus próprios
# Certifique-se de que o EFS e o banco de dados estejam configurados corretamente antes de executar este script
EFS_FILE_SYSTEM_ID="<seu_file_id>"  
DB_HOST="<seu_host_do_banco_de_dados>"  
DB_NAME="<seu_nome_do_banco_de_dados>"  
DB_USER="<seu_usuario_do_banco>"  
DB_PASSWORD="<sua_senha_do_banco>"  
DOCKER_COMPOSE_VERSION="v2.34.0"
PROJECT_DIR="/home/ec2-user/projeto-docker"
EFS_MOUNT_DIR="/mnt/efs"  

# Atualizar e instalar dependências
yum update -y
yum install -y aws-cli

# Instalar e configurar do Docker
yum install -y docker
service docker start
systemctl enable docker
usermod -a -G docker ec2-user

# Instalar o Docker Compose
curl -SL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Instalar e montar o EFS
yum install -y amazon-efs-utils
mkdir -p ${EFS_MOUNT_DIR}
mount -t efs ${EFS_FILE_SYSTEM_ID}:/ ${EFS_MOUNT_DIR}
echo "${EFS_FILE_SYSTEM_ID}:/ ${EFS_MOUNT_DIR} efs defaults,_netdev 0 0" >> /etc/fstab

# Permissões corretas para WordPress (usuário 33 = www-data no container)
chown -R 33:33 ${EFS_MOUNT_DIR}

# Preparação do projeto
mkdir -p ${PROJECT_DIR}
cd ${PROJECT_DIR}

# Arquivo docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3.7'
services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    environment:
      WORDPRESS_DB_HOST: ${DB_HOST}
      WORDPRESS_DB_NAME: ${DB_NAME}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
    ports:
      - 80:80
    volumes:
      - ${EFS_MOUNT_DIR}:/var/www/html

volumes:
  wordpress_data:
EOL

# Iniciar o WordPress
docker-compose up -d