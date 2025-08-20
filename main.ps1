###########
# Imports #
###########
#####################################################################
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\infoGathering.ps1"
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\functions.ps1"
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\byof.ps1"
#####################################################################

$logLocation = '<YOUR DIR LOCATION>'
$dateTime = Get-Date -F 'yyyyMMddHHmm'
$filename = "LogFile-$($dateTime).txt"

$Transcript = (Join-Path -Path $logLocation -ChildPath $filename).ToString()

Start-Transcript $Transcript -NoClobber

Clear-Host

$validate = parseData
verifyInfo -DataArray $validate

if($validate.IsBYOF -ne "Y"){
    apiAuth
    createIpSpace
    createNetwork
    getIpSpaceUplinkID
    ipSpaceUplink
    createEdge
    vSphereConn
    tagResourcePool
    updateThresholds
}
else{
    apiAuth
    createByof
    assignDirectNetwork
    updateThresholds
}


