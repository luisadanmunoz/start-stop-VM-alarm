# Start/Stop VM Alarm

Solución de automatización en Azure para gestionar el encendido y apagado programado de máquinas virtuales basándose en etiquetas (tags), con notificaciones automáticas por correo electrónico sobre el estado de las operaciones.

## Descripción.

Este proyecto implementa una infraestructura completa en Azure usando Terraform que permite:

- **Automatizar el encendido/apagado** de VMs según horarios definidos
- **Filtrar VMs por tags** (por ejemplo, `environment=pre`)
- **Enviar notificaciones por correo** con el resultado de cada operación
- **Monitorizar** la ejecución de los runbooks mediante Log Analytics y alertas programadas
- **Desplegar con red privada** usando Private Endpoints para mayor seguridad

## Arquitectura

La solución despliega los siguientes componentes de Azure:

- **Automation Account** con identidad administrada (System Assigned)
- **Automation Runbooks** PowerShell para start/stop de VMs
- **Automation Schedules** para ejecutar runbooks de forma programada
- **Action Group** para notificaciones por correo electrónico
- **Log Analytics Workspace** para centralizar logs
- **Monitor Scheduled Query Rules Alert V2** para detectar finalización de jobs
- **Virtual Network** y **Subnet** para conectividad privada
- **Private DNS Zone** para resolución DNS privada del Automation Account
- **Role Assignments** necesarios para permisos de la identidad administrada

### Diagrama de Arquitectura

```mermaid
graph TB
    subgraph "Recursos de Red"
        VNET[Virtual Network<br/>10.248.4.0/24]
        SUBNET[Subnet<br/>subnet-lab-01]
        PDNS[Private DNS Zone<br/>privatelink.azure-automation.net]
        PE[Private Endpoint<br/>Automation Account]
    end

    subgraph "Automation"
        AA[Automation Account<br/>aa-prod<br/>System Assigned Identity]
        RB_START[Runbook: vm-start.ps1<br/>PowerShell]
        RB_STOP[Runbook: vm-stop.ps1<br/>PowerShell]
        SCH_START[Schedule: Start<br/>Daily 08:00 AM]
        SCH_STOP[Schedule: Stop<br/>Daily 05:00 PM]
        VAR[Variable: ACTION_GROUP_ID]
    end

    subgraph "Monitorización"
        LAW[Log Analytics Workspace<br/>law-lab-01]
        AG[Action Group<br/>ag-vm-tag-email-lab-01]
        ALERT[Scheduled Query Alert<br/>automation-runbook-finished]
    end

    subgraph "Máquinas Virtuales Target"
        VM1[VM 1<br/>tag: environment=pre]
        VM2[VM 2<br/>tag: environment=pre]
        VM3[VM 3<br/>tag: environment=pre]
    end

    subgraph "Permisos RBAC"
        RBAC1[Virtual Machine Contributor<br/>sobre RG de VMs]
        RBAC2[Monitoring Contributor<br/>sobre RG Automation]
        RBAC3[Contributor<br/>sobre Action Group]
        RBAC4[Log Analytics Reader<br/>sobre LAW]
    end

    VNET --> SUBNET
    SUBNET --> PE
    PE --> AA
    PDNS -.DNS Resolution.-> PE
    
    SCH_START -->|Trigger| RB_START
    SCH_STOP -->|Trigger| RB_STOP
    
    AA --> RB_START
    AA --> RB_STOP
    AA --> VAR
    
    RB_START -->|Get-AzVM -Status| VM1
    RB_START -->|Get-AzVM -Status| VM2
    RB_START -->|Get-AzVM -Status| VM3
    
    RB_START -->|Start-AzVM| VM1
    RB_START -->|Start-AzVM| VM2
    RB_START -->|Start-AzVM| VM3
    
    RB_STOP -->|Stop-AzVM| VM1
    RB_STOP -->|Stop-AzVM| VM2
    RB_STOP -->|Stop-AzVM| VM3
    
    VAR -->|Action Group ID| RB_START
    VAR -->|Action Group ID| RB_STOP
    
    RB_START -->|Send Notification| AG
    RB_STOP -->|Send Notification| AG
    
    AG -->|Email| EMAIL[📧 ops@domain.com]
    
    AA -->|Logs| LAW
    RB_START -->|Execution Logs| LAW
    RB_STOP -->|Execution Logs| LAW
    
    LAW --> ALERT
    ALERT -->|Trigger on Job Finish| AG
    
    AA -.Identity.-> RBAC1
    AA -.Identity.-> RBAC2
    AA -.Identity.-> RBAC3
    AA -.Identity.-> RBAC4
    
    RBAC1 -.Allows.-> VM1
    RBAC1 -.Allows.-> VM2
    RBAC1 -.Allows.-> VM3
    RBAC2 -.Allows.-> LAW
    RBAC3 -.Allows.-> AG
    RBAC4 -.Allows.-> LAW

    style AA fill:#0078D4,stroke:#005A9E,color:#fff
    style RB_START fill:#50E6FF,stroke:#0078D4,color:#000
    style RB_STOP fill:#50E6FF,stroke:#0078D4,color:#000
    style LAW fill:#FFA500,stroke:#FF8C00,color:#000
    style AG fill:#FFD700,stroke:#FFA500,color:#000
    style VM1 fill:#90EE90,stroke:#32CD32,color:#000
    style VM2 fill:#90EE90,stroke:#32CD32,color:#000
    style VM3 fill:#90EE90,stroke:#32CD32,color:#000
    style EMAIL fill:#FFB6C1,stroke:#FF69B4,color:#000
```

