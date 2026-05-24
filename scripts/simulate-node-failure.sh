#!/bin/bash

NODO=${1:-"hapi-sincelejo"}

echo "========================================="
echo "⚠️  SIMULANDO CAÍDA DE NODO"
echo "========================================="
echo ""

echo "📍 Nodo afectado: $NODO"
echo ""

# Escalar a 0 réplicas (simula caída)
echo "🔌 Desconectando nodo..."
kubectl scale deployment $NODO -n historia-clinica-distribuida --replicas=0

echo ""
echo "✅ Nodo $NODO ha sido desconectado"
echo ""

echo "🔍 Verificando estado actual:"
kubectl get pods -n historia-clinica-distribuida | grep hapi
echo ""

MINIKUBE_IP=$(minikube ip)
echo "📡 El sistema sigue funcionando en: http://$MINIKUBE_IP:30080"
echo "   (Nginx balancea automáticamente a los nodos restantes)"
echo ""

echo "🔄 Para restaurar el nodo:"
echo "   kubectl scale deployment $NODO -n historia-clinica-distribuida --replicas=1"
echo ""
