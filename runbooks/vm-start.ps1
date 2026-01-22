param(
  [string]$tagkey   = "environment",
  [string]$tagvalue = "pre",
  [string]$subscriptionid = "",
  [int]$waitseconds = 60
)

Connect-AzAccount -Identity | Out-Null

if ($subscriptionid -and $subscriptionid.Trim().Length -gt 0) {
  Set-AzContext -Subscription $subscriptionid | Out-Null
}

Write-Output "Buscando VMs con tag '$tagkey=$tagvalue'..."

# 1) Obtener targets
$vms = Get-AzVM -Status
$targets = $vms | Where-Object {
  $_.Tags.ContainsKey($tagkey) -and $_.Tags[$tagkey] -eq $tagvalue
}

# Cargar Action Group ID (para cualquier caso: sin targets, fallos, ok)
$actionGroupId = Get-AutomationVariable -Name "ACTION_GROUP_ID"
if (-not $actionGroupId) { throw "No existe la variable ACTION_GROUP_ID en el Automation Account." }

$uri = "https://management.azure.com${actionGroupId}/createNotifications?api-version=2021-09-01"
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token

function Send-ActionGroupMail([string]$subject, [string]$description, $contextObj) {
$payload = @{
  alertType = "activitylog"
  emailReceivers = @(
    @{
      name  = "ops"
      emailAddress = "luis.adanmunoz@evolutio.com"
      useCommonAlertSchema = $false
    }
  )
  # Puedes añadir más emails aquí
} | ConvertTo-Json -Depth 10

  Invoke-RestMethod -Method Post -Uri $uri `
    -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
    -Body $payload | Out-Null
}

if (-not $targets -or $targets.Count -eq 0) {
  Write-Output "No se encontraron VMs con tag '$tagkey=$tagvalue'."

  Send-ActionGroupMail `
    "AVISO: no hay VMs con tag ($tagkey=$tagvalue)" `
    "El runbook se ejecutó pero no encontró VMs con ese tag." `
    @{ tagKey = $tagkey; tagValue = $tagvalue; found = 0 }

  return
}

Write-Output ("Encontradas {0} VM(s)." -f $targets.Count)

# 2) Intentar arrancar y guardar errores
$startErrors = @()

foreach ($vm in $targets) {
  $rg   = $vm.ResourceGroupName
  $name = $vm.Name
  $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -First 1).DisplayStatus

  Write-Output "VM: $rg/$name -> Estado: $powerState"

  if ($powerState -eq "VM running") {
    Write-Output "  - Ya está arrancada. Skip."
    continue
  }

  try {
    Write-Output "  - Arrancando..."
    Start-AzVM -ResourceGroupName $rg -Name $name -ErrorAction Stop | Out-Null
    Write-Output "  - OK (start solicitado)"
  }
  catch {
    $msg = $_.Exception.Message
    Write-Output "  - ERROR arrancando $rg/$name : $msg"
    $startErrors += [PSCustomObject]@{ name = $name; resourceGroupName = $rg; error = $msg }
  }
}

Write-Output "Esperando $waitseconds segundos para re-chequeo..."
Start-Sleep -Seconds $waitseconds

# 3) Re-chequeo de estado de TODOS los targets
$after = Get-AzVM -Status | Where-Object {
  $_.Tags.ContainsKey($tagkey) -and $_.Tags[$tagkey] -eq $tagvalue
}

$running = @()
$notRunning = @()

foreach ($vm in $after) {
  $rg   = $vm.ResourceGroupName
  $name = $vm.Name
  $ps = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" } | Select-Object -First 1).DisplayStatus

  if ($ps -eq "VM running") {
    $running += [PSCustomObject]@{ name = $name; resourceGroupName = $rg }
  } else {
    $notRunning += [PSCustomObject]@{ name = $name; resourceGroupName = $rg; state = $ps }
  }
}

# 4) Construir resumen y enviar 1 correo con todo
$runningNames = if ($running.Count -gt 0) { ($running | ForEach-Object { $_.name }) -join ", " } else { "(ninguna)" }
$notRunningNames = if ($notRunning.Count -gt 0) { ($notRunning | ForEach-Object { "$($_.name) [$($_.state)]" }) -join ", " } else { "(ninguna)" }

$errText = "(ninguno)"
if ($startErrors.Count -gt 0) {
  $errText = ($startErrors | ForEach-Object { "$($_.name): $($_.error)" }) -join " | "
}

$subject = "Resultado start VMs por tag ($tagkey=$tagvalue)"
$desc = @"
Resumen:
- Running: $runningNames
- No running: $notRunningNames
- Errores al solicitar start: $errText
"@.Trim()

Send-ActionGroupMail $subject $desc @{
  tagKey      = $tagkey
  tagValue    = $tagvalue
  running     = $running
  notRunning  = $notRunning
  startErrors = $startErrors
}

Write-Output "Correo enviado. Proceso terminado."

