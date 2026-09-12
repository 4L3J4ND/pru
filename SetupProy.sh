#!/usr/bin/env bash
###############################################################################
# setup_proyecto.sh
#
# Genera automáticamente la estructura completa de un proyecto Django
# (Sistema de Venta de Pasajes y Encomiendas) lista para desarrollar con
# Docker + PostgreSQL.
#
# Uso:
#   chmod +x setup_proyecto.sh
#   ./setup_proyecto.sh [nombre_del_proyecto]
#
# Si no se indica nombre, se usa "transporte_pasajeros".
###############################################################################
set -euo pipefail

PROJECT_ROOT="${1:-transporte_pasajeros}"
APPS=(usuarios rutas flota viajes ventas encomiendas incidencias reportes promociones personal core)

if [ -d "$PROJECT_ROOT" ]; then
  echo "El directorio '$PROJECT_ROOT' ya existe. Elimínalo o elige otro nombre."
  exit 1
fi

echo ">> Creando proyecto en ./${PROJECT_ROOT}"
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

###############################################################################
# 1. Carpetas base
###############################################################################
mkdir -p config/settings
mkdir -p apps
mkdir -p templates/partials
mkdir -p static/css static/js static/img
mkdir -p media/comprobantes media/comprobantes_encomiendas media/encomiendas
mkdir -p requirements
mkdir -p docker/django docker/nginx
mkdir -p scripts

touch media/comprobantes/.gitkeep media/comprobantes_encomiendas/.gitkeep media/encomiendas/.gitkeep
touch static/js/.gitkeep static/img/.gitkeep

###############################################################################
# 2. manage.py
###############################################################################
cat > manage.py << 'EOF'
#!/usr/bin/env python
"""Utilidad de línea de comandos de Django."""
import os
import sys


def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "No se pudo importar Django. ¿Está el entorno activado / instalado?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
EOF
chmod +x manage.py

###############################################################################
# 3. config/
###############################################################################
touch config/__init__.py
touch config/settings/__init__.py

cat > config/settings/base.py << 'EOF'
"""
Configuración base - Sistema de Venta de Pasajes y Encomiendas
"""
import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent.parent

load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.environ.get("SECRET_KEY", "inseguro-cambiar-en-produccion")

