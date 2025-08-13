. "<YOUR DIR LOCATION>\vCD-NSX\Modules\infogathering.ps1"

function createByof {

    $info = parseData

    $pair = "${global:username}@<DOMAIN>:${global:convertedPw}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
    $encodedCreds = [System.Convert]::ToBase64String($bytes)

    $headers = @{
        "Authorization" = "Basic $encodedCreds"
        "Content-Type"  = "application/json"
    }

    if($info.Location -eq "PHX"){
        $nsxtManager = "<NSXT MANAGER URL>"
        if($info.IsVCCR -eq "Y"){
            $transportZonePath = "/infra/sites/default/enforcement-points/default/transport-zones/<TRANSPORT ZONE ID>"
        } else {
            $transportZonePath = "/infra/sites/default/enforcement-points/default/transport-zones/<TRANSPORT ZONE ID>"
        }
    } else {
        $nsxtManager = "<NSXT MANAGER URL>"
        if($info.IsVCCR -eq "Y"){
            $transportZonePath = "/infra/sites/default/enforcement-points/default/transport-zones/<TRANSPORT ZONE ID>"
        } else {
            $transportZonePath = "/infra/sites/default/enforcement-points/default/transport-zones/<TRANSPORT ZONE ID>"
        }
    }

    $payload = @{
        resource_type = "Segment"
        display_name = "$($info.CID)-$($info.OrgName)_$($info.VLAN)"
        subnets = @(@{ gateway_address = "$($info.GatewayAddress)/$($info.NetMask)" })
        replication_mode = "MTEP"
        transport_zone_path = $transportZonePath
        vlan_ids = @([string]$info.VLAN)
        admin_state = "UP"
        tags = @(@{tag = $info.VLAN})
        description = $info.Desc
        advanced_config = @{
            address_pool_paths = @()
            connectivity = "ON"
        }
        id = "$($info.CID)-$($info.OrgName)_$($info.VLAN)"
    }

    $endpoint = "$($nsxtManager)/policy/api/v1/infra/segments/$($info.OrgName)"

    $payloadJson = $payload | ConvertTo-Json -Depth 10 -Compress

    # Use Invoke-WebRequest to capture HTTP status and response
    $response = Invoke-WebRequest -Method Put -Uri $Endpoint -Headers $headers -Body $payloadJson -UseBasicParsing

    # Assign the NSX-T segment UUID to the global variable
    $global:newSegmentId = ($response.Content | ConvertFrom-Json).unique_id
    Write-Host "NSX-T Segment created with UUID: $global:newSegmentId"

    Write-Host "Full Response:"
    $response.Content | Write-Host
}

function assignDirectNetwork {

    $info = parseData

    $Endpoint = "<CLOUD DIRECTOR URL>/cloudapi/1.0.0/orgVdcNetworks"

    $headers = @{
        "Authorization" = "Bearer $global:JWT_Token"
        "Content-Type"  = "application/json"
        "Accept" = "application/json;version=39.0"
    }

    if($info.IsVCCR -eq "Y") {
        $name = "$($info.OrgName)_DR-VDC"
    }
    else {
        $name = "$($info.OrgName)_VDC"
    }

    $getVdcID = Get-OrgVdc $name
    Write-Host "OrgVDC ID: $($getVdcID.Id)"

    $payload = @{
        ownerRef = @{
            id   = $getVdcID.Id
            name = $name
        }
        name                     = "$($info.CID)-$($info.OrgName)_$($info.VLAN)-Direct"
        description              = $info.Desc
        networkType              = "OPAQUE"
        strictIpMode             = $false
        subnets = @{
            values = @(
                @{
                    gateway      = $info.GatewayAddress
                    prefixLength = [int]$info.NetMask
                    dnsServer1   = ""
                    dnsServer2   = ""
                    dnsSuffix    = ""
                    ipRanges = @{
                        values = @(
                            @{
                                startAddress = $info.FirstUsable
                                endAddress   = $info.LastUsable
                            }
                        )
                    }
                }
            )
        }
        enableDualSubnetNetwork  = $false
        backingNetworkId         = $global:newSegmentId
        backingNetworkType       = "IMPORTED_T_LOGICAL_SWITCH"
        segmentProfileTemplateRef = $null
    }

    $PayloadJson = $payload | ConvertTo-Json -Depth 10 -Compress

    try {
        $response = Invoke-RestMethod -Method Post -Uri $Endpoint -Headers $headers -Body $PayloadJson -UseBasicParsing

        Write-Host "Direct Network Created Successfully."
        Write-Host "Response:"
        $response | ConvertTo-Json -Depth 10 | Write-Host
    }
    catch {
        Write-Host "Error creating Direct Network:"
        Write-Host $_.Exception.Message
        if ($_.Exception.Response) {
            $respStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($respStream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response body:`n$responseBody"
        }
    }
}
