#!/bin/bash
set -e

echo "========================================="
echo "🏥 HISTORIA CLÍNICA DISTRIBUIDA"
echo "========================================="
echo ""

# Verificar Minikube
echo "🔍 Verificando Minikube..."
if ! minikube status > /dev/null 2>&1; then
    echo "🚀 Iniciando Minikube..."
    minikube start --cpus=4 --memory=8192 --driver=docker
else
    echo "✅ Minikube ya está corriendo"
fi

# Crear namespace y secretos
echo ""
echo "📦 Creando recursos Kubernetes..."
kubectl apply -f ../k8s/namespace.yaml
kubectl apply -f ../k8s/secrets.yaml

# Desplegar Citus
echo ""
echo "🗄️ Desplegando Citus (Base de Datos Distribuida)..."
kubectl apply -f ../k8s/citus-coordinator.yaml
kubectl apply -f ../k8s/citus-worker.yaml

# Esperar a que Citus esté listo
echo ""
echo "⏳ Esperando a que Citus esté listo (30 segundos)..."
sleep 30

# Inicializar base de datos
echo ""
echo "📊 Inicializando base de datos distribuida..."
cd ../database
./init-citus.sh
cd ../scripts

# Desplegar HAPI FHIR (3 nodos geográficos)
echo ""
echo "🏥 Desplegando 3 nodos HAPI FHIR..."
echo "   - Sincelejo (Costa)"
kubectl apply -f ../k8s/hapi-sincelejo.yaml
echo "   - Bogotá (Centro)"
kubectl apply -f ../k8s/hapi-bogota.yaml
echo "   - Medellín (Antioquia)"
kubectl apply -f ../k8s/hapi-medellin.yaml

# Desplegar Nginx con balanceador
echo ""
echo "⚖️ Desplegando Nginx (Balanceador de Carga)..."
kubectl apply -f ../k8s/nginx-balancer.yaml

# Esperar a que todos los pods estén listos
echo ""
echo "⏳ Esperando a que todos los pods estén listos (60 segundos)..."
sleep 60

# Mostrar estado final
echo ""
echo "========================================="
echo "✅ SISTEMA OPERATIVO"
echo "========================================="
echo ""

MINIKUBE_IP=$(minikube ip)
echo "📡 Frontend: http://$MINIKUBE_IP:30080"
echo "📡 FHIR API:  http://$MINIKUBE_IP:30080/fhir"
echo ""

echo "🔍 Estado de los pods:"
kubectl get pods -n historia-clinica-distribuida
echo ""

echo "📋 Para ver logs de un nodo específico:"
echo "   kubectl logs -n historia-clinica-distribuida deployment/hapi-sincelejo --tail=20"
echo ""

echo "🛑 Para detener el sistema: ./stop.sh"
echo "⚠️  Para simular fallo de un nodo: ./simulate-node-failure.sh hapi-sincelejo"
echo ""