### Diagrama de Flujo de Ejecución

```mermaid
sequenceDiagram
    participant SCH as Automation Schedule<br/>(08:00 AM)
    participant RB as Runbook<br/>(vm-start.ps1)
    participant AAI as Automation Account<br/>Identity
    participant AZURE as Azure Resource Manager
    participant VM as Virtual Machines<br/>(tag: environment=pre)
    participant AG as Action Group
    participant EMAIL as Email Recipients

    Note over SCH,RB: Trigger diario programado
    SCH->>RB: Ejecutar runbook
    
    activate RB
    RB->>AAI: Connect-AzAccount -Identity
    AAI-->>RB: Token de autenticación
    
    RB->>AZURE: Get-AzVM -Status
    AZURE-->>RB: Lista de todas las VMs
    
    Note over RB: Filtrar VMs con tag<br/>environment=pre
    
    RB->>RB: Procesar lista de VMs objetivo
    
    loop Para cada VM con el tag
        RB->>VM: Verificar PowerState
        VM-->>RB: Estado actual (running/stopped/deallocated)
        
        alt VM no está running
            RB->>VM: Start-AzVM
            VM-->>RB: Operación iniciada
        else VM ya está running
            RB->>RB: Skip (ya está encendida)
        end
    end
    
    Note over RB: Esperar 60 segundos
    RB->>RB: Start-Sleep -Seconds 60
    
    RB->>AZURE: Get-AzVM -Status (verificación)
    AZURE-->>RB: Estados actualizados
    
    RB->>RB: Construir resumen:<br/>- VMs running<br/>- VMs no running<br/>- Errores
    
    RB->>AAI: Get-AutomationVariable<br/>"ACTION_GROUP_ID"
    AAI-->>RB: Action Group ID
    
    RB->>AAI: Get-AzAccessToken
    AAI-->>RB: Access Token
    
    RB->>AG: POST /createNotifications<br/>Resumen de ejecución
    AG->>EMAIL: Enviar notificación por correo
    
    EMAIL-->>AG: Email entregado
    AG-->>RB: Notificación enviada
    
    deactivate RB
    
    Note over EMAIL: 📧 Correo recibido con:<br/>- VMs encendidas<br/>- VMs que no se encendieron<br/>- Errores (si los hay)
```

### Diagrama de Estados de VM

