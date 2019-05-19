#Requires -Version 3.0

Param (
    [string][Parameter(Mandatory = $true)] $Name,
    [string] $TemplateFile = ".\template\bronzeCluster.json",
    [string] $Location = "westeurope"
)

. "$PSScriptRoot\Utils.ps1"

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$ResourceGroupName = "$Name-rg"
$KeyVaultName = "$Name-cfg"
$ClusterAdminName = "cluster-admin"
$ClusterAdminPwd = GeneratePassword 16 2

CheckLoggedIn
EnsureResourceGroup $ResourceGroupName $Location
$keyVault = EnsureKeyVault $KeyVaultName $ResourceGroupName $Location
$cert = EnsureCertificateImported $Name $KeyVaultName

Set-Content -Path "cluster.pwd.txt" -Value "$ClusterAdminPwd"
Write-Host "Cluster admin password stored to 'cluster.pwd.txt'"

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

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$ArtifactStagingDirectory = ".\template"
$ArtifactsLocationName = "_artifactsLocation"
$ArtifactsLocationSasTokenName = "_artifactsLocationSasToken"
$StorageContainerName = $ResourceGroupName.ToLowerInvariant() + "-stageartifacts"

# Convert relative paths to absolute paths if needed
$ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))

# Create the storage account if it doesn't already exist
$StorageAccountName = "stage" + ((Get-AzureRmContext).Subscription.SubscriptionId).Replace('-', '').substring(0, 19)
$StorageAccount = (Get-AzureRmStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName })
if ($null -eq $StorageAccount) {
    $StorageResourceGroupName = "ARM_Deploy_Staging"
    New-AzureRmResourceGroup -Location "$Location" -Name $StorageResourceGroupName -Force
    $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$Location"
}

# Generate the value for artifacts location
$OptionalParameters[$ArtifactsLocationName] = $StorageAccount.Context.BlobEndPoint + $StorageContainerName

# Copy files from the local storage staging location to the storage account container
New-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue *>&1

$ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process { $_.FullName }
foreach ($SourcePath in $ArtifactFilePaths) {
    Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
        -Container $StorageContainerName -Context $StorageAccount.Context -Force
}

# Generate a 4 hour SAS token for the artifacts location
$sasPlainText = (New-AzureStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
$OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString $sasPlainText -AsPlainText -Force

Write-Host "$($OptionalParameters[$ArtifactsLocationName])"
Write-Host "$($OptionalParameters[$ArtifactsLocationSasTokenName])"

New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFile `
    -Mode Incremental `
    -TemplateParameterObject $Parameters `
    @OptionalParameters `
    -Force `
    -Verbose `
    -ErrorVariable ErrorMessages

if ($ErrorMessages) {
    Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
}
