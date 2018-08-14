$subscriptionId = $args[0]
$resourceGroupName = $args[1]
$location = $args[2]
$managedInstanceName = $args[3]
$administratorLogin = $args[4]
$administratorLoginPassword = $args[5]
$certificateNamePrefix = $args[6]
$scriptUrlBase = $args[7]

function Ensure-Login () 
{
    $context = Get-AzureRmContext
    If($context.Subscription -eq $null)
    {
        Login-AzureRmAccount | Out-null
    }
}

Ensure-Login

$context = Get-AzureRmContext
If($context.Subscription.Id -ne $subscriptionId)
{
    #TODO check if subscription exists
    Select-AzureRmSubscription -SubscriptionId $subscriptionId  | Out-null
}

$certificate = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
    -Subject ("CN=$certificateNamePrefix"+"P2SRoot") -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

$certificateThumbprint = $certificate.Thumbprint

New-SelfSignedCertificate -Type Custom -DnsName ($certificateNamePrefix+"P2SChild") -KeySpec Signature `
    -Subject ("CN=$certificateNamePrefix"+"P2SChild") -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -Signer $certificate -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") | Out-null

$publicRootCertData = [Convert]::ToBase64String((Get-Item cert:\currentuser\my\$certificateThumbprint).RawData)

$templateParameters = @{
    location = $location
    managedInstanceName = $managedInstanceName
    administratorLogin  = $administratorLogin
    administratorLoginPassword = $administratorLoginPassword
    publicRootCertData = $publicRootCertData
}

New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri ($scriptUrlBase+'/azuredeploy.json') -TemplateParameterObject $templateParameters