```mermaid
stateDiagram-v2
    [*] --> Verificando
    
    state "Schedule Trigger (08:00 AM)" as Verificando
    state "VM Running" as Running
    state "VM Stopped" as Stopped  
    state "VM Deallocated" as Deallocated
    state "Skip VM" as SkipVM
    state "Iniciando VM" as Iniciando
    state "Esperando 60s" as Esperando
    state "Verificar Estado" as VerificarEstado
    state "Error al Iniciar" as Error
    state "Notificar Resultados" as Notificar
    state "Enviar Email" as EnviarEmail
    
    Verificando --> Running: VM ya encendida
    Verificando --> Stopped: VM detenida
    Verificando --> Deallocated: VM deallocated
    
    Running --> SkipVM: No requiere acción
    
    Stopped --> Iniciando: Start-AzVM ejecutado
    Deallocated --> Iniciando: Start-AzVM ejecutado
    
    Iniciando --> Esperando: Esperar confirmación
    
    Esperando --> VerificarEstado: Re-verificar estado
    
    VerificarEstado --> Running: VM encendida exitosamente
    VerificarEstado --> Error: VM no pudo encenderse
    
    Running --> Notificar: Agregar a lista Running
    Error --> Notificar: Agregar a lista Errores
    SkipVM --> Notificar: Agregar a lista Running
    
    Notificar --> EnviarEmail: Action Group envía resumen
    
    EnviarEmail --> [*]: Proceso completado
    
    note right of Verificando
        Filtrar VMs con
        tag environment=pre
    end note
    
    note right of Iniciando
        Operación asíncrona
        Azure inicia el proceso
    end note
    
    note right of EnviarEmail
        Email incluye:
        VMs running
        VMs no running
        Detalles de errores
    end note
```

## Requisitos Previos

- **Terraform** >= 1.0
- **Azure CLI** configurado con permisos adecuados
- **Proveedor azurerm** 4.57.0
- Una **suscripción de Azure** activa
- Permisos para crear recursos en la suscripción

## Variables Principales

### Resource Group
```hcl
rg = {
  rg1 = {
    resource_group_name = "rg-lab-01"
    location            = "spaincentral"
  }
}
```

### Automation Account
```hcl
automation_accounts = {
  aa-prod = {
    automation_account_name       = "aa-prod"
    resource_group_name           = "rg-lab-01"
    location                      = "spaincentral"
    sku_name                      = "Basic"
    identity_type                 = "SystemAssigned"
    public_network_access_enabled = false
    private_dns_zone_ids          = "privatelink.azure-automation.net"
    subnet                        = "subnet-lab-01"
  }
}
```

### Automation Runbooks
```hcl
automation_runbooks = {
  rb_vm_start = {
    resource_group_name     = "rg-lab-01"
    location                = "spaincentral"
    automation_account_name = "aa-prod"
    runbook_type            = "PowerShell"
    script_path             = "runbooks/vm-start.ps1"
    description             = "Arranque de VMs"
  }
  rb_vm_stop = {
    resource_group_name     = "rg-lab-01"
    location                = "spaincentral"
    automation_account_name = "aa-prod"
    runbook_type            = "PowerShell"
    script_path             = "runbooks/vm-stop.ps1"
    description             = "Parada de VMs"
  }
}
```

### Automation Schedules
```hcl
automation_schedule = {
  sch_vm_start_pre_0800 = {
    name                    = "sch-vm-start-daily-0800"
    resource_group_name     = "rg-lab-01"
    automation_account_name = "aa-prod"
    frequency               = "Day"
    interval                = 1
    vm_start_schedule_start_time  = "2026-01-15T08:00:00+01:00"
    vm_start_schedule_timezone    = "Europe/Madrid"
    runbook_name            = "rb_vm_start"
    tag_key                 = "environment"
    tag_value               = "pre"
  }
}
```

### Role Assignments
```hcl
role_assignments = {
  ra1 = {
    scope                   = "/subscriptions/{sub-id}/resourceGroups/rg-vms"
    role_definition_name    = "Virtual Machine Contributor"
    automation_account_name = "aa-prod"
  }
  ra2 = {
    scope                   = "/subscriptions/{sub-id}/resourceGroups/rg-lab-01"
    role_definition_name    = "Monitoring Contributor"
    automation_account_name = "aa-prod"
  }
  ra3 = {
    scope                   = "/subscriptions/{sub-id}/resourceGroups/rg-lab-01/providers/Microsoft.Insights/actionGroups/ag-vm-tag-email-lab-01"
    role_definition_name    = "Contributor"
    automation_account_name = "aa-prod"
  }
  ra_law_reader = {
    scope                   = "/subscriptions/{sub-id}/resourceGroups/rg-lab-01/providers/Microsoft.OperationalInsights/workspaces/law-lab-01"
    role_definition_name    = "Log Analytics Reader"
    automation_account_name = "aa-prod"
  }
}
```

