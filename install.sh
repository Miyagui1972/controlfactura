#!/bin/bash

# Script de Instalación Automatizada - Control de Facturas PWA
# Para Ubuntu 20.04 LTS o superior

set -e

echo "========================================"
echo "  Control de Facturas - Instalación"
echo "========================================"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root (use sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}[1/9]${NC} Actualizando paquetes del sistema..."
apt update && apt upgrade -y

echo -e "${GREEN}[2/9]${NC} Instalando dependencias del sistema..."
apt install -y curl git build-essential

# Instalar Node.js 20.x
echo -e "${GREEN}[3/9]${NC} Instalando Node.js 20.x..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt install -y nodejs
else
    echo "Node.js ya está instalado: $(node -v)"
fi

# Instalar Yarn
echo -e "${GREEN}[4/9]${NC} Instalando Yarn..."
if ! command -v yarn &> /dev/null; then
    npm install -g yarn
else
    echo "Yarn ya está instalado: $(yarn -v)"
fi

# Instalar PostgreSQL
echo -e "${GREEN}[5/9]${NC} Instalando PostgreSQL..."
if ! command -v psql &> /dev/null; then
    apt install -y postgresql postgresql-contrib
    systemctl start postgresql
    systemctl enable postgresql
else
    echo "PostgreSQL ya está instalado"
fi

# Configurar PostgreSQL
echo -e "${GREEN}[6/9]${NC} Configurando base de datos PostgreSQL..."

echo -e "${YELLOW}Ingrese el nombre de usuario para PostgreSQL:${NC}"
read -p "Usuario (default: facturas_user): " DB_USER
DB_USER=${DB_USER:-facturas_user}

echo -e "${YELLOW}Ingrese la contraseña para el usuario de PostgreSQL:${NC}"
read -sp "Contraseña: " DB_PASSWORD
echo ""

DB_NAME="control_facturas"

# Crear usuario y base de datos en PostgreSQL
sudo -u postgres psql <<EOF
-- Crear usuario si no existe
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '${DB_USER}') THEN
      CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';
   END IF;
END
\$\$;

-- Crear base de datos si no existe
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_NAME}')\gexec

-- Otorgar privilegios
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
EOF

echo -e "${GREEN}Base de datos configurada exitosamente${NC}"

# Instalar PM2 para gestión de procesos
echo -e "${GREEN}[7/9]${NC} Instalando PM2..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
    pm2 startup systemd -u $SUDO_USER --hp /home/$SUDO_USER
else
    echo "PM2 ya está instalado"
fi

# Instalar Nginx
echo -e "${GREEN}[8/9]${NC} Instalando Nginx..."
if ! command -v nginx &> /dev/null; then
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
else
    echo "Nginx ya está instalado"
fi

# Configurar firewall
echo -e "${GREEN}[9/9]${NC} Configurando firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 'Nginx Full'
    ufw allow OpenSSH
    echo "Firewall configurado (HTTP, HTTPS, SSH permitidos)"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Instalación de Dependencias Completa${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Información de la base de datos:${NC}"
echo "  Usuario: ${DB_USER}"
echo "  Base de datos: ${DB_NAME}"
echo "  Host: localhost"
echo "  Puerto: 5432"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "  1. Navega a la carpeta nextjs_space: cd nextjs_space"
echo "  2. Copia .env.example a .env: cp .env.example .env"
echo "  3. Edita .env con tus configuraciones"
echo "  4. Instala dependencias: yarn install"
echo "  5. Ejecuta migraciones: yarn prisma migrate deploy"
echo "  6. Genera cliente Prisma: yarn prisma generate"
echo "  7. (Opcional) Carga datos de prueba: yarn prisma db seed"
echo "  8. Construye la aplicación: yarn build"
echo "  9. Inicia con PM2: pm2 start ecosystem.config.js"
echo ""
echo -e "${GREEN}¡Instalación exitosa!${NC}"
