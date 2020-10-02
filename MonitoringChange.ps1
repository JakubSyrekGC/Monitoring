Import-Module SwisPowerShell

$password = ConvertTo-SecureString "$($ENV:SLW_PASSWORD)" -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential ("$ENV:SLW_USERNAME", $password)

$hostName = "$ENV:SLW_SERVER"
$swis = Connect-Swis -Credential $credentials -Hostname $hostName 
$global:appName = $ENV:SERVICE_NAME
$global:serverName = $ENV:SERVER_NAME
$start = (Get-Date).ToUniversalTime()
$end = $start.AddYears(5)
  

function checkStatus {
  param(
    [Parameter(Mandatory=$TRUE)] [ValidateNotNullOrEmpty()]
    [string]$serverName
  )
  $status = Get-SwisData $swis "select distinct a.Unmanaged as [IsApplicationUnManaged]
  from Orion.Nodes n
  join Orion.APM.Application a on a.NodeID = n.NodeID
  join Orion.APM.Component ac on ac.ApplicationID = a.ID
  join Orion.APM.ComponentTemplate ct ON ac.TemplateID = ct.ID
  join Orion.APM.ComponentTemplateSetting  cts ON ct.id = cts.ComponentTemplateID
  where n.Caption LIKE '$serverName%' and cts.Value LIKE '$global:appName%'"
  return $status
}

$appId = Get-SwisData $swis "select distinct a.ID as [ApplicationId]
  from Orion.Nodes n
  join Orion.APM.Application a on a.NodeID = n.NodeID
  join Orion.APM.Component ac on ac.ApplicationID = a.ID
  join Orion.APM.ComponentTemplate ct ON ac.TemplateID = ct.ID
  join Orion.APM.ComponentTemplateSetting  cts ON ct.id = cts.ComponentTemplateID
  where n.Caption LIKE '$serverName%' and cts.Value LIKE '$global:appName%'"

if ($appId -eq $NULL) {
  Write-Host "[ERROR] application $global:appName not assined to $global:serverName node"
} Else {
  switch -Exact ($ENV:ACTION) {
    'enable' {
      Invoke-SwisVerb $swis Orion.APM.Application Remanage -Arguments @( "AA:$appId" ) > $NULL
      If (checkStatus -serverName $global:serverName) {
        Write-Host "[ERROR] application $global:appName ID: $appId still UNMANAGED"
        #exit 1
      } Else {
        Write-Host "[INFO] application $global:appName ID: $appId on $global:serverName successfully REMANAGED"
      }
    }
    'disable' {
      Invoke-SwisVerb $swis Orion.APM.Application Unmanage -Arguments @( "AA:$appId", $start, $end, "false" ) > $NULL
      If (-Not (checkStatus -serverName $global:serverName)) {
        Write-Host "[ERROR] application $global:appName ID: $appId still MANAGED"
        #exit 1
      } Else {
        Write-Host "[INFO] application $global:appName ID: $appId on $global:serverName successfully UNMANAGED"
      }
    }
    'check' {
      # The boolean value that specifies if application is unmanaged.
      If (checkStatus -serverName $global:serverName) {
        Write-Host "[INFO] application $global:appName ID: $appId on $global:serverName is UNMANAGED"
      } Else {
        Write-Host "[INFO] application $global:appName ID: $appId on $global:serverName is MANAGED"
      }
    }
    Default {
      Write-Host "[ERROR] $ENV:ACTION action type not supported"
      exit 1
    }
  }
}