### Monitor Action Group
```hcl
monitor_action_group = {
  ag_lab_email = {
    name                            = "ag-vm-tag-email-lab-01"
    resource_group_name             = "rg-lab-01"
    short_name                      = "aglabemail"
    email_receiver_name             = "ops"
    email_receiver_email_address    = "usuario@dominio.com"
    automation_account_name         = "aa-prod"
  }
}
```

### Log Analytics
```hcl
log_analytics = {
  log1 = {
    name                    = "law-lab-01"
    location                = "spaincentral"
    resource_group_name     = "rg-lab-01"
    sku                     = "PerGB2018"
    retention_in_days       = "30"
    automation_account_name = "aa-prod"
  }
}
```

### Monitor Scheduled Query Rules Alert
```hcl
monitor_scheduled_query_rules_alert_v2 = {
  alert_automation_job_finished = {
    name                                        = "automation-runbook-finished"
    resource_group_name                         = "rg-lab-01"
    location                                    = "spaincentral"
    law_id                                      = "law-lab-01"
    severity                                    = 4
    evaluation_frequency                        = "PT5M"
    window_duration                             = "PT5M"
    time_aggregation_method                     = "Count"
    operator                                    = "GreaterThan"
    threshold                                   = 0
    minimum_failing_periods_to_trigger_alert    = 1
    number_of_evaluation_periods                = 1
    action_group_id                             = "ag_lab_email"
  }
}
```

## Instalación y Uso

### 1. Clonar el repositorio
```bash
git clone https://github.com/luisadanmunoz/start-stop-VM-alarm.git
cd start-stop-VM-alarm
```

### 2. Configurar variables
Copia el archivo de ejemplo y ajusta los valores según tu entorno:

```bash
cp start-stop-VM-alarm.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` y configura:
- IDs de recursos (scopes) para role assignments
- Direcciones de correo electrónico para notificaciones
- Horarios de inicio/parada (en formato ISO8601)
- Tags para filtrar las VMs

### 3. Configurar backend (opcional)
Si usas un backend remoto en Azure Storage, configura el archivo `backend.conf`:

```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "sttfstate"
container_name       = "tfstate"
key                  = "start-stop-vm.tfstate"
```

### 4. Inicializar Terraform
```bash
terraform init -backend-config=backend.conf
```

### 5. Validar configuración
```bash
terraform validate
terraform plan
```

### 6. Desplegar infraestructura
```bash
terraform apply
```

### 7. Configurar variable en Automation Account
Después del despliegue, configura manualmente la variable `ACTION_GROUP_ID` en el Automation Account:

1. Ve al Automation Account en el portal de Azure
2. Navega a **Variables** en el menú lateral
3. Crea una nueva variable:
   - **Nombre**: `ACTION_GROUP_ID`
   - **Valor**: `/subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.Insights/actionGroups/{ag-name}`
   - **Tipo**: String
   - **Encriptada**: No

## Estructura de Archivos

```
.
├── automation_account.tf                     # Automation Account principal
├── automation_runbook.tf                     # Runbooks PowerShell
├── automation_schedule.tf                    # Programación de runbooks
├── log_analytics.tf                          # Log Analytics Workspace
├── monitor_action_group.tf                   # Action Group para emails
├── monitor_scheduled_query_rules_alert_v2.tf # Alertas de monitorización
├── private_dns_zone.tf                       # DNS privado
├── provider.tf                               # Providers y backend
├── rg.tf                                     # Resource Groups
├── role_assignment.tf                        # Asignaciones de roles
├── subnet.tf                                 # Subnets
├── variables.tf                              # Definición de variables
├── vnet.tf                                   # Virtual Networks
├── start-stop-VM-alarm.tfvars                # Valores de variables
├── runbooks/
│   ├── vm-start.ps1                          # Script PowerShell para iniciar VMs
│   └── vm-stop.ps1                           # Script PowerShell para detener VMs
└── README.md                                 # Este archivo
```

