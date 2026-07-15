$PSDefaultParameterValues['Connect-AzAccount:UseDeviceAuthentication'] = $true

function Connect-AzFresh {
    [CmdletBinding()]
    param()

    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
    Clear-AzContext -Force -ErrorAction SilentlyContinue
    Connect-AzAccount
}
