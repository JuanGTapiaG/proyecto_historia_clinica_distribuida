#!/bin/bash

echo "========================================="
echo "🛑 DETENIENDO HISTORIA CLÍNICA DISTRIBUIDA"
echo "========================================="
echo ""

echo "📦 Eliminando recursos Kubernetes..."
kubectl delete -f ../k8s/ --ignore-not-found=true

echo ""
echo "🗄️ Deteniendo Minikube..."
minikube stop

echo ""
echo "✅ Sistema detenido correctamente"
echo ""
echo "Para volver a iniciar: ./start.sh"