## Funcionamiento de los Runbooks

### vm-start.ps1
Runbook PowerShell que realiza las siguientes acciones:

1. Se conecta a Azure usando la identidad administrada del Automation Account
2. Busca todas las VMs que tengan un tag específico (por ejemplo, `environment=pre`)
3. Verifica el estado actual de cada VM
4. Intenta iniciar las VMs que estén detenidas
5. Espera 60 segundos para permitir que las VMs se inicien
6. Vuelve a verificar el estado de todas las VMs
7. Envía un correo electrónico mediante el Action Group con un resumen detallado:
   - VMs que quedaron en estado "Running"
   - VMs que no lograron iniciarse (con su estado actual)
   - Errores encontrados durante el proceso

**Parámetros del runbook:**
- `tagkey`: Clave del tag para filtrar VMs (default: "environment")
- `tagvalue`: Valor del tag para filtrar VMs (default: "pre")
- `subscriptionid`: ID de suscripción (opcional, usa la del contexto si no se especifica)
- `waitseconds`: Segundos a esperar antes del re-chequeo (default: 60)

### vm-stop.ps1
Runbook similar a vm-start.ps1 pero para detener VMs. Sigue el mismo flujo de trabajo pero ejecuta `Stop-AzVM` en lugar de `Start-AzVM`.

### Ejemplo de correo de notificación
```
Asunto: Resultado start VMs por tag (environment=pre)

Resumen:
- Running: vm-web-01, vm-app-01, vm-db-01
- No running: vm-test-01 [VM deallocated]
- Errores al solicitar start: (ninguno)
```

## Permisos Necesarios

La identidad administrada del Automation Account requiere los siguientes roles:

| Rol | Ámbito | Propósito |
|-----|--------|-----------|
| Virtual Machine Contributor | Resource Group de las VMs | Iniciar/detener VMs |
| Monitoring Contributor | Resource Group del Automation Account | Escribir logs y métricas |
| Contributor | Action Group específico | Enviar notificaciones |
| Log Analytics Reader | Log Analytics Workspace | Leer logs para alertas |

## Características de Seguridad

- **Red privada**: El Automation Account está configurado con `public_network_access_enabled = false`
- **Private Endpoint**: Acceso al Automation Account mediante Private Endpoint
- **Private DNS Zone**: Resolución DNS privada para `privatelink.azure-automation.net`
- **Identidad administrada**: Usa System Assigned Managed Identity sin necesidad de credenciales
- **Principio de mínimo privilegio**: Los role assignments están limitados a los ámbitos necesarios

## Monitorización y Alertas

### Log Analytics
Todos los logs de ejecución de los runbooks se envían automáticamente al Log Analytics Workspace configurado.

### Alertas Programadas
Se configura una alerta que se ejecuta cada 5 minutos para detectar cuando un runbook finaliza su ejecución. Esto permite:

- Detectar fallos en la ejecución
- Monitorizar tiempos de ejecución
- Tener visibilidad del estado general del sistema

### Notificaciones por Email
Cada ejecución de runbook envía un correo electrónico con:

- Estado final de cada VM objetivo
- Lista de VMs que se iniciaron/detuvieron correctamente
- Lista de VMs que no cambiaron de estado
- Detalles de errores si los hubiera

## Ejemplo de Uso

### Configurar inicio automático diario
Para configurar que las VMs con tag `environment=pre` se inicien todos los días a las 8:00 AM:

```hcl
automation_schedule = {
  sch_vm_start_pre_0800 = {
    name                              = "sch-vm-start-daily-0800"
    resource_group_name               = "rg-lab-01"
    automation_account_name           = "aa-prod"
    frequency                         = "Day"
    interval                          = 1
    vm_start_schedule_start_time      = "2026-01-15T08:00:00+01:00"
    vm_start_schedule_description     = "Arranca VMs con tag environment=pre"
    vm_start_schedule_timezone        = "Europe/Madrid"
    runbook_name                      = "rb_vm_start"
    tag_key                           = "environment"
    tag_value                         = "pre"
  }
}
```

