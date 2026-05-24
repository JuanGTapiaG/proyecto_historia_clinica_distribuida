#!/bin/bash

echo "========================================="
echo "⚠️  SIMULANDO CAÍDA DE BASE DE DATOS"
echo "========================================="
echo ""

echo "🗄️ Desconectando worker de Citus..."
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT citus_remove_node('citus-worker-0.citus-worker', 5432);"

echo ""
echo "✅ Worker eliminado del clúster"
echo ""

echo "🔍 Workers activos:"
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT * FROM citus_get_active_worker_nodes();"
echo ""

MINIKUBE_IP=$(minikube ip)
echo "📡 El sistema sigue funcionando con el worker restante"
echo "   Frontend: http://$MINIKUBE_IP:30080"
echo ""

echo "🔄 Para restaurar el worker:"
echo "   kubectl rollout restart statefulset citus-worker -n historia-clinica-distribuida"
echo "   Luego ejecutar en el coordinador: SELECT citus_add_node('citus-worker-0.citus-worker', 5432);"
echo ""
