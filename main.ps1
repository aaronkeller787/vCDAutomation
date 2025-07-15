###########
# Imports #
###########
#####################################################################
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\infoGathering.ps1"
. "<YOUR DIR LOCATION>\vCD-NSX\Modules\functions.ps1"
#####################################################################

$logLocation = '<YOUR DIR LOCATION>'
$dateTime = Get-Date -F 'yyyyMMddHHmm'
$filename = "LogFile-$($dateTime).txt"

$Transcript = (Join-Path -Path $logLocation -ChildPath $filename).ToString()

Start-Transcript $Transcript -NoClobber

Clear-Host

$validate = parseData
verifyInfo -DataArray $validate

apiAuth
createIpSpace
createNetwork
getIpSpaceUplinkID
ipSpaceUplink
createEdge
vSphereConn
tagResourcePool

