# Noot Not - Confesiones Anónimas

**Proyecto universitario de plataforma web para compartir confesiones de forma anónima**

[![PHP](https://img.shields.io/badge/PHP-8.1+-777BB4?style=flat-square&logo=php)](https://php.net)
[![React](https://img.shields.io/badge/React-18+-61DAFB?style=flat-square&logo=react)](https://reactjs.org)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?style=flat-square&logo=python)](https://python.org)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat-square&logo=docker)](https://docker.com)

## ¿Qué es esto?

Noot Not es una aplicación web donde los usuarios pueden compartir confesiones de forma anónima.

## Características

- **Anonimato completo** - No se requiere registro ni login
- **Sistema de votos** - Los usuarios pueden votar confesiones (upvote/downvote)
- **Generación de imágenes** - Las confesiones se convierten automáticamente en imágenes
- **Responsive** - Funciona en móviles y desktop
- **Anti-spam** - Sistema para prevenir votos duplicados
- **Soporte de emojis** - Renderizado correcto de emojis en las imágenes

## Arquitectura

La aplicación está dividida en tres servicios principales:

```
Usuario → Frontend (React) → API (PHP) → Base de datos (MariaDB)
                           ↓
                    Servicio de imágenes (Python)
```

### Tecnologías usadas

**Frontend**

- React 18 con TypeScript
- Material-UI para los componentes
- Vite para desarrollo y build
- Axios para llamadas a la API

**Backend**

- PHP 8.1+ con Slim Framework
- MariaDB para la base de datos
- Middleware personalizado para CORS

**Servicio de imágenes**

- Python Flask
- Pillow (PIL) para generar imágenes
- Fuentes Noto Sans y Noto Emoji

**Infraestructura**

- Docker y Docker Compose
- Nginx como reverse proxy
- Scripts de deployment automatizado

## Instalación

### Requisitos

- Docker y Docker Compose
- Git
- Al menos 2GB de RAM

### Instalación rápida

```bash
# Clonar el repo
git clone <url-del-repo> noot-not
cd noot-not

# Configurar variables de entorno
cp .env.production.example .env.production
# Editar .env.production según tu configuración

# Levantar todos los servicios
./deploy.sh all production
```

### Desarrollo local

```bash
# Configurar entornos de desarrollo
cp noot-not-api/.env.example noot-not-api/.env
cp noot-not-front/.env.example noot-not-front/.env
cp noot-not-image-api/.env.example noot-not-image-api/.env

# Ejecutar script de desarrollo
./start-dev.sh
```

## API

### Endpoints principales

- `GET /api/confessions` - Obtener confesiones (con paginación)
- `POST /api/confessions` - Crear nueva confesión
- `POST /api/confessions/{id}/vote` - Votar una confesión
- `POST /api/confessions/{id}/report` - Reportar contenido
- `GET /api/health` - Estado del servicio

### Como funciona la generación de imágenes

1. Usuario crea una confesión en el frontend
2. API PHP guarda la confesión en la base de datos
3. API hace una llamada webhook al servicio Python
4. Servicio Python genera las imágenes con PIL
5. Servicio Python envía las URLs de vuelta a la API PHP
6. Frontend muestra las imágenes al usuario

### Sistema de votos

- Se previenen votos duplicados usando IP + fingerprint del navegador
- Los usuarios pueden cambiar su voto (de up a down o viceversa)
- Se almacenan en una tabla separada para mantener el historial

---

## 🐳 Deployment y DevOps

### 🌐 Configuración de Dominio

```yaml
# Configuración DNS recomendada
nootnot.rocks          A    xxx.xxx.xxx.xxx
www.nootnot.rocks      A    xxx.xxx.xxx.xxx
api.nootnot.rocks      A    xxx.xxx.xxx.xxx
image-api.nootnot.rocks A   yyy.yyy.yyy.yyy
```

### 🔐 SSL y Seguridad

```bash
# Configurar certificados SSL
certbot certonly --nginx -d nootnot.rocks -d www.nootnot.rocks
certbot certonly --nginx -d api.nootnot.rocks
certbot certonly --nginx -d image-api.nootnot.rocks

# Copiar certificados
cp /etc/letsencrypt/live/nootnot.rocks/*.pem nginx/ssl/
```

### 📊 Monitoreo (Opcional)

```bash
# Desplegar stack de monitoreo
./deploy.sh monitoring production

# Servicios incluidos:
# - Grafana: http://localhost:3001
# - Prometheus: http://localhost:9090
# - AlertManager: http://localhost:9093
```

### 🔄 Scripts de Utilidad

```bash
# Limpiar archivos temporales
./cleanup.sh

# Estado de servicios
./deploy.sh status

# Logs de servicios
docker-compose logs -f [service-name]

# Backup de base de datos
docker exec noot-not-db mysqldump -u root -p noot_not > backup.sql
```

## Desarrollo

### Configurar el entorno de desarrollo

```bash
# Frontend
cd noot-not-front
npm install
npm run dev      # Servidor de desarrollo en puerto 3000

# Backend PHP
cd noot-not-api
composer install
composer run start    # Servidor en puerto 8000

# Servicio de imágenes
cd noot-not-image-api
pip install -r requirements.txt
python app.py         # Servidor en puerto 8001
```

### Estructura de archivos importante

```
noot-not/
├── noot-not-front/           # Frontend React
│   ├── src/components/       # Componentes React
│   ├── src/hooks/           # Custom hooks
│   └── src/services/        # Cliente API
├── noot-not-api/            # Backend PHP
│   ├── src/Controllers/     # Controladores de la API
│   ├── src/Models/         # Modelos de datos
│   └── src/Services/       # Lógica de negocio
├── noot-not-image-api/      # Servicio de imágenes
│   ├── app.py              # Aplicación Flask
│   ├── image_generator.py  # Generador de imágenes
│   └── assets/fonts/       # Fuentes Noto
└── docker-compose.yml       # Configuración Docker
```

## Deployment

### Para producción

El proyecto está configurado para deployarse en dos servidores:

- Servidor principal: API + Frontend + Base de datos
- Servidor de imágenes: Servicio Python

```bash
# Servidor principal
./deploy.sh main production

# Servidor de imágenes
./deploy.sh image-api production
```

### Configuración DNS recomendada

```
nootnot.rocks          → Servidor principal
api.nootnot.rocks      → Servidor principal
image-api.nootnot.rocks → Servidor de imágenes
```

### Scripts útiles

```bash
./cleanup.sh                    # Limpiar archivos temporales
./deploy.sh status              # Ver estado de servicios
docker-compose logs -f          # Ver logs en tiempo real
```

---

## Tecnologías y recursos

**Tecnologías principales:**

- [React](https://reactjs.org) - Frontend
- [Material-UI](https://mui.com) - Componentes UI
- [PHP Slim](https://slimframework.com) - API backend
- [Python Flask](https://flask.palletsprojects.com) - Servicio de imágenes
- [Docker](https://docker.com) - Containerización

**Recursos utilizados:**

- [Noto Fonts](https://fonts.google.com/noto) - Fuentes Unicode
- [Material Icons](https://material.io/icons) - Iconos

---

## Licencia

ver archivo LICENSE para detalles.
