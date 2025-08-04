###########
# Imports #
###########
#####################################################################
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\infogathering.ps1"
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\nsx-t.ps1"
#####################################################################

# Collects credentials, and makes the initial connection to Cloud Director
function vCDConnect{

    $global:username = Read-Host 'Please enter in your username'
    $password = Read-Host 'Please enter in your password' -AsSecureString 
    $global:convertedPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

    $location = parseData

    if($location.Location -eq "PHX"){
        Write-Host "Connecting to PHX Cloud Director..."
        Connect-CIServer <CLOUD DIRECTOR URL> -User $global:username -Password $global:convertedPw    
        orgCreation
    }
    elseif($location.Location -eq "ASH"){
        Write-Host "Connecting to ASH Cloud Director..."
        Connect-CIServer <CLOUD DIRECTOR URL> -User $global:username -Password $global:convertedPw    
        orgCreation
        
    }

}

# Creates the new Customer Organization
function orgCreation(){   
    
    $info = parseData 

    $newOrg = New-Org -Name $info.orgName -FullName $info.FullOrgName -Description $info.orgDesc
    $newOrg = Get-Org $info.orgName

    ################
    # ORG SETTINGS #
    ################    
    
    # Enables Subscribe to external catalogs
    $newOrg.ExtensionData.Settings.OrgGeneralSettings.CanSubscribe = $True
    $newOrg.ExtensionData.Settings.VAppLeaseSettings.StorageLeaseSeconds = 0
    $newOrg.ExtensionData.Settings.VAppLeaseSettings.DeploymentLeaseSeconds = 0
    $newOrg.ExtensionData.Settings.VAppTemplateLeaseSettings.StorageLeaseSeconds = 0
    $newOrg.ExtensionData.Settings.OrgPasswordPolicySettings.InvalidLoginsBeforeLockout = 6
    $newOrg.ExtensionData.Settings.OrgPasswordPolicySettings.AccountLockoutIntervalMinutes = 15
    $newOrg.ExtensionData.Settings.UpdateServerData()

    #metadata
    $metadata = $newOrg.ExtensionData.GetMetadata()
    $metadata.MetadataEntry = New-Object VMware.VimAutomation.Cloud.Views.MetadataEntry
    $metadata.MetadataEntry[0].Key="Name"
    $metadata.MetadataEntry[0].TypedValue = New-Object VMware.VimAutomation.Cloud.Views.MetadataStringValue
    $metadata.MetadataEntry[0].TypedValue.Value = $info.orgName
    $newOrg.ExtensionData.CreateMetadata($metadata)

    $metadata = $newOrg.ExtensionData.GetMetadata()
    $metadata.MetadataEntry = New-Object VMware.VimAutomation.Cloud.Views.MetadataEntry
    $metadata.MetadataEntry[0].Key="Client ID"
    $metadata.MetadataEntry[0].TypedValue = New-Object VMware.VimAutomation.Cloud.Views.MetadataStringValue
    $metadata.MetadataEntry[0].TypedValue.Value = $info.CID
    $newOrg.ExtensionData.CreateMetadata($metadata)

    createOrgVDC
}  

