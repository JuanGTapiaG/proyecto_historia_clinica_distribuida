# 🏥 Historia Clínica Distribuida

> Sistema distribuido de historia clínica electrónica basado en **HL7 FHIR**, orquestado con **Kubernetes**, con base de datos distribuida **PostgreSQL + Citus** y balanceo de carga mediante **Nginx**. Diseñado para operar en múltiples nodos geográficos dentro del territorio colombiano.

---

## 📑 Tabla de Contenidos

- [Descripción General](#-descripción-general)
- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Stack Tecnológico](#-stack-tecnológico)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Prerrequisitos](#-prerrequisitos)
- [Instalación y Despliegue](#-instalación-y-despliegue)
- [Esquema de Base de Datos](#-esquema-de-base-de-datos)
- [API FHIR](#-api-fhir)
- [Frontend](#-frontend)
- [Scripts Operacionales](#-scripts-operacionales)
- [Pruebas con Postman](#-pruebas-con-postman)
- [Simulación de Fallos](#-simulación-de-fallos)
- [Modelo de Distribución de Datos](#-modelo-de-distribución-de-datos)
- [Monitoreo y Operaciones](#-monitoreo-y-operaciones)
- [Consideraciones de Seguridad](#-consideraciones-de-seguridad)
- [Licencia](#-licencia)

---

## 📋 Descripción General

Este proyecto implementa un **sistema de historia clínica electrónica distribuida** que permite la gestión unificada de registros médicos a través de múltiples nodos geográficos en Colombia. El sistema garantiza:

- **Alta disponibilidad**: Tolerancia a fallos mediante redundancia de nodos FHIR y balanceo de carga.
- **Distribución geográfica**: 3 nodos de aplicación ubicados en Sincelejo, Bogotá y Medellín.
- **Interoperabilidad**: Cumplimiento del estándar **HL7 FHIR R4** para intercambio de datos clínicos.
- **Escalabilidad horizontal**: Base de datos distribuida con sharding automático vía Citus.
- **Consistencia de datos**: Co-localización de tablas relacionadas bajo la misma clave de distribución (`documento_id`).

---

## 🏗 Arquitectura del Sistema

```
                        ┌──────────────────────┐
                        │     Cliente Web       │
                        │  (Frontend HTML/JS)   │
                        └──────────┬───────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │   Nginx Balancer      │
                        │   (NodePort :30080)   │
                        │   least_conn          │
                        └──┬───────┬────────┬──┘
                           │       │        │
              ┌────────────┘       │        └────────────┐
              ▼                    ▼                     ▼
   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
   │  HAPI FHIR      │  │  HAPI FHIR      │  │  HAPI FHIR      │
   │  Sincelejo      │  │  Bogotá         │  │  Medellín       │
   │  (Costa)        │  │  (Centro)       │  │  (Antioquia)    │
   └────────┬────────┘  └────────┬────────┘  └────────┬────────┘
            │                    │                     │
            └────────────┬───────┘─────────────────────┘
                         ▼
              ┌──────────────────────┐
              │  Citus Coordinator   │
              │  (PostgreSQL 14)     │
              │  :5432               │
              └──────────┬───────────┘
                    ┌────┴────┐
                    ▼         ▼
           ┌─────────────┐ ┌─────────────┐
           │ Citus       │ │ Citus       │
           │ Worker 0    │ │ Worker 1    │
           │ (Shards)    │ │ (Shards)    │
           └─────────────┘ └─────────────┘
```

### Flujo de datos

1. El **cliente web** envía peticiones HTTP al balanceador Nginx expuesto en el puerto `30080`.
2. **Nginx** distribuye la carga entre los 3 nodos HAPI FHIR usando el algoritmo `least_conn` (menor número de conexiones activas).
3. Cada nodo **HAPI FHIR** se conecta al **Coordinador Citus**, que actúa como punto de entrada unificado a la base de datos.
4. El coordinador **enruta las consultas** hacia los **workers** apropiados según la clave de distribución (`documento_id`).
5. Las tablas de referencia (como `profesional_salud`) se **replican completamente** en todos los workers.

---

## 🛠 Stack Tecnológico

| Componente | Tecnología | Versión | Propósito |
|---|---|---|---|
| **Orquestación** | Kubernetes (Minikube) | Latest | Gestión de contenedores y servicios |
| **Base de datos** | PostgreSQL + Citus | 11.2 | Base de datos relacional distribuida |
| **Servidor FHIR** | HAPI FHIR JPA Server | Latest | API REST compatible con HL7 FHIR R4 |
| **Balanceador** | Nginx | Latest | Balanceo de carga y proxy reverso |
| **Frontend** | HTML5 + CSS3 + JavaScript | — | Interfaz de usuario web |
| **Gráficos** | Chart.js | CDN | Visualización de reportes y dashboards |
| **Contenedores** | Docker | — | Runtime de contenedores (driver de Minikube) |
| **Pruebas API** | Postman | — | Colección de pruebas CRUD FHIR |

---

## 📂 Estructura del Proyecto

```
proyecto_historia_clinica_distribuida/
│
├── database/                        # Capa de datos distribuida
│   ├── schema_citus.sql             # Esquema DDL (tablas, índices, datos semilla)
│   └── init-citus.sh                # Script de inicialización del clúster Citus
│
├── frontend/                        # Interfaz de usuario web
│   ├── index.html                   # Página principal (dashboard clínico)
│   ├── app.js                       # Lógica de negocio y comunicación FHIR
│   └── styles.css                   # Estilos de la aplicación
│
├── k8s/                             # Manifiestos de Kubernetes
│   ├── namespace.yaml               # Namespace: historia-clinica-distribuida
│   ├── secrets.yaml                 # Credenciales de base de datos
│   ├── citus-coordinator.yaml       # Deployment + Service del coordinador
│   ├── citus-worker.yaml            # StatefulSet + Headless Service de workers
│   ├── hapi-sincelejo.yaml          # Nodo FHIR - Sincelejo (Costa)
│   ├── hapi-bogota.yaml             # Nodo FHIR - Bogotá (Centro)
│   ├── hapi-medellin.yaml           # Nodo FHIR - Medellín (Antioquia)
│   └── nginx-balancer.yaml          # ConfigMap + Deployment + NodePort
│
├── scripts/                         # Scripts de operación y pruebas
│   ├── start.sh                     # Despliegue completo del sistema
│   ├── stop.sh                      # Detención y limpieza
│   ├── test-crud.sh                 # Pruebas CRUD automatizadas
│   ├── simulate-node-failure.sh     # Simulación de caída de nodo FHIR
│   └── simulate-bd-failure.sh       # Simulación de caída de worker Citus
│
├── postman/                         # Colección de pruebas Postman
│   └── FHIR_3_Nodos_Collection.json # 13 requests CRUD + tolerancia a fallos
│
├── capturas/                        # Capturas de pantalla y evidencias
├── paper/                           # Documentación académica del proyecto
├── .gitignore                       # Archivos excluidos del repositorio
└── README.md                        # Este archivo
```

---

## ⚙ Prerrequisitos

Antes de desplegar el sistema, asegúrese de tener instalado:

| Herramienta | Versión mínima | Instalación |
|---|---|---|
| **Docker** | 20.10+ | [docs.docker.com](https://docs.docker.com/engine/install/) |
| **Minikube** | 1.30+ | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/docs/start/) |
| **kubectl** | 1.27+ | [kubernetes.io/docs](https://kubernetes.io/docs/tasks/tools/) |
| **curl** | 7.x+ | Preinstalado en la mayoría de distribuciones Linux |
| **bash** | 4.x+ | Preinstalado en Linux |

### Recursos mínimos recomendados

- **CPU**: 4 cores (dedicados a Minikube)
- **RAM**: 8 GB (asignados a Minikube)
- **Disco**: 20 GB libres
- **Red**: Acceso a Internet para descargar imágenes de contenedores

---

## 🚀 Instalación y Despliegue

### 1. Clonar el repositorio

```bash
git clone https://github.com/JuanGTapiaG/proyecto_historia_clinica_distribuida
cd proyecto_historia_clinica_distribuida
```

### 2. Despliegue automático

El script `start.sh` realiza todo el proceso de forma automatizada:

```bash
cd scripts
chmod +x *.sh
./start.sh
```

Este script ejecuta los siguientes pasos en orden:

1. **Verifica/inicia Minikube** con 4 CPUs y 8 GB de RAM usando el driver Docker.
2. **Crea el namespace** `historia-clinica-distribuida` y los secrets de base de datos.
3. **Despliega Citus** (1 coordinador + 2 workers como StatefulSet).
4. **Inicializa la base de datos**: crea la extensión Citus, registra workers, ejecuta el esquema SQL y distribuye las tablas.
5. **Despliega 3 nodos HAPI FHIR** (Sincelejo, Bogotá, Medellín).
6. **Despliega Nginx** como balanceador de carga con NodePort en el puerto `30080`.

### 3. Verificar el despliegue

```bash
# Ver el estado de todos los pods
kubectl get pods -n historia-clinica-distribuida

# Verificar que todos los servicios están activos
kubectl get svc -n historia-clinica-distribuida

# Guardar la IP de Minikube en una variable
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"
```

### 4. Acceder al sistema

```bash
# Guardar la IP de Minikube en una variable (si no se ha hecho antes)
MINIKUBE_IP=$(minikube ip)

# Frontend web
echo "Frontend: http://$MINIKUBE_IP:30080"

# API FHIR (metadata/health check)
curl http://$MINIKUBE_IP:30080/fhir/metadata
```

### 5. Detener el sistema

```bash
cd scripts
./stop.sh
```

---

## 🗄 Esquema de Base de Datos

La base de datos `historia_clinica` utiliza **PostgreSQL 14 con la extensión Citus 11.2** para distribución horizontal.

### Tablas Distribuidas

Todas las tablas clínicas se distribuyen por `documento_id` (número de identificación del paciente), lo que garantiza **co-localización** de los datos relacionados de un mismo paciente en el mismo shard.

| Tabla | Tipo | Clave de distribución | Descripción |
|---|---|---|---|
| `usuario` | Distribuida | `documento_id` | Datos demográficos del paciente |
| `atencion` | Distribuida | `documento_id` | Registros de atención clínica |
| `diagnostico` | Distribuida | `documento_id` | Diagnósticos con código CIE-10 |
| `tecnologia_salud` | Distribuida | `documento_id` | Medicamentos y prescripciones |
| `egreso` | Distribuida | `documento_id` | Registros de alta y recomendaciones |
| `profesional_salud` | Referencia (replicada) | — | Catálogo de profesionales de salud |

### Diagrama Entidad-Relación

```
┌─────────────────┐
│    usuario       │       ┌──────────────────────┐
│─────────────────│       │  profesional_salud    │
│ documento_id PK │       │──────────────────────│
│ nombre_completo  │       │ id_personal_salud PK │
│ fecha_nacimiento │       │ nombre               │
│ sexo / genero    │       │ especialidad          │
│ ocupacion        │       │ registro_medico       │
│ zona_residencia  │       │ activo                │
└────────┬────────┘       └──────────────────────┘
         │                         ▲
         │ 1:N                     │ referenciado por
         ▼                         │
┌─────────────────┐               │
│    atencion      │               │
│─────────────────│               │
│ atencion_id     │               │
│ documento_id FK │               │
│ entidad_salud    │               │
│ fecha_ingreso    │               │
│ modalidad        │               │
│ triage           │               │
└────────┬────────┘               │
         │ 1:N                     │
    ┌────┴────┬───────────────┐   │
    ▼         ▼               ▼   │
┌────────┐ ┌──────────┐ ┌────────┴───────┐
│diagnós-│ │  egreso   │ │tecnologia_salud│
│tico    │ │           │ │  (medicamentos)│
│────────│ │──────────│ │────────────────│
│diag_id │ │egreso_id │ │tecnologia_id   │
│doc_id  │ │doc_id    │ │doc_id          │
│aten_id │ │aten_id   │ │aten_id         │
│CIE-10  │ │condición │ │medicamento     │
└────────┘ │incapac.  │ │dosis/frecuencia│
           └──────────┘ │id_personal_sal.│
                         └────────────────┘
```

### Índices de rendimiento

```sql
CREATE INDEX idx_usuario_nombre    ON usuario(nombre_completo);
CREATE INDEX idx_atencion_fecha    ON atencion(fecha_ingreso);
CREATE INDEX idx_diagnostico_codigo ON diagnostico(codigo_cie10);
```

---

## 🔌 API FHIR

El sistema expone una API REST compatible con **HL7 FHIR R4** a través de los servidores HAPI FHIR. El endpoint base es:

```bash
MINIKUBE_IP=$(minikube ip)
# Endpoint base:
# http://$MINIKUBE_IP:30080/fhir
```

### Recursos FHIR soportados

| Recurso FHIR | Operaciones | Uso clínico |
|---|---|---|
| `Patient` | CREATE, READ, SEARCH | Registro y consulta de pacientes |
| `Observation` | CREATE, READ, SEARCH | Signos vitales y resultados de triage |
| `Condition` | CREATE, READ, SEARCH | Diagnósticos clínicos |
| `MedicationRequest` | CREATE, READ, SEARCH | Prescripciones farmacológicas |

### Ejemplos de uso con cURL

#### Crear un paciente

```bash
MINIKUBE_IP=$(minikube ip)
curl -X POST "http://$MINIKUBE_IP:30080/fhir/Patient" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "identifier": [{"system": "http://hospital.gov.co/id", "value": "123456789"}],
    "name": [{"use": "official", "family": "Gómez", "given": ["Ana María"]}],
    "gender": "female",
    "birthDate": "1990-05-15"
  }'
```

#### Buscar paciente por identificación

```bash
MINIKUBE_IP=$(minikube ip)
curl "http://$MINIKUBE_IP:30080/fhir/Patient?identifier=123456789"
```

#### Registrar signos vitales

```bash
MINIKUBE_IP=$(minikube ip)
curl -X POST "http://$MINIKUBE_IP:30080/fhir/Observation" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Observation",
    "status": "final",
    "code": {"coding": [{"system": "http://loinc.org", "code": "85354-9"}]},
    "subject": {"reference": "Patient/<PATIENT_ID>"},
    "component": [
      {"code": {"coding": [{"code": "8480-6"}]}, "valueQuantity": {"value": 120, "unit": "mmHg"}},
      {"code": {"coding": [{"code": "8867-4"}]}, "valueQuantity": {"value": 75, "unit": "/min"}}
    ]
  }'
```

#### Registrar diagnóstico

```bash
MINIKUBE_IP=$(minikube ip)
curl -X POST "http://$MINIKUBE_IP:30080/fhir/Condition" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Condition",
    "clinicalStatus": {"coding": [{"code": "active"}]},
    "code": {"coding": [{"display": "Hipertensión esencial"}]},
    "subject": {"reference": "Patient/<PATIENT_ID>"}
  }'
```

#### Health check

```bash
MINIKUBE_IP=$(minikube ip)
curl "http://$MINIKUBE_IP:30080/fhir/metadata"
```

### Headers de respuesta útiles

| Header | Descripción |
|---|---|
| `X-Upstream` | Indica a cuál nodo FHIR respondió Nginx (útil para verificar balanceo) |

---

## 🖥 Frontend

El frontend es una **aplicación web estática** (HTML5 + CSS3 + JavaScript vanilla) servida por Nginx y accesible en `http://$MINIKUBE_IP:30080` (donde `MINIKUBE_IP=$(minikube ip)`).

### Módulos funcionales

| Módulo | Descripción | Recurso FHIR |
|---|---|---|
| **📋 Admisión** | Registro de nuevos pacientes con datos demográficos | `Patient` |
| **🩺 Triage** | Registro de signos vitales con clasificación Manchester automática | `Observation` |
| **👨‍⚕️ Médico** | Registro de diagnósticos y prescripción de medicamentos | `Condition` + `MedicationRequest` |
| **📄 Historia Clínica** | Consulta consolidada del historial completo del paciente | Todos |
| **📊 Reportes** | Dashboard con gráficos de pacientes por nodo, diagnósticos frecuentes y KPIs | — |

### Clasificación de Triage Manchester

El módulo de triage implementa un algoritmo de clasificación basado en signos vitales:

| Nivel | Color | Descripción | Tiempo máximo de espera |
|---|---|---|---|
| 1 | 🔴 Rojo | Reanimación | Inmediato |
| 2 | 🟠 Naranja | Emergencia | 10 minutos |
| 3 | 🟡 Amarillo | Urgente | 30 minutos |
| 4 | 🟢 Verde | Menos Urgente | 60 minutos |
| 5 | 🔵 Azul | No Urgente | 120 minutos |

### Selector de nodo

La interfaz permite seleccionar el modo de operación:

- **⚖️ Balanceado**: Nginx distribuye automáticamente (por defecto).
- **🏙️ Sincelejo**: Forzar peticiones al nodo de la Costa.
- **🏔️ Bogotá**: Forzar peticiones al nodo Centro.
- **🌆 Medellín**: Forzar peticiones al nodo de Antioquia.

---

## 🔧 Scripts Operacionales

Todos los scripts se encuentran en el directorio `scripts/` y deben ejecutarse desde esa ubicación.

### `start.sh` — Despliegue completo

```bash
cd scripts && ./start.sh
```

Levanta todo el sistema de forma automatizada: Minikube → Kubernetes → Citus → HAPI FHIR → Nginx.

### `stop.sh` — Detener el sistema

```bash
cd scripts && ./stop.sh
```

Elimina todos los recursos de Kubernetes y detiene Minikube.

### `test-crud.sh` — Pruebas CRUD

```bash
cd scripts && ./test-crud.sh
```

Ejecuta una secuencia de pruebas automáticas:

1. ✅ Health check del servidor FHIR
2. ✅ Crear paciente de prueba
3. ✅ Buscar paciente por identificador
4. ✅ Registrar signos vitales (Observation)

### `simulate-node-failure.sh` — Simular caída de nodo

```bash
cd scripts && ./simulate-node-failure.sh hapi-sincelejo
```

Escala a 0 réplicas el nodo especificado, simulando una caída. Nginx redirige automáticamente el tráfico a los nodos restantes.

**Nodos disponibles**: `hapi-sincelejo`, `hapi-bogota`, `hapi-medellin`

**Restaurar el nodo**:

```bash
kubectl scale deployment hapi-sincelejo -n historia-clinica-distribuida --replicas=1
```

### `simulate-bd-failure.sh` — Simular caída de worker de BD

```bash
cd scripts && ./simulate-bd-failure.sh
```

Elimina un worker del clúster Citus, el sistema sigue operando con el worker restante.

**Restaurar el worker**:

```bash
kubectl rollout restart statefulset citus-worker -n historia-clinica-distribuida
# Esperar a que reinicie, luego:
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
  psql -U admin -d historia_clinica -c "SELECT citus_add_node('citus-worker-0.citus-worker', 5432);"
```

---

## 📮 Pruebas con Postman

Se incluye una colección Postman completa en `postman/FHIR_3_Nodos_Collection.json` con 13 requests organizados secuencialmente.

### Importar la colección

1. Abrir Postman.
2. Ir a **File → Import**.
3. Seleccionar el archivo `postman/FHIR_3_Nodos_Collection.json`.
4. Configurar la variable `minikube_ip` con la IP de su Minikube (`minikube ip`).

### Requests incluidos

| # | Request | Método | Descripción |
|---|---|---|---|
| 01 | Health Check | GET | Verificar disponibilidad del servidor |
| 02 | Crear paciente (Sincelejo) | POST | Registrar paciente: Ana María Gómez |
| 03 | Crear paciente (Bogotá) | POST | Registrar paciente: Carlos Rodríguez |
| 04 | Crear paciente (Medellín) | POST | Registrar paciente: Laura Martínez |
| 05 | Buscar por identificación | GET | Consultar paciente por documento |
| 06 | Registrar signos vitales | POST | Observation con panel de vitales |
| 07 | Registrar diagnóstico | POST | Condition: Hipertensión esencial |
| 08 | Prescribir medicamento | POST | MedicationRequest: Enalapril 10mg |
| 09 | Historia clínica completa | GET | Obtener datos del paciente |
| 10 | Signos vitales del paciente | GET | Listar Observations |
| 11 | Diagnósticos del paciente | GET | Listar Conditions |
| 12 | Listar todos los pacientes | GET | Paginado (20 por página) |
| 13 | Prueba de tolerancia a fallos | GET | Verifica respuesta post-caída de nodo |

---

## 💥 Simulación de Fallos

El sistema está diseñado para demostrar **tolerancia a fallos** en dos niveles:

### Nivel 1: Caída de nodo de aplicación (HAPI FHIR)

```bash
# Simular caída del nodo Sincelejo
./simulate-node-failure.sh hapi-sincelejo

# Verificar que el sistema sigue respondiendo
MINIKUBE_IP=$(minikube ip)
curl http://$MINIKUBE_IP:30080/fhir/metadata
# ✅ Nginx redirige automáticamente a Bogotá o Medellín
```

**Comportamiento**: Nginx detecta el nodo caído (después de 3 intentos fallidos en 30 segundos) y redistribuye el tráfico entre los nodos activos.

### Nivel 2: Caída de worker de base de datos (Citus)

```bash
# Simular caída de un worker
./simulate-bd-failure.sh

# Verificar workers activos
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
  psql -U admin -d historia_clinica -c "SELECT * FROM citus_get_active_worker_nodes();"
```

**Comportamiento**: Las consultas que afectan shards del worker caído pueden fallar, pero los datos en el worker restante siguen accesibles.

---

## 🔀 Modelo de Distribución de Datos

### Estrategia de Sharding

- **Clave de distribución**: `documento_id` (número de identificación del paciente).
- **Método**: Hash-based sharding gestionado por Citus.
- **Co-localización**: Todas las tablas clínicas (`usuario`, `atencion`, `diagnostico`, `tecnologia_salud`, `egreso`) comparten la misma clave de distribución, lo que permite JOINs locales eficientes.

### Tabla de referencia

- `profesional_salud` se configura como **tabla de referencia** (`create_reference_table`), replicándose completamente en todos los workers. Esto permite JOINs eficientes sin transferencia de datos entre nodos.

### Distribución visual

```
Worker 0                          Worker 1
┌─────────────────────────┐      ┌─────────────────────────┐
│ Shards para documento_id│      │ Shards para documento_id│
│ con hash ∈ [0, N/2)     │      │ con hash ∈ [N/2, N)     │
│                         │      │                         │
│ ○ usuario (parcial)     │      │ ○ usuario (parcial)     │
│ ○ atencion (parcial)    │      │ ○ atencion (parcial)    │
│ ○ diagnostico (parcial) │      │ ○ diagnostico (parcial) │
│ ○ tecnologia_s (parcial)│      │ ○ tecnologia_s (parcial)│
│ ○ egreso (parcial)      │      │ ○ egreso (parcial)      │
│                         │      │                         │
│ ★ profesional_salud     │      │ ★ profesional_salud     │
│   (copia completa)      │      │   (copia completa)      │
└─────────────────────────┘      └─────────────────────────┘
```

---

## 📊 Monitoreo y Operaciones

### Verificar el estado del clúster

```bash
# Estado de todos los pods
kubectl get pods -n historia-clinica-distribuida

# Estado de los servicios
kubectl get svc -n historia-clinica-distribuida

# Ver tablas distribuidas en Citus
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
  psql -U admin -d historia_clinica -c "SELECT * FROM citus_tables;"

# Ver workers activos
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
  psql -U admin -d historia_clinica -c "SELECT * FROM citus_get_active_worker_nodes();"

# Ver distribución de shards
kubectl exec -n historia-clinica-distribuida deployment/citus-coordinator -- \
  psql -U admin -d historia_clinica -c "SELECT * FROM citus_shards;"
```

### Logs de los nodos

```bash
# Logs del nodo Sincelejo
kubectl logs -n historia-clinica-distribuida deployment/hapi-sincelejo --tail=50

# Logs del nodo Bogotá
kubectl logs -n historia-clinica-distribuida deployment/hapi-bogota --tail=50

# Logs del nodo Medellín
kubectl logs -n historia-clinica-distribuida deployment/hapi-medellin --tail=50

# Logs del coordinador Citus
kubectl logs -n historia-clinica-distribuida deployment/citus-coordinator --tail=50

# Logs del balanceador Nginx
kubectl logs -n historia-clinica-distribuida deployment/nginx-balancer --tail=50
```

### Health checks configurados

| Componente | Tipo de probe | Endpoint | Intervalo |
|---|---|---|---|
| Citus Coordinator | `livenessProbe` (exec) | `pg_isready -U admin -d historia_clinica` | 10s (delay: 30s) |
| HAPI FHIR (×3) | `livenessProbe` (HTTP) | `GET /fhir/metadata :8080` | 10s (delay: 30s) |
| HAPI FHIR (×3) | `readinessProbe` (HTTP) | `GET /fhir/metadata :8080` | 5s (delay: 15s) |

---

## 🔐 Consideraciones de Seguridad

> ⚠️ **Nota**: Esta configuración está diseñada para entornos de desarrollo y demostración académica. Para producción, implemente las siguientes mejoras:

| Aspecto | Estado actual | Recomendación para producción |
|---|---|---|
| **Contraseña BD** | `admin123` en base64 en secrets.yaml | Usar un gestor de secretos (Vault, AWS Secrets Manager) |
| **TLS/HTTPS** | No configurado | Implementar cert-manager con Let's Encrypt |
| **Autenticación API** | Sin autenticación | OAuth 2.0 / OpenID Connect |
| **RBAC** | No configurado | Configurar roles de Kubernetes |
| **Network Policies** | Sin restricciones | Limitar comunicación entre pods |
| **Persistencia** | Sin PersistentVolumes | Configurar PVCs para datos de Citus |
| **Backups** | Sin configurar | pg_dump distribuido + CronJobs |

---

## 📜 Licencia

Este proyecto fue desarrollado con fines académicos e investigativos. Consulte los términos específicos con el autor del proyecto antes de utilizar el código en entornos de producción.

---

<p align="center">
  Desarrollado con ❤️ para el sistema de salud colombiano 🇨🇴
</p>
