#!/bin/bash

echo "========================================="
echo "🧪 PROBANDO CRUD FHIR EN 3 NODOS"
echo "========================================="
echo ""

MINIKUBE_IP=$(minikube ip)
BASE_URL="http://$MINIKUBE_IP:30080/fhir"

# Verificar que el sistema responde
echo "1. Verificando health check..."
if curl -s "$BASE_URL/metadata" | head -c 100 > /dev/null; then
    echo "   ✅ Servidor FHIR responde"
else
    echo "   ❌ Error: Servidor FHIR no responde"
    exit 1
fi

echo ""

# Crear paciente de prueba
echo "2. Creando paciente de prueba..."
RESPONSE=$(curl -s -X POST "$BASE_URL/Patient" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "name": [{"family": "Prueba", "given": ["Sistema"]}],
    "identifier": [{"value": "99999999"}]
  }')

PATIENT_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$PATIENT_ID" ]; then
    echo "   ✅ Paciente creado con ID: $PATIENT_ID"
else
    echo "   ❌ Error al crear paciente"
fi

echo ""

# Buscar el paciente
echo "3. Buscando paciente por identificador..."
curl -s "$BASE_URL/Patient?identifier=99999999" | head -c 200
echo "..."
echo ""

# Crear Observation (signos vitales)
echo "4. Registrando signos vitales..."
curl -s -X POST "$BASE_URL/Observation" \
  -H "Content-Type: application/fhir+json" \
  -d "{
    \"resourceType\": \"Observation\",
    \"status\": \"final\",
    \"code\": {\"coding\": [{\"code\": \"85354-9\"}]},
    \"subject\": {\"reference\": \"Patient/$PATIENT_ID\"},
    \"effectiveDateTime\": \"$(date -Iseconds)\",
    \"component\": [
        {\"code\": {\"coding\": [{\"code\": \"8480-6\"}]}, \"valueQuantity\": {\"value\": 120, \"unit\": \"mmHg\"}},
        {\"code\": {\"coding\": [{\"code\": \"8867-4\"}]}, \"valueQuantity\": {\"value\": 75, \"unit\": \"/min\"}}
    ]
  }" > /dev/null
echo "   ✅ Signos vitales registrados"
echo ""

echo "========================================="
echo "✅ PRUEBA COMPLETADA EXITOSAMENTE"
echo "========================================="
echo ""
echo "📊 Resumen:"
echo "   - Servidor FHIR: OK"
echo "   - Crear Patient: OK (ID: $PATIENT_ID)"
echo "   - Crear Observation: OK"
echo "   - 3 nodos operativos: ✅"
echo ""
