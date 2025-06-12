# Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress

1. Abrir a barra de pesquisa e digitar por 'EFS'
2. Clicar em 'Criar sistema de arquivos'

## Etapa 1: Configurações do sistema de arquivos
1. Clicar em 'Personalizar'
2. Nome: inserir um nome
3. Tipo de sistema de arquivos: selecionar 'One Zone' ou 'Regional'
- No nosso projeto, usaremos 'Regional' 
4. Backups automáticos: desmarcar o checkbox
5. Gerenciamento de ciclo de vida: colocar todas as opções para 'Nenhum'

![alt text](images-tres/image-24.png)

6. Configurações de performance: selecionar 'Intermitente'
10. Configurações adicionais: selecionar 'Uso geral (Recomendado)'

![alt text](images-tres/image-25.png)

11. Clicar em 'Próximo'

## Etapa 2: Acesso à rede 
1. Virtual Private Cloud (VPC): Selecionar a VPC 
2. Selecionar Availability Zones (AZs)
- Selecionar subnets privadas (subnet privada da us-east-1a e subnets **PRIVADAS** da us-east-1b)
3. Grupos de segurança: escolher o grupo de segurança EFS

![alt text](images-tres/image-28.png)

4. Clicar em próximo

## Etapa 3: Política do sistema de arquivos / EFS
1. Ler as opções
2. Clicar em 'Próximo'

## Etapa 4: Revisar e criar
1. Revisar as opções
2. Clicar em 'Criar'

> Depois de criada, você irá anotar o ID do seu EFS para utilizá-lo futuramente.

# Launch Template / Modelos de Execução
1. Na barra de pesquisa, pesquisar EC2
2. Na lateral esquerda, clicar em 'Modelos de Execução' na seção 'Instâncias'

### Configurações
1. Nomes do modelo de execução: inserir um nome para o modelo
2. Descrição: inserir uma descrição 
3. Imagens de aplicação e de sistema operacional (imagem de máquina da Amazon): selecionar 'Ubuntu' ou 'Amazon Linux'
4. Tipo de instância: selecionar t2.micro
5. Par de chaves (login): selecionar a chave via SSH.
6. Configurações de rede: clique em 'Editar',
- Em Subent, selecione a opção 'Don't include in launch template
- Em Firewall, selecionar 'Selecionar grupo de segurança existente' e depois selecione o grupo de segurança feita para EFS
7. Detalhes avançados: desça a página até 'Dados do usuário (opcional)' e cole o código do user_data.

```bash
#!/bin/bash

exec > /var/log/user-data.log 2>&1
set -euxo pipefail

# --- Variáveis de Configuração ---
# Substitua os valores entre < > pelos seus valores reais
EFS_ENDPOINT="<seu_efs_endpoint>" # Ex: fs-xxxxxxxxxxxxxxxxx.efs.sa-east-1.amazonaws.com
DB_HOST="<seu_db_host>"           # Ex: seu-banco.xxxxxxx.sa-east-1.rds.amazonaws.com
DB_USER="<seu_db_user>"
DB_PASSWORD="<sua_db_password>"
DB_NAME="<seu_db_name>"
DOCKER_COMPOSE_VERSION="v2.23.0"  # Versão que você estava usando. Para a mais recente, verifique o GitHub do Docker Compose.

# --- Atualizações e Instalações Básicas ---
dnf update -y
dnf install -y docker amazon-efs-utils # Adicionado amazon-efs-utils para montagem automática EFS

# --- Configuração do Docker ---
systemctl enable --now docker
usermod -aG docker ec2-user

# --- Instalação do Docker Compose (como plugin do Docker CLI) ---
mkdir -p /usr/libexec/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# --- Montagem do EFS ---
# Monta o EFS usando o client amazon-efs-utils, que é mais robusto
mkdir -p /mnt/efs
mount -t efs ${EFS_ENDPOINT}:/ /mnt/efs
echo "${EFS_ENDPOINT}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab # Adiciona ao fstab para remontagem após reboot

# Garante que o EFS esteja montado antes de continuar
while ! mountpoint -q /mnt/efs; do
  echo "EFS não montado, aguardando..."
  sleep 5
done

# --- Permissões para o WordPress ---
# O usuário www-data (ID 33) dentro do container precisa de permissão de escrita
mkdir -p /mnt/efs/wordpress
chown -R 33:33 /mnt/efs/wordpress

# --- Criação do docker-compose.yaml ---
# O arquivo será criado no diretório inicial do ec2-user
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

# --- Inicialização do WordPress com Docker Compose ---
sudo -u ec2-user bash -c "cd /home/ec2-user && docker compose up -d"
```

- Adicione tags se necessário. No projeto, usarei as minhas.
8. Espere iniciar e clique em 'Conectar'
9. Em Conexão de instância do EC2, clique em 'Connect using a Public IP'

## Instalação do EFS

1. Para instalar o EFS:
```bash
sudo yum update -y
sudo yum install -y git binutils rust cargo pkgconfig openssl-devel
git clone https://github.com/aws/efs-utils
cd efs-utils
./build-deb.sh
sudo yum install -y ./build/amazon-efs-utils*.rpm
```

2. Para montar:
```bash
sudo mkdir -p /mnt/efs
sudo mount -t efs -o tls fs-12345678:/ /mnt/efs
```
