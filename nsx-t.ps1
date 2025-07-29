function getEdgeNode {
 
    $NsxManager = "<NSXT MANAGER URL>"
    $Username   = "<ADMIN USER>"
    $Password = Read-Host 'Please enter in the admin password for NSXT Manager' -AsSecureString 
    $TargetNodeNames = @("<EDGE NODE NAME>", "<EDGE NODE NAME>")

 
    $pair = "${Username}:${Password}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
    $encodedCreds = [System.Convert]::ToBase64String($bytes)

    $headers = @{
        "Authorization" = "Basic $encodedCreds"
        "Accept"        = "application/json"
    }

    try {
        $edgeClusters = (Invoke-RestMethod -Uri "$NsxManager/api/v1/edge-clusters" -Method GET -Headers $headers).results
        $logicalRouters = (Invoke-RestMethod -Uri "$NsxManager/api/v1/logical-routers" -Method GET -Headers $headers).results
    } catch {
        Write-Error "API call failed: $_"
        return $null
    }

    $routerCounts = @()

    foreach ($cluster in $edgeClusters) {
        $clusterId = $cluster.id

        foreach ($member in $cluster.members) {
            $memberName = $member.display_name

            if ($TargetNodeNames -contains $memberName) {
                $routerCount = ($logicalRouters | Where-Object { $_.edge_cluster_id -eq $clusterId }).Count

                $routerCounts += [PSCustomObject]@{
                    NodeName    = $memberName
                    RouterCount = $routerCount
                }
            }
        }
    }

    if ($routerCounts.Count -eq 0) {
        return $null
    }

    return ($routerCounts | Sort-Object RouterCount | Select-Object -First 1 -ExpandProperty NodeName)
}