# Creates the new Customer Organization vDC
function createOrgVDC {

    $info = parseData 

    $convRAM = $([int]$info.RAM * 1024)
    $convCPU = $([int]$info.CPU * 1000) * 2

    if($info.Location -eq "PHX"){

        if($info.IsVCCR -eq "Y"){

            $pvdc = (Get-ProviderVDC -Name "<PROVIDER VDC>")
            $selectedPool = Get-NetworkPool -Name "<NETWORK POOL NAME>"

        }

        else{

            $pvdc = (Get-ProviderVDC -Name "<PROVIDER VDC>")
            $selectedPool = Get-NetworkPool -Name "<NETWORK POOL NAME>"
        
        }

    }
    else{

        if($info.IsVCCR -eq "Y"){

            $pvdc = (Get-ProviderVDC -Name "<PROVIDER VDC>")
            $selectedPool = Get-NetworkPool -Name "<NETWORK POOL NAME>"
        }

        else{

            $pvdc = (Get-ProviderVDC -Name "<PROVIDER VDC>")
            $selectedPool = Get-NetworkPool -Name "<NETWORK POOL NAME>"

        }

    }

    $storageProfileName = $pvdc.StorageProfiles | Where-Object { $_.Name -eq $info.StoragePolicy }
    
    $vdc = New-OrgVDC -Name "$($info.OrgName)_VDC" -Description $info.orgDesc -AllocationModelPayAsYouGo -Org $info.OrgName -ProviderVdc $pvdc `
     -VMCpuCoreMHz 2000 -StorageAllocationGB $info.Storage -StorageProfile $storageProfileName

    $vdc = Get-OrgVdc -Name "$($info.OrgName)_VDC"

    ################
    # VDC Settings #
    ################

    $ext = $vdc.ExtensionData

    $vdc.ExtensionData.IsThinProvision = $True
    $vdc.ExtensionData.ComputeCapacity.Cpu.Limit = $convCPU
    $vdc.ExtensionData.ResourceGuaranteedCpu = 0
    $vdc.ExtensionData.ComputeCapacity.Memory.Limit = $convRAM
    $vdc.ExtensionData.ResourceGuaranteedMemory = 0
    $vdc.ExtensionData.VmQuota = $null

    $ext.NetworkPoolReference = New-Object VMware.VimAutomation.Cloud.Views.Reference
    $ext.NetworkPoolReference.href = $selectedPool.ExtensionData.href
    $ext.NetworkPoolReference.name = $selectedPool.Name
    $ext.NetworkPoolReference.type = "application/vnd.vmware.vcloud.networkPool+xml"
    $ext.UpdateServerData()


    createUser
}

# vSphere Connection
function vSphereConn(){ 
    
    $info = parseData 
    
    if($info.location -eq 'PHX'){
        Write-Host 'Connecting to PHX vSphere...'
        Connect-VIServer <VCENTER URL> -User <DOMAIN>\$global:username -Password $global:convertedPw | Out-Null

    }
    elseif($info.location -eq 'ASH'){
        Write-Host 'Connecting to ASH vSphere...'
        Connect-VIServer <VCENTER URL>  -User <DOMAIN>\$global:username -Password $global:convertedPw | Out-Null
        
    }
    else{
        Write-Host 'There has been an issue with the vSphere location'
        vSphereConn
    }
}

# Creates and Tags the Resource Pool in vSphere
function tagResourcePool{

    $info = parseData

    $rp = Get-ResourcePool -Name "*$($info.orgName)*"

    $category = Get-TagCategory -Name "Client ID - Resource Pool" -ErrorAction SilentlyContinue

    if (-not $category) {
        $category = New-TagCategory -Name "Client ID - Resource Pool" -Cardinality Single -EntityType ResourcePool
    }

    $tag = Get-Tag -Name "$($info.CID)" -ErrorAction SilentlyContinue
    if (-not $tag) {
        $tag = New-Tag -Name "$($info.CID)" -Category $category -Description $($info.FullOrgName)
    }

    
    New-TagAssignment -Tag $tag -Entity $rp | Out-Null
    Start-Sleep 5
    Write-Host "vSphere VDC Tags Applied"


}

# API Authentication
function apiAuth {

    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$global:username@system:$global:convertedPw"))

    $headers = @{
        "Accept" = "application/json;version=38.1"
        "Authorization" = "Basic $Base64AuthInfo"
    }

    $AuthUrl = "<PROVIDER API URL>"

    $AuthResponse = Invoke-WebRequest -Uri $AuthUrl -Method Post -Headers $headers -UseBasicParsing

    # Extract JWT token from headers
    $global:JWT_Token = $AuthResponse.Headers["X-VMWARE-VCLOUD-ACCESS-TOKEN"] 

    # Verify if token is received
    if (-not $global:JWT_Token) {
        Write-Host "ERROR: JWT Token is blank!"
        exit
    }


}

# Creates the Administrator account for the Org
function createUser(){

    Clear-Host

   $newUser = New-Object -TypeName VMware.VimAutomation.Cloud.Views.User

   $newUser.Name = Read-Host 'Please enter in the Org Admin Name '
   $newUser.Password = & passwordGen
   $newUser.IsEnabled = $true

   $role = $newOrg.ExtensionData.RoleReferences.RoleReference | Where-Object -FilterScript { $_.Name -eq "Organization Administrator" }

   $newuser.Role = $role

   $newOrg.ExtensionData.CreateUser($newUser)

   # Directory Path will need to change once this is released
   $filePath = "<YOUR DIR LOCATION>\vCD-NSX\Modules\creds.txt"
   Clear-Content -Path $filePath
   $newUser.Name, $newUser.Password | Add-Content -Path $filePath

   Write-Host "Please copy out the credentials at $($filePath) and store in KeePass"

   while ($true) {
    $response = Read-Host "Have you copied the credentials to KeePass? (y/n)"
    
    if ($response -match '^(yes|y)$') {
        Write-Host 'Purging credentials file...'
        Clear-Content -Path $filePath
        Start-Sleep 2
        Write-Host 'Purged...'
        Clear-Host
        break
        } 
    else {
        Write-Host "Please copy them into KeePass..."
        }
    }

}

# Creates the password, and once created stores it in a local file to be stored in KeePass
function passwordGen(){

    $numbers = (65..90)
    $lower_chars = (97..122)
    $upper_chars =  (48..57)
    $special_chars = (33..47)

    $random_password = -join ($numbers + $lower_chars + $upper_chars + $special_chars | Get-Random -Count 25 | ForEach-Object {[char]$_})
    return $random_password

}

# Creates the Public IP Space
function createIpSpace {

    $authHeader = @{
        "Authorization" = "Bearer $global:JWT_Token"
        "Accept" = "application/json;version=38.1"
        "Content-Type"  = "application/json"
    }

    $info = parseData
    $prefix = $info.Location -replace ".$", "DSC"

    if($($info.location -eq "PHX")){
       $loc = "phx"
    }
    else{
        $loc = "ash"
    }

    $payload = @{
        name = "$prefix-$($info.orgName)_IPS_PUB"
        description = $($info.Desc)
        type = "PUBLIC"
        orgRef = $null
        utilization = @{
            floatingIPs = @{
                totalCount = 8
                allocatedCount = 6
                usedCount = 6
                unusedCount = 0
                allocatedPercentage = 75
                usedPercentage = 100
            }
            ipPrefixes = $null
        }
        ipSpaceRanges = @{
            ipRanges = @(
                @{
                    startIpAddress = $($info.FirstUsable)
                    endIpAddress   = $($info.LastUsable)
                    totalIpCount = 8
                    allocatedIpCount = 6
                    allocatedIpPercentage = 100
                }
            )
            defaultFloatingIpQuota = -1
        }
        ipSpacePrefixes = @()
        ipSpaceInternalScope = @($($info.Network))
        ipSpaceExternalScope = "0.0.0.0/0"
        routeAdvertisementEnabled = $true
        defaultGatewayServiceConfig = @{
            enableDefaultSnatRuleCreation = $false
            enableDefaultNoSnatRuleCreation = $false
            enableDefaultFirewallRuleCreation = $false
        }

        
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Method POST -Uri "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/ipSpaces" `
            -Headers $authHeader -Body $payload -ContentType "application/json"
    
        Write-Host "IP Space created:"
        return $response
    }
    catch {
        Write-Host "Request failed with 400 error"
    
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Server response: $errorBody"
        }
        else {
            Write-Host "Exception: $($_.Exception.Message)"
        }
    }

}

