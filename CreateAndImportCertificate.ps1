#Requires -Version 3.0

Param (
    [string][Parameter(Mandatory = $true)] $ClusterName,
    [string] $Location = "westeurope"
)

. "$PSScriptRoot\Utils.ps1"

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$ResourceGroupName = "$ClusterName-rg"
$KeyVaultName = "$ClusterName-cfg"

CheckLoggedIn
EnsureResourceGroup $ResourceGroupName $Location
$keyVault = EnsureKeyVault $KeyVaultName $ResourceGroupName $Location
$cert = EnsureCertificateImported $ClusterName $KeyVaultName

Write-Host "Provide following parameters to ARM template:" -ForegroundColor Green
Write-Host "sourceVaultValue:" -ForegroundColor Green
Write-Host "$($keyVault.ResourceId)"
Write-Host "certificateUrlValue:" -ForegroundColor Green
Write-Host "$($cert.SecretId)"
Write-Host "certificateThumbprint:" -ForegroundColor Green
Write-Host "$($cert.Thumbprint)"
