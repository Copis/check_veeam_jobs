

# Parameters
param(
    [string]$Server,
    [string]$user,
    [string]$password,
    [string]$pattern
)

#Adding required SnapIn
if ((Get-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue) -eq $null) {
	Add-PsSnapin VeeamPSSnapIn
}

#Get Veeam backup jobs
if ($pattern -eq $null) {
    $jobs = Get-VBRJob
}
else {
    $pattern = "*$pattern*"
    $jobs = Get-VBRJob -Name $pattern
}

foreach ($job in $jobs) {
    Write-Host $job.Name
    }