### Configurar parada automática diaria
Para configurar que las mismas VMs se detengan todos los días a las 17:00 PM:

```hcl
automation_schedule = {
  sch_vm_stop_pre_1700 = {
    name                              = "sch-vm-stop-daily-1700"
    resource_group_name               = "rg-lab-01"
    automation_account_name           = "aa-prod"
    frequency                         = "Day"
    interval                          = 1
    vm_start_schedule_start_time      = "2026-01-15T17:00:00+01:00"
    vm_start_schedule_description     = "Para VMs con tag environment=pre"
    vm_start_schedule_timezone        = "Europe/Madrid"
    runbook_name                      = "rb_vm_stop"
    tag_key                           = "environment"
    tag_value                         = "pre"
  }
}
```

### Etiquetar VMs para automatización
Para que una VM sea gestionada por esta solución, simplemente añádele el tag correspondiente:

```bash
az vm update \
  --resource-group rg-vms-prod \
  --name vm-web-01 \
  --set tags.environment=pre
```

O mediante Terraform:

```hcl
resource "azurerm_virtual_machine" "example" {
  name                = "vm-web-01"
  resource_group_name = "rg-vms-prod"
  location            = "spaincentral"
  # ... otras configuraciones ...
  
  tags = {
    environment = "pre"
  }
}
```

## Solución de Problemas

### Los runbooks no se ejecutan
1. Verifica que los schedules tengan una fecha de inicio futura
2. Confirma que el runbook está publicado (estado "Published")
3. Revisa los logs en el Log Analytics Workspace

### Las VMs no se inician/detienen
1. Verifica que la identidad administrada tenga los permisos necesarios
2. Confirma que las VMs tengan el tag correcto configurado
3. Revisa los logs de ejecución del runbook en el Automation Account

### No llegan notificaciones por correo
1. Verifica que la variable `ACTION_GROUP_ID` esté configurada correctamente
2. Confirma que el email en el Action Group sea correcto
3. Revisa la bandeja de spam
4. Verifica que la identidad tenga permisos de "Contributor" sobre el Action Group

### Error de conexión al Automation Account
1. Verifica que el Private Endpoint esté correctamente configurado
2. Confirma que la Private DNS Zone esté vinculada a la VNet correcta
3. Verifica la resolución DNS desde la red privada

## Costos Estimados

Costos mensuales aproximados (región Spain Central):

- Automation Account (Basic): ~€0
- Ejecuciones de runbook: ~€0.002 por minuto de ejecución
- Log Analytics Workspace (PerGB2018): desde €2.76/GB ingerido
- Action Group: Primeras 1000 notificaciones gratis, luego ~€0.60/1000 emails
- Private Endpoint: ~€6.57/mes
- Virtual Network: Gratis

**Estimación total**: €10-20/mes para uso básico (2 ejecuciones diarias)

## Mejoras Futuras

- [ ] Añadir soporte para múltiples suscripciones
- [ ] Implementar retry logic para VMs que no cambien de estado
- [ ] Añadir dashboard en Azure Monitor con métricas clave
- [ ] Implementar webhook para notificaciones a Teams/Slack
- [ ] Añadir runbook para start/stop bajo demanda
- [ ] Implementar start/stop basado en condiciones (uso de CPU, costo)

## Contribución

Las contribuciones son bienvenidas. Por favor:

1. Haz fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commitea tus cambios (`git commit -am 'Añadir nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crea un Pull Request

## Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo `LICENSE` para más detalles.

## Autor

**Luis Adán Muñoz**
- GitHub: [@luisadanmunoz](https://github.com/luisadanmunoz)

## Agradecimientos

- Documentación oficial de Azure Automation
- Comunidad de Terraform
- Equipo de Azure

## Referencias

- [Azure Automation Documentation](https://docs.microsoft.com/en-us/azure/automation/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Monitor Action Groups](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups)
- [Log Analytics Workspaces](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)