# Creates the Provider Gateway
function createNetwork{

    Write-Host "Creating Provider Gateway..."

    $authHeader = @{
        "Authorization" = "Bearer $global:JWT_Token"
        "Accept" = "application/json;version=38.1"
        "Content-Type"  = "application/json"
    }

    $info = parseData
    $prefix = $info.Location -replace ".$", "<ENVIORNMENT MARKER>"

    $org = Get-Org $($info.orgName)
    $orgID = $org.id


    if($($info.location -eq "PHX")){
       $nsxt = "<NSXT MANAGER URL>"
       $nsxtId = "<NSX-T ID>"
       $nsxtParentName = "<NSX-T PARENT>"
       $backingId = "<BACKING ID>"
       $loc = "phx"
    }
    else{
        $nsxt = "<NSXT MANAGER URL>"
        $nsxtId = "<NSX-T ID>"
        $nsxtParentName = "<NSX-T PARENT>"
        $backingId = "<BACKING ID>"
        $loc = "ash"
    } 

    $payload = @{
    name         = "$prefix-$($info.orgName)_PGW"
    description  = $($info.Desc)
    usingIpSpace = $true
    dedicatedOrg = @{
        id = "$($orgID)"
        name = "$($info.orgName)"
    }
    subnets     = @{
        values = @(
            @{
                gateway     = $($info.FirstUsable)
                prefixLength = 29
                dnsSuffix    = ""
                dnsServer1   = ""
                dnsServer2   = ""
                ipRanges     = @{
                    values = @(
                        @{
                            startAddress = $($info.FirstUsable)
                            endAddress   = $($info.LastUsable)
                        }
                    )
                }
                enabled       = $true
                totalIpCount  = 5
                usedIpCount   = 5
            }
        )
    }
    status           = "REALIZED"
    networkBackings  = @{
        values = @(
            @{
                backingId         = "$($backingId)$($info.VLAN)"
                backingType       = "NSXT_VRF_TIER0"
                backingTypeValue  = "NSXT_VRF_TIER0"
                networkProvider   = @{
                    name = $nsxt
                    id   = "urn:vcloud:nsxtmanager:$($nsxtId)"
                }
                name              = "vcd-tier0-gateway-vrf-vlan$($info.VLAN)"
                isNsxTVlanSegment = $false
                parentTier0Ref    = @{
                    id   = $($nsxtId)
                    name = $($nsxtParentName)
                    type = $null
                }
            }
        )
    }
    totalIpCount       = 5
    usedIpCount        = 0
    dedicatedEdgeGateway = $null
    networkRouteAdvertisementIntention = $null
    natAndFirewallServiceIntention     = $null

    } | ConvertTo-Json -Depth 10

    

    try {
        $response = Invoke-RestMethod -Method POST -Uri "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/externalNetworks" `
            -Headers $authHeader -Body $payload -ContentType "application/json"
    
        Write-Host "Provider Gateway Created"

        Start-Sleep 30
        return $response
    }
    catch {
        Write-Host "Request failed with 400 error"
    
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Server response: $errorBody"
        }
        else {
            Write-Host "Exception: $($_.Exception.Message)"
        }
    }

}

# Retrieves the IP Space Uplink ID
function getIpSpaceUplinkID{

    $authHeader = @{
        "Accept" = "application/json;version=39.0"
        "Authorization" = "Bearer $global:JWT_Token"
    }

    $info = parseData
    $prefix = $info.Location -replace ".$", "<ENVIORNMENT MARKER>"

    if($($info.Location) -eq "PHX"){
        $loc = "phx"
    }
    else{
        $loc = "ash"
    }

    $page = 1
    $pageSize = 50
    $allResults = @()

    do {
        $pagedUrl = "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/ipSpaces/summaries?filter=name==$prefix-$($info.orgName)_IPS_PUB&page=$page&pageSize=$pageSize"
        $response = Invoke-RestMethod -Method GET -Uri $pagedUrl -Headers $authHeader

        if ($response.values) {
            $allResults += $response.values
        }

        $page++
    } 
    while ($response.values.Count -eq $pageSize)

    # Now search for your item
    $ipSpace = $allResults | Where-Object { $_.name -eq "$prefix-$($info.orgName)_IPS_PUB"}

    $global:ipSpaceID = $ipSpace.id


} 

# Links the IP Space to the Provider Gateway
function ipSpaceUplink{

    $authHeader = @{
        "Authorization" = "Bearer $global:JWT_Token"
        "Accept" = "application/json;version=38.1"
        "Content-Type"  = "application/json"
    }

    $info = parseData
    $prefix = $info.Location -replace ".$", "<ENVIRONMENT MARKER>"

     if($($info.Location -eq "PHX")){

        if($($info.IsVCCR -eq "Y")){
            $edgeClusterName = "<EDGE NODE NAME>"
            $edgeClusterId = "urn:vcloud:edgeCluster:<EDGE CLUSTER ID>"
            $loc = "phx"
        }
        else{
            $edgeClusterName = "$($edgeNode)"
            Write-Host $($edgeNode)
            if($($edgeNode -eq  "<EDGE NODE NAME>")){
                $edgeClusterId = "urn:vcloud:edgeCluster:<EDGE CLUSTER ID>"
            }
            else{
                $edgeClusterId = "urn:vcloud:edgeCluster:<EDGE CLUSTER ID>"
            }
            $loc = "phx"
        }
     }
     else{

        if($(info.IsVCCR -eq "Y")){
            $edgeClusterName = "<EDGE NODE NAME>"
            $edgeClusterId = "urn:vcloud:edgeCluster:<EDGE CLUSTER ID>"
            $loc = "ash"

        }
        else{
            $edgeClusterName = "<EDGE NODE NAME>"
            $edgeClusterId = "urn:vcloud:edgeCluster:<EDGE CLUSTER ID>"
            $loc = "ash"
            }
     }

    $payload = @{
        name =  "$prefix-$($info.orgName)_Internet"
        description = $info.Desc

        externalNetworkRef = @{
            name = "$prefix-$($info.orgName)_PGW"
            id = (Get-ExternalNetwork -Name "$prefix-$($info.orgName)_PGW").Id
        }
        ipSpaceRef = @{
            name = "$prefix-$($info.orgName)_IPS_PUB"
            id = "$($global:ipSpaceID)"
        }

    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Method POST -Uri "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/ipSpaceUplinks" `
            -Headers $authHeader -Body $payload -ContentType "application/json"
    
        Write-Host "IP Space Uplink Updated..."
        return $response
    }
    catch {
        Write-Host "Request failed with 400 error"
    
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Server response: $errorBody"
        }
        else {
            Write-Host "Exception: $($_.Exception.Message)"
        }
    }
    
     
}

