param (
    [string][Parameter(Mandatory = $true)] $Name,
    [string] $TemplateName = ".\clusterTemplate.json",
    [string] $Location = "westeurope"
)

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. "$ScriptDirectory\Utils.ps1"

$ErrorActionPreference = 'Stop'

$ResourceGroupName = "$Name-rg"
$KeyVaultName = "$Name-cfg"
$ClusterAdminName = "cluster-admin"
$ClusterAdminPwd = GeneratePassword 16 2

CheckLoggedIn
EnsureResourceGroup $ResourceGroupName $Location
$keyVault = EnsureKeyVault $KeyVaultName $ResourceGroupName $Location
Write-Host "$($keyVault.ResourceId)"
$cert = EnsureCertificateImported $Name $KeyVaultName

Set-Content -Path "cluster.pwd.txt" -Value "$ClusterAdminPwd"
Write-Host "Cluster admin password stored to 'cluster.pwd.txt'"

Write-Host "Creating claster using $TemplateName..."
$Parameters = @{
    clusterName           = $Name;
    clusterLocation       = $Location;
    computeLocation       = $Location;
    adminUserName         = $ClusterAdminName;
    adminPassword         = $ClusterAdminPwd;
    nicName               = "$Name-nic";
    publicIPAddressName   = "$Name-pubip";
    dnsName               = "$Name";
    virtualNetworkName    = "$Name-vnet";
    lbName                = "$Name-lb";
    lbIPName              = "$Name-lbip";
    sourceVaultValue      = $keyVault.ResourceId;
    certificateUrlValue   = $cert.SecretId;
    certificateThumbprint = $cert.Thumbprint;
}

New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile "$TemplateName" `
    -Mode Incremental `
    -TemplateParameterObject $Parameters `
    -Verbose