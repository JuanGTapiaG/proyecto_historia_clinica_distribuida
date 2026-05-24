#!/bin/bash

echo "========================================="
echo "🗄️ INICIALIZANDO CLUSTER CITUS"
echo "========================================="

# Esperar a que el coordinador esté listo
echo "⏳ Esperando coordinador..."
until kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- pg_isready -U admin -d historia_clinica 2>/dev/null; do
    echo -n "."
    sleep 2
done
echo ""
echo "✅ Coordinador listo"

# Crear extensión Citus
echo "🔌 Creando extensión Citus..."
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "CREATE EXTENSION IF NOT EXISTS citus;"

# Registrar workers
echo "➕ Registrando workers..."
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT citus_add_node('citus-worker-0.citus-worker', 5432);"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT citus_add_node('citus-worker-1.citus-worker', 5432);"

# Verificar workers activos
echo "✅ Workers activos:"
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT * FROM citus_get_active_worker_nodes();"

# Ejecutar schema (crear tablas)
echo "📊 Creando tablas..."
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -i -- \
    psql -U admin -d historia_clinica < schema_citus.sql

# Convertir a tablas distribuidas
echo "🔀 Distribuyendo tablas..."
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_distributed_table('usuario', 'documento_id');"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_distributed_table('atencion', 'documento_id');"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_distributed_table('diagnostico', 'documento_id');"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_distributed_table('tecnologia_salud', 'documento_id');"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_distributed_table('egreso', 'documento_id');"

kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
    psql -U admin -d historia_clinica -c "SELECT create_reference_table('profesional_salud');"

echo ""
echo "========================================="
echo "✅ CLUSTER CITUS INICIALIZADO"
echo "========================================="
echo ""
echo "Verificar con:"
echo "kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \\"
echo "    psql -U admin -d historia_clinica -c \"SELECT * FROM citus_tables;\""
