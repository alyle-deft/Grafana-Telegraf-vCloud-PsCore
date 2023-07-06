$ConfigFile = "$PSScriptRoot/Config.json"
$Configs = Get-Content -Raw -Path $ConfigFile -ErrorAction Continue | ConvertFrom-Json -ErrorAction Continue

if (!($Configs)) {
    Throw "Import JSON Config Failed"
    }

$VcdHost = $Configs.Base.VcdHost
$BasicAuth = $Configs.Base.BasicAuth

#region: Login
$Uri = "https://$VcdHost/cloudapi/1.0.0/sessions/provider"
$Authorization = 'Basic {0}' -f $BasicAuth
$Headers =  @{'accept' = 'application/json;version=37.0.0-alpha'; 'Authorization' = $Authorization}
$ResponseHeaders = $null
try {
    $Login = Invoke-RestMethod -uri $Uri -Method Post -Headers $Headers -ResponseHeadersVariable 'ResponseHeaders'
}
catch {
    Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
    Exit
}
#endregion

#region: Cleanup Confidential Data
Clear-Variable -Name BasicAuth, Authorization, Headers, Uri
#endregion

#region: Get vOrgs
$Uri = "https://$VcdHost/api/query?type=adminOrgVdc&pageSize=10"
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
[XML]$orgVdcs = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers -FollowRelLink -MaximumFollowRelLink 2
#endregion

#region: Get vApps
$Uri = "https://$VcdHost/api/query?type=adminVApp&pageSize=10"
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
[XML]$vApps = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get VMs
$Uri = "https://$VcdHost/api/query?type=adminVM&pageSize=10"
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
[XML]$VMs = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get orgNetworks
$Uri = "https://$VcdHost/api/query?type=orgVdcNetwork&pageSize=10"
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
[XML]$orgNetworks = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

#region: Get edgeGateway
$Uri = "https://$VcdHost/api/query?type=edgeGateway&pageSize=10"
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
[XML]$edgeGateways = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
#endregion

## region: Output
# Simple Stats
# vOrg count
$orgVdcsTotal = $orgVdcs.QueryResultRecords.total
$body="vCloudStats orgVdcCountTotal=$orgVdcsTotal"
Write-Host $body
# vApp count
$vAppsTotal = $vApps.QueryResultRecords.total
$body="vCloudStats vAppCountTotal=$vAppsTotal"
Write-Host $body
# VMs count
$VMsTotal = ([Array]$VMs.QueryResultRecords.AdminVMRecord | Where-Object {$_.isVAppTemplate -ne "true"}).Count
$body="vCloudStats VMCountTotal=$VMsTotal"
Write-Host $body
# VMs Powered off Count
$VMsPoweredOff = ([Array]$VMs.QueryResultRecords.AdminVMRecord | Where-Object {$_.isVAppTemplate -ne "true" -and  $_.status -eq "POWERED_OFF"}).Count
$body="vCloudStats VMCountPoweredOff=$VMsPoweredOff"
Write-Host $body
# OrgNetworks count
$orgNetworksTotal = $orgNetworks.QueryResultRecords.total
$body="vCloudStats orgNetworkCountTotal=$orgNetworksTotal"
Write-Host $body
# edgeGateways count
$edgeGatewaysTotal = ([Array]$edgeGateways.QueryResultRecords.EdgeGatewayRecord).Count
$body="vCloudStats edgeGatewaysTotal=$edgeGatewaysTotal"
Write-Host $body

# Details stats
# OrgVdc Details
foreach ($item in [Array]$orgVdcs.QueryResultRecords.AdminVdcRecord) {
    $body = "vCloudStats,orgVdc=$($item.name  -replace ' ','\ '),isEnabled=$($item.isEnabled) cpuUsedMhz=$($item.cpuUsedMhz),memoryUsedMB=$($item.memoryUsedMB),numberOfMedia=$($item.numberOfMedia),numberOfVAppTemplates=$($item.numberOfVAppTemplates),numberOfVApps=$($item.numberOfVApps),storageUsedMB=$($item.storageUsedMB)"
        Write-Host $body
}
# vApp Details
foreach ($item in [Array]$vApps.QueryResultRecords.AdminVAppRecord | Where-Object {$_.status -ne "RESOLVED"}) {
    $body = "vCloudStats,vApp=$($item.name  -replace ' ','\ '),status=$($item.status) numberOfVMs=$($item.numberOfVMs),cpuAllocationInMhz=$($item.cpuAllocationInMhz),storageKB=$($item.storageKB)"
        Write-Host $body
}
# orgNetwork Details
foreach ($item in [Array]$orgNetworks.QueryResultRecords.OrgVdcNetworkRecord) {
    $Uri = [string]$item.href + "/allocatedAddresses"
    $Headers =  @{'accept' = 'application/*;version=32.0'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
    [XML]$orgNetworkAllocated = Invoke-RestMethod -uri $Uri -Method Get -Headers $Headers
    $AllocatedIpAddressesTotal = $orgNetworkAllocated.AllocatedIpAddresses.IpAddress.Count
    $body = "vCloudStats,orgNetwork=$($item.name  -replace ' ','\ '),gateway=$($item.defaultGateway) AllocatedIpAddressesTotal=$AllocatedIpAddressesTotal"
        Write-Host $body
}
# Edge Details
foreach ($item in [Array]$edgeGateways.QueryResultRecords.EdgeGatewayRecord) {
    $body = "vCloudStats,edgeGateway=$($item.name  -replace ' ','\ '),gatewayStatus=$($item.gatewayStatus),haStatus=$($item.haStatus) numberOfExtNetworks=$($item.numberOfExtNetworks),numberOfOrgNetworks=$($item.numberOfOrgNetworks)"
        Write-Host $body
}
#endregion

#region: Logout
$Uri = "https://$VcdHost/api/session"
#$Headers =  @{'accept' = 'application/vnd.vmware.vcloud.session+xml;version=27.0'; 'x-vcloud-authorization' = [String]$ResponseHeaders.'x-vcloud-authorization'}
$Headers =  @{'accept' = 'application/*;version=32.0'; 'content-type' = 'application/vnd.vmware.admin.vcloud+xml'; 'Authorization' = 'Bearer {0}' -f [String]$ResponseHeaders.'x-vmware-vcloud-access-token'}
$Logout = Invoke-RestMethod -uri $Uri -Method Delete -Headers $Headers
#endregion

#region: Cleanup Confidential Data
Clear-Variable -Name ResponseHeaders, Headers
#endregion
