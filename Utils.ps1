$systemWeb = [Reflection.Assembly]::LoadWithPartialName("System.Web")

function CheckLoggedIn() {
    $context = Get-AzureRmContext
    if ([string]::IsNullOrEmpty($context.Account)) {
        Write-Host "Use Login-AzureRmAccount to log in." -ForegroundColor Red
        exit
    }

    Write-Host "'$($context.Account.Id)' in '$($context.Subscription.Name)'" -ForegroundColor Green
}

function EnsureResourceGroup([String]$Name, [String]$Location) {
    $rGroup = Get-AzureRmResourceGroup -Name $Name -Location $Location -ErrorAction Ignore
    if ($null -eq $rGroup) {
        Write-Host "Resource group not found. Creating one..."
        $rGroup = New-AzureRmResourceGroup -Name $Name -Location $Location
        Write-Host "Resource group '$Name' created."
    }
    else {
        Write-Host "Resource group '$Name' already exists."
    }
}

function EnsureKeyVault([string]$Name, [string]$ResourceGroupName, [string]$Location) {
    $kVault = Get-AzureRmKeyVault -VaultName $Name -ErrorAction Ignore
    if ($null -eq $kVault) {
        Write-Host "Key Vault '$Name' not found. Creating one..."
        $kVault = New-AzureRmKeyVault -VaultName $Name -ResourceGroupName $ResourceGroupName -Location $Location -EnabledForDeployment
        Write-Host "Key Vault '$Name' created."
    }
    else {
        Write-Host "Key vault '$Name' already exists."
    }

    $kVault
}

function EnsureCertificateCreated([string]$CertName) {
    $certFilename = "$CertName.pfx"
    $fileExists = Test-Path $certFilename
    if ($fileExists) {
        Write-Host "Using certificate from '$certFilename'"
        $password = Get-Content "$CertName.pwd.txt"
    }
    else {
        Write-Host "Creating new self-signed certificate..."
        $password = GeneratePassword 16 2
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $cert = New-SelfSignedCertificate -DnsName $CertName -CertStoreLocation cert:\CurrentUser\My -KeySpec KeyExchange
        $thumbprint = $cert.Thumbprint
        $certContent = (Get-ChildItem -Path Cert:\CurrentUser\My\$thumbprint)
        $filename = Export-PfxCertificate -Cert $certContent -FilePath $certFilename -Password $securePassword
        Set-Content -Path "$CertName.thumb.txt" -Value $thumbprint
        Set-Content -Path "$CertName.pwd.txt" -Value "$password"
        Write-Host "New certificate stored to '$filename'"
    }

    $certFilename
    $password
}

function GeneratePassword([int]$Length, [int]$NumNotAlphanumeric) {
    [System.Web.Security.Membership]::GeneratePassword($Length, $NumNotAlphanumeric)
}

function EnsureCertificateImported([string]$CertName, [string]$VaultName) {

    $cert = Get-AzureKeyVaultCertificate -VaultName $VaultName -Name $CertName -ErrorAction Ignore
    if ($null -eq $cert) {
        Write-Host "Certificate '$CertName' not found in key vault '$VaultName'. Importing..."
        $certFilename, $password = EnsureCertificateCreated $CertName
        $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
        $cert = Import-AzureKeyVaultCertificate -VaultName $VaultName -Name $CertName -FilePath $certFilename -Password $securePassword
        Write-Host "Certificate '$CertName' imported to key vault '$VaultName'."
    }
    else {
        Write-Host "Certificate '$CertName' already exists in key vault '$VaultName'."
    }
    
    $cert
}