DEBUG = os.environ.get("DEBUG", "False") == "True"

ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",

    # Apps del sistema
    "apps.core",
    "apps.usuarios",
    "apps.rutas",
    "apps.flota",
    "apps.viajes",
    "apps.ventas",
    "apps.encomiendas",
    "apps.incidencias",
    "apps.reportes",
    "apps.promociones",
    "apps.personal",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "apps.core.context_processors.datos_globales",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "transporte_db"),
        "USER": os.environ.get("POSTGRES_USER", "transporte_user"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "postgres"),
        "HOST": os.environ.get("POSTGRES_HOST", "db"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

AUTH_USER_MODEL = "usuarios.Usuario"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "es-bo"
TIME_ZONE = "America/La_Paz"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATICFILES_DIRS = [BASE_DIR / "static"]
STATIC_ROOT = BASE_DIR / "staticfiles"

MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "usuarios:login"
LOGIN_REDIRECT_URL = "rutas:index"
LOGOUT_REDIRECT_URL = "usuarios:login"
EOF

cat > config/settings/local.py << 'EOF'
from .base import *  # noqa

DEBUG = True
ALLOWED_HOSTS = ["*"]

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Desactiva HTTPS forzado en desarrollo
SECURE_SSL_REDIRECT = False
EOF

cat > config/settings/production.py << 'EOF'
from .base import *  # noqa

DEBUG = False

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 3600
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = "DENY"

MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"
EOF

cat > config/urls.py << 'EOF'
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path("admin/", admin.site.urls),
    path("cuentas/", include("apps.usuarios.urls")),
    path("rutas/", include("apps.rutas.urls")),
    path("flota/", include("apps.flota.urls")),
    path("viajes/", include("apps.viajes.urls")),
    path("ventas/", include("apps.ventas.urls")),
    path("encomiendas/", include("apps.encomiendas.urls")),
    path("incidencias/", include("apps.incidencias.urls")),
    path("reportes/", include("apps.reportes.urls")),
    path("promociones/", include("apps.promociones.urls")),
    path("personal/", include("apps.personal.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
EOF

cat > config/wsgi.py << 'EOF'
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")

application = get_wsgi_application()
EOF

cat > config/asgi.py << 'EOF'
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")

application = get_asgi_application()
EOF

###############################################################################
# 4. apps/ (skeleton genérico para cada app)
###############################################################################
touch apps/__init__.py

for app in "${APPS[@]}"; do
  app_dir="apps/${app}"
  class_name="$(tr '[:lower:]' '[:upper:]' <<< "${app:0:1}")${app:1}"

  mkdir -p "${app_dir}/migrations"
  mkdir -p "${app_dir}/templates/${app}"
  mkdir -p "${app_dir}/tests"

  touch "${app_dir}/__init__.py"
  touch "${app_dir}/migrations/__init__.py"
  touch "${app_dir}/templates/${app}/.gitkeep"
  touch "${app_dir}/tests/__init__.py"

  cat > "${app_dir}/apps.py" << EOF
from django.apps import AppConfig


class ${class_name}Config(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.${app}"
    verbose_name = "${class_name}"
EOF

  cat > "${app_dir}/models.py" << EOF
from django.db import models
from apps.core.models import TimeStampedModel

# Modelos de la app "${app}"
EOF

  cat > "${app_dir}/admin.py" << EOF
from django.contrib import admin

# Registra aquí los modelos de la app "${app}"
EOF

  cat > "${app_dir}/views.py" << EOF
from django.views.generic import TemplateView

# Vistas de la app "${app}"
EOF

  cat > "${app_dir}/forms.py" << EOF
from django import forms

# Formularios de la app "${app}"
EOF

  cat > "${app_dir}/urls.py" << EOF
from django.urls import path
from . import views

app_name = "${app}"

urlpatterns = [
    # path("", views.IndexView.as_view(), name="index"),
]
EOF

  cat > "${app_dir}/tests/test_models.py" << EOF
from django.test import TestCase

# Tests de la app "${app}"
EOF

done

###############################################################################
# 5. Personalización app "core" (utilidades compartidas, sin modelos propios
#    de negocio, solo el TimeStampedModel abstracto)
###############################################################################
cat > apps/core/models.py << 'EOF'
from django.conf import settings
from django.db import models


class TimeStampedModel(models.Model):
    """Modelo base abstracto con auditoría de creación/actualización."""
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    creado_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    class Meta:
        abstract = True
EOF

cat > apps/core/mixins.py << 'EOF'
from django.contrib.auth.mixins import UserPassesTestMixin


class RolRequeridoMixin(UserPassesTestMixin):
    """Restringe el acceso a una vista según el rol del usuario autenticado.

    Uso:
        class MiVista(RolRequeridoMixin, View):
            roles_permitidos = ["ventanillero", "supervisor"]
    """
    roles_permitidos: list[str] = []

    def test_func(self):
        user = self.request.user
        return user.is_authenticated and getattr(user, "rol", None) in self.roles_permitidos
EOF

cat > apps/core/utils.py << 'EOF'
import uuid


def generar_codigo(prefijo="COD"):
    """Genera un código único legible (ej. para pasajes, encomiendas, comprobantes)."""
    return f"{prefijo}-{uuid.uuid4().hex[:8].upper()}"
EOF

cat > apps/core/context_processors.py << 'EOF'
def datos_globales(request):
    """Variables disponibles en todos los templates."""
    return {
        "nombre_sistema": "Sistema de Venta de Pasajes y Encomiendas",
    }
EOF

mkdir -p apps/core/templatetags
touch apps/core/templatetags/__init__.py
cat > apps/core/templatetags/core_extras.py << 'EOF'
from django import template

register = template.Library()


@register.filter
def moneda(valor):
    """Formatea un número como moneda: 150.5 -> 'Bs. 150.50'"""
    try:
        return f"Bs. {float(valor):,.2f}"
    except (TypeError, ValueError):
        return valor
EOF

# core no expone urls propias en config/urls.py, pero dejamos el archivo por consistencia
cat > apps/core/urls.py << 'EOF'
# La app "core" no expone rutas propias; contiene utilidades compartidas.
EOF

###############################################################################
# 6. Personalización app "usuarios" (modelo de usuario, login, registro)
###############################################################################
cat > apps/usuarios/models.py << 'EOF'
from django.contrib.auth.models import AbstractUser
from django.db import models


class Usuario(AbstractUser):
    ROL_CHOICES = [
        ("cliente", "Cliente"),
        ("ventanillero", "Ventanillero"),
        ("supervisor", "Supervisor"),
        ("admin", "Administrador"),
    ]

    rol = models.CharField(max_length=20, choices=ROL_CHOICES, default="cliente")
    telefono = models.CharField(max_length=20, blank=True)
    ci = models.CharField(max_length=20, unique=True, null=True, blank=True)

    # Descomenta esta relación una vez que definas el modelo Terminal
    # en apps/rutas/models.py (útil para asignar ventanilleros a una terminal):
    #
    # terminal_asignado = models.ForeignKey(
    #     "rutas.Terminal", null=True, blank=True, on_delete=models.SET_NULL
    # )

    def __str__(self):
        return self.get_full_name() or self.username
EOF

cat > apps/usuarios/admin.py << 'EOF'
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import Usuario


@admin.register(Usuario)
class UsuarioAdmin(UserAdmin):
    list_display = ("username", "email", "rol", "is_staff")
    fieldsets = UserAdmin.fieldsets + (
        ("Información adicional", {"fields": ("rol", "telefono", "ci")}),
    )
EOF

cat > apps/usuarios/forms.py << 'EOF'
from django.contrib.auth.forms import UserCreationForm
from .models import Usuario


class RegistroClienteForm(UserCreationForm):
    class Meta(UserCreationForm.Meta):
        model = Usuario
        fields = ("username", "email", "first_name", "last_name", "telefono", "ci")
EOF

cat > apps/usuarios/views.py << 'EOF'
from django.contrib.auth.views import LoginView, LogoutView
from django.urls import reverse_lazy
from django.views.generic import CreateView
from .forms import RegistroClienteForm


class LoginUsuarioView(LoginView):
    template_name = "usuarios/login.html"


class LogoutUsuarioView(LogoutView):
    pass


class RegistroClienteView(CreateView):
    form_class = RegistroClienteForm
    template_name = "usuarios/registro.html"
    success_url = reverse_lazy("usuarios:login")
EOF

cat > apps/usuarios/urls.py << 'EOF'
from django.urls import path
from . import views

app_name = "usuarios"

urlpatterns = [
    path("login/", views.LoginUsuarioView.as_view(), name="login"),
    path("logout/", views.LogoutUsuarioView.as_view(), name="logout"),
    path("registro/", views.RegistroClienteView.as_view(), name="registro"),
]
EOF

cat > apps/usuarios/templates/usuarios/login.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Iniciar sesión</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Ingresar</button>
</form>
{% endblock %}
EOF

cat > apps/usuarios/templates/usuarios/registro.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Crear cuenta</h2>
<form method="post">
  {% csrf_token %}
  {{ form.as_p }}
  <button type="submit">Registrarme</button>
</form>
{% endblock %}
EOF

###############################################################################
# 7. Personalización app "rutas" (vista índice mínima, referenciada por
#    LOGIN_REDIRECT_URL para que el proyecto arranque sin errores)
###############################################################################
cat > apps/rutas/views.py << 'EOF'
from django.views.generic import TemplateView


class IndexView(TemplateView):
    template_name = "rutas/index.html"
EOF

cat > apps/rutas/urls.py << 'EOF'
from django.urls import path
from . import views

app_name = "rutas"

urlpatterns = [
    path("", views.IndexView.as_view(), name="index"),
]
EOF

cat > apps/rutas/templates/rutas/index.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<h2>Bienvenido, {{ user.get_full_name|default:user.username }}</h2>
<p>Panel principal del sistema. Aquí irá el listado de rutas y horarios.</p>
{% endblock %}
EOF

###############################################################################
# 8. Templates globales
###############################################################################
cat > templates/base.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}{{ nombre_sistema }}{% endblock %}</title>
  <link rel="stylesheet" href="{% static 'css/styles.css' %}">
</head>
<body>
  {% include "partials/navbar.html" %}
  {% include "partials/mensajes.html" %}

  <main class="contenedor">
    {% block content %}{% endblock %}
  </main>

  {% include "partials/footer.html" %}
</body>
</html>
EOF
# nota: {% load static %} se agrega en producción real; aquí se deja simple.
sed -i '1i {% load static %}' templates/base.html

cat > templates/base_ventanilla.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<div class="layout-ventanilla">
  {% block contenido_ventanilla %}{% endblock %}
</div>
{% endblock %}
EOF

cat > templates/base_cliente.html << 'EOF'
{% extends "base.html" %}
{% block content %}
<div class="layout-cliente">
  {% block contenido_cliente %}{% endblock %}
</div>
{% endblock %}
EOF

cat > templates/partials/navbar.html << 'EOF'
<nav class="navbar">
  <span class="navbar-brand">{{ nombre_sistema }}</span>
  {% if user.is_authenticated %}
    <span>{{ user.get_full_name|default:user.username }} ({{ user.rol }})</span>
    <a href="{% url 'usuarios:logout' %}">Salir</a>
  {% else %}
    <a href="{% url 'usuarios:login' %}">Iniciar sesión</a>
  {% endif %}
</nav>
EOF

cat > templates/partials/footer.html << 'EOF'
<footer class="footer">
  <p>&copy; {{ now|date:"Y" }} Sistema de Venta de Pasajes y Encomiendas</p>
</footer>
EOF

cat > templates/partials/mensajes.html << 'EOF'
{% if messages %}
<ul class="mensajes">
  {% for message in messages %}
    <li class="mensaje mensaje-{{ message.tags }}">{{ message }}</li>
  {% endfor %}
</ul>
{% endif %}
EOF

cat > static/css/styles.css << 'EOF'
/* Estilos base del sistema - personalizar según diseño definitivo */
body {
  font-family: system-ui, sans-serif;
  margin: 0;
  color: #1a1a1a;
}

.navbar {
  display: flex;
  justify-content: space-between;
  padding: 1rem 2rem;
  background: #0f4c81;
  color: #fff;
}

.navbar a { color: #fff; margin-left: 1rem; }

.contenedor {
  max-width: 1100px;
  margin: 2rem auto;
  padding: 0 1rem;
}

.footer {
  text-align: center;
  padding: 1rem;
  color: #666;
  font-size: 0.9rem;
}

.mensajes { list-style: none; padding: 0; }
.mensaje { padding: 0.75rem 1rem; margin-bottom: 0.5rem; border-radius: 4px; }
.mensaje-success { background: #d1f5d3; }
.mensaje-error { background: #fdd; }
EOF

###############################################################################
# 9. requirements/
###############################################################################
cat > requirements/base.txt << 'EOF'
Django>=5.0,<5.1
psycopg2-binary>=2.9
python-dotenv>=1.0
Pillow>=10.0
reportlab>=4.0
EOF

cat > requirements/local.txt << 'EOF'
-r base.txt
django-debug-toolbar>=4.3
EOF

cat > requirements/production.txt << 'EOF'
-r base.txt
gunicorn>=22.0
whitenoise>=6.6
EOF

###############################################################################
# 10. Docker
###############################################################################
cat > docker/django/Dockerfile << 'EOF'
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY requirements/ requirements/
ARG REQUIREMENTS_FILE=requirements/local.txt
RUN pip install --no-cache-dir -r ${REQUIREMENTS_FILE}

COPY . .

RUN chmod +x scripts/entrypoint.sh

ENTRYPOINT ["scripts/entrypoint.sh"]
EOF

cat > docker/nginx/Dockerfile << 'EOF'
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
EOF

cat > docker/nginx/nginx.conf << 'EOF'
upstream django {
    server web:8000;
}

server {
    listen 80;

    location /static/ {
        alias /app/staticfiles/;
    }

    location /media/ {
        alias /app/media/;
    }

    location / {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

cat > scripts/entrypoint.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "Esperando a PostgreSQL en ${POSTGRES_HOST}:${POSTGRES_PORT}..."
while ! nc -z "${POSTGRES_HOST}" "${POSTGRES_PORT}"; do
  sleep 0.5
done
echo "PostgreSQL disponible."

python manage.py migrate --noinput
python manage.py collectstatic --noinput --clear || true

exec "$@"
EOF
chmod +x scripts/entrypoint.sh

cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    env_file:
      - .env
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  web:
    build:
      context: .
      dockerfile: docker/django/Dockerfile
      args:
        REQUIREMENTS_FILE: requirements/local.txt
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - .:/app
    ports:
      - "8000:8000"
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy

volumes:
  postgres_data:
EOF

cat > docker-compose.prod.yml << 'EOF'
version: "3.9"

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data/
    env_file:
      - .env

  web:
    build:
      context: .
      dockerfile: docker/django/Dockerfile
      args:
        REQUIREMENTS_FILE: requirements/production.txt
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 3
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    env_file:
      - .env
    environment:
      - DJANGO_SETTINGS_MODULE=config.settings.production
    depends_on:
      - db

  nginx:
    build:
      context: ./docker/nginx
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    ports:
      - "80:80"
    depends_on:
      - web

volumes:
  postgres_data:
  static_volume:
  media_volume:
EOF

###############################################################################
# 11. Variables de entorno
###############################################################################
cat > .env.example << 'EOF'
DJANGO_SETTINGS_MODULE=config.settings.local
SECRET_KEY=cambia-esta-clave-por-una-segura
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

POSTGRES_DB=transporte_db
POSTGRES_USER=transporte_user
POSTGRES_PASSWORD=cambia-esta-password
POSTGRES_HOST=db
POSTGRES_PORT=5432
EOF

cp .env.example .env

###############################################################################
# 12. .gitignore y README
###############################################################################
cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
*.sqlite3
.env
/staticfiles/
/media/*
!/media/comprobantes/.gitkeep
!/media/comprobantes_encomiendas/.gitkeep
!/media/encomiendas/.gitkeep
venv/
.venv/
*.log
.DS_Store
EOF

cat > README.md << 'EOF'
# Sistema de Venta de Pasajes y Encomiendas

Proyecto Django (MVT) + PostgreSQL, ejecutado con Docker.

## Primeros pasos

1. Revisa y ajusta las variables en `.env` (ya se creó una copia de `.env.example`).

2. Construye las imágenes:

   ```bash
   docker compose build
   ```

3. Levanta los servicios (web + base de datos):

   ```bash
   docker compose up -d
   ```

   El `entrypoint.sh` espera a que PostgreSQL esté listo, aplica migraciones
   y recolecta archivos estáticos automáticamente.

4. Crea un superusuario para entrar al admin:

   ```bash
   docker compose exec web python manage.py createsuperuser
   ```

5. Abre el sistema:

   - Aplicación: http://localhost:8000
   - Admin: http://localhost:8000/admin

## Comandos útiles

```bash
# Ver logs
docker compose logs -f web

# Crear una migración tras modificar modelos
docker compose exec web python manage.py makemigrations

# Aplicar migraciones manualmente
docker compose exec web python manage.py migrate

# Abrir una shell de Django
docker compose exec web python manage.py shell

# Detener todo
docker compose down
```

## Estructura de apps

| App | Responsabilidad |
|---|---|
| usuarios | Autenticación, roles (cliente, ventanillero, supervisor, admin) |
| rutas | Terminales, rutas, horarios |
| flota | Buses, tipos de bus, asientos |
| viajes | Viaje programado (ruta + bus + fecha) y disponibilidad de asientos |
| ventas | Pasajes, pagos, comprobantes, reembolsos |
| encomiendas | Registro y seguimiento de paquetería |
| incidencias | Alertas, reclamos, tickets de soporte |
| reportes | Reportes de ventas diarios/semanales/mensuales |
| promociones | Descuentos y cupones |
| personal | Desempeño del personal de ventanilla |
| core | Utilidades compartidas (modelo base, mixins, context processors) |

## Producción

Para producción se usa `docker-compose.prod.yml`, que añade Gunicorn y Nginx,
y fuerza `DJANGO_SETTINGS_MODULE=config.settings.production`:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```
EOF

###############################################################################
# Fin
###############################################################################
cd ..
echo ""
echo "Proyecto '${PROJECT_ROOT}' creado correctamente."
echo ""
echo "Siguientes pasos:"
echo "  cd ${PROJECT_ROOT}"
echo "  docker compose build"
echo "  docker compose up -d"
echo "  docker compose exec web python manage.py createsuperuser"
echo ""