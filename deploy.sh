#!/bin/bash

# =============================================================================
# MicroarrAI - Script de Despliegue Rápido
# =============================================================================
# Este script automatiza el despliegue de MicroarrAI usando Docker
# =============================================================================

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo "============================================================================="
echo "  MicroarrAI - Despliegue con Docker"
echo "============================================================================="
echo ""

# Verificar que Docker está instalado
if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado. Por favor instala Docker first."
    echo "  Ubuntu/Debian: sudo apt install docker.io docker-compose"
    echo "  CentOS/RHEL: sudo yum install docker docker-compose"
    exit 1
fi

print_success "Docker está instalado"

# Verificar que Docker Compose está instalado
if ! command -v docker-compose &> /dev/null; then
    print_warning "Docker Compose no está instalado. Se usará 'docker compose'."
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

# Verificar que Docker está corriendo
if ! docker info &> /dev/null; then
    print_error "Docker no está corriendo. Inicia el servicio Docker:"
    echo "  sudo systemctl start docker"
    exit 1
fi

print_success "Docker está corriendo"

# Crear directorio de logs si no existe
if [ ! -d "logs" ]; then
    mkdir -p logs
    print_info "Directorio de logs creado"
fi

# Menú de opciones
echo ""
echo "Selecciona una opción:"
echo "  1) Construir y desplegar (primera vez)"
echo "  2) Iniciar aplicación existente"
echo "  3) Detener aplicación"
echo "  4) Ver logs"
echo "  5) Re-construir y actualizar"
echo "  6) Estado del contenedor"
echo "  7) Limpiar (eliminar contenedor e imagen)"
echo "  0) Salir"
echo ""
read -p "Opción: " option

case $option in
    1)
        print_info "Construyendo imagen Docker..."
        print_warning "Esto puede tardar 15-30 minutos la primera vez."
        
        $COMPOSE_CMD build
        
        print_success "Imagen construida exitosamente"
        print_info "Iniciando contenedor..."
        
        $COMPOSE_CMD up -d
        
        print_success "Contenedor iniciado"
        echo ""
        print_info "La aplicación estará disponible en:"
        echo "  http://localhost:3838/MicroarrAI"
        echo ""
        print_info "Para ver los logs en tiempo real:"
        echo "  $COMPOSE_CMD logs -f"
        ;;
    
    2)
        print_info "Iniciando aplicación..."
        $COMPOSE_CMD up -d
        print_success "Aplicación iniciada"
        echo ""
        print_info "Accede a la aplicación en:"
        echo "  http://localhost:3838/MicroarrAI"
        ;;
    
    3)
        print_info "Deteniendo aplicación..."
        $COMPOSE_CMD down
        print_success "Aplicación detenida"
        ;;
    
    4)
        print_info "Mostrando logs (Ctrl+C para salir)..."
        $COMPOSE_CMD logs -f
        ;;
    
    5)
        print_info "Deteniendo contenedor actual..."
        $COMPOSE_CMD down
        
        print_info "Re-construyendo imagen..."
        $COMPOSE_CMD build --no-cache
        
        print_info "Iniciando nuevo contenedor..."
        $COMPOSE_CMD up -d
        
        print_success "Aplicación actualizada y reiniciada"
        ;;
    
    6)
        print_info "Estado del contenedor:"
        $COMPOSE_CMD ps
        echo ""
        print_info "Uso de recursos:"
        docker stats --no-stream microarrai-app 2>/dev/null || print_warning "Contenedor no está corriendo"
        ;;
    
    7)
        print_warning "Esto eliminará el contenedor y la imagen."
        read -p "¿Estás seguro? (y/N): " confirm
        if [[ $confirm == "y" || $confirm == "Y" ]]; then
            print_info "Deteniendo y eliminando contenedor..."
            $COMPOSE_CMD down
            
            print_info "Eliminando imagen..."
            docker rmi microarrai:latest 2>/dev/null || print_warning "Imagen no encontrada"
            
            print_success "Limpieza completada"
        else
            print_info "Operación cancelada"
        fi
        ;;
    
    0)
        print_info "Saliendo..."
        exit 0
        ;;
    
    *)
        print_error "Opción no válida"
        exit 1
        ;;
esac

echo ""
print_success "Operación completada"
