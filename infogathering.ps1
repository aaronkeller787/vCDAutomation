# Reads in the build data from the CSV
function parseData {

    $BuildArray = @()

    $filepath = "<YOUR DIR LOCATION>\vCD-NSX\Modules\information.csv"
    $data = Import-Csv -Path $filePath

    foreach ($d in $data) {
        $BuildData = [PSCustomObject]@{

            Location = $d.Location
            FullOrgName = $d.FullOrgName
            OrgName = $d.OrgName
            Desc = $d.Desc
            CID = $d.CID
            RAM = $d.RAM
            CPU = $d.CPU
            Storage = $d.Storage
            StoragePolicy = $d.StoragePolicy
            VLAN = $d.VLAN
            Network = $d.Network
            GatewayAddress = $d.GWAddress
            NetMask = $d.NetMask
            FirstUsable = $d.FirstUsable
            LastUsable = $d.LastUsable
            IsVCCR = $d.IsVCCR

        }
        $BuildArray += $BuildData
    }

    return $BuildArray

}
    
# Last verification check before provisioning
function verifyInfo {

    param(
        [array]$DataArray
    )
    
    foreach ($i in $DataArray){

        Clear-Host
        Write-Host "Please Validate the following before proceeding..."

        Write-Host "Location: $($i.Location)"
        Write-Host "Full Organization Name: $($i.FullOrgName)"
        Write-Host "Org Name: $($i.OrgName)"
        Write-Host "Description: $($i.Desc)"
        Write-Host "Customer Id: $($i.CID)"
        Write-Host "RAM: $($i.RAM)"
        Write-Host "CPU: $($i.CPU)"
        Write-Host "Storage: $($i.Storage)"
        Write-Host "Storage Policy: $($i.StoragePolicy)"
        Write-Host "VLAN: $($i.VLAN)"
        Write-Host "Network: $($i.Network)"
        Write-Host "Subnet Mask: $($i.NetMask)"
        Write-Host "Gateway Address: $($i.GatewayAddress)"
        Write-Host "First Usable IP: $($i.FirstUsable)"
        Write-Host "Last Usable IP: $($i.LastUsable)"
         Write-Host "VCCR Deployment: $($i.IsVCCR)"

        $response = Read-Host "Is the above correct? (Y/N)"

        if($response -like 'y'){
            
            vCDConnect
        }
        else{
            Write-Host "Please correct the spreadsheet and run this again"
        }

    }

}