# Creates the Edge Gateway
function createEdge {

    $info = parseData
    $prefix = $info.Location -replace ".$", "<ENVIORNMENT MARKER>"

    $edgeNode = getEdgeNode

    $VdcId = (Get-OrgVdc -Name "$($info.orgName)_VDC")
    $UplinkNetworkId = (Get-ExternalNetwork -Name "$prefix-$($info.orgName)_PGW")
    $UplinkNetworkName = "$prefix-$($info.orgName)_PGW"
    $Gateway = "$($info.FirstUsable)"
    $StartIP = "$($info.FirstUsable)"
    $EndIP = "$($info.LastUsable)"
    $PrefixLength = $($info.NetMask)
    $EdgeName = "$prefix-$($info.orgName)_Edge"
    $Description = "$($info.Desc)"


    if($($info.Location -eq "PHX")){
        $edgeClusterName = "${edgeNode}"
        $edgeClusterId = "urn:vcloud:edgeCluster:<URN ID>"
        $loc = "phx"
     }
     else{
        $edgeClusterName = "<EDGE CLUSTER NAME>"
        $edgeClusterId = "urn:vcloud:edgeCluster:<URN ID>"
        $loc = "ash"
     }
    

    $headers = @{
        "Authorization" = "Bearer $global:JWT_Token"
        "Accept"        = "application/json;version=39.0"
        "Content-Type"  = "application/json"
    }

    $payload = @{
        name        = $EdgeName
        description = $Description
        ownerRef    = @{
            id = "urn:vcloud:vdc:$($VdcId.id)"
        }
        edgeGatewayUplinks = @(
            @{
                uplinkId   = "urn:vcloud:network:$($UplinkNetworkId.id)"
                uplinkName = $UplinkNetworkName
                subnets    = @{
                    values = @(
                        @{
                            gateway       = $Gateway
                            prefixLength  = $PrefixLength
                            dnsSuffix     = ""
                            dnsServer1    = ""
                            dnsServer2    = ""
                            ipRanges      = @{
                                values = @(
                                    @{
                                        startAddress = $StartIP
                                        endAddress   = $EndIP
                                    }
                                )
                            }
                            enabled       = $true
                            totalIpCount  = 5
                            usedIpCount   = 0
                        }
                    )
                }
                dedicated = $false
            }  
        )
        
   edgeClusterConfig = @{
    primaryEdgeCluster = @{
        edgeClusterRef  = @{
            name = $($edgeClusterName)
             id =  $($edgeClusterId)

              }
                     }
             }
               
    } | ConvertTo-Json -Depth 10

    try {

        $response = Invoke-RestMethod -Method POST `
            -Uri "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/edgeGateways" `
            -Headers $headers `
            -Body $payload

        Write-Host "Edge Gateway created"
        return $response
    } catch {
        Write-Host "Error creating Edge Gateway"
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            Write-Host "Server response: $errorBody"
        } else {
            Write-Host "Exception: $($_.Exception.Message)"
        }
    }
}

