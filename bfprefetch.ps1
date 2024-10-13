function bfprefetch {
    [CmdletBinding(DefaultParameterSetName = 'LocalFile')]
    param(
        [Parameter(ParameterSetName = 'WebAddress', Mandatory = $true, HelpMessage = 'File URL to download to BigFix server')]
        [string]$Url,
        [Parameter(ParameterSetName = 'LocalFile', Mandatory = $true, HelpMessage = 'Local file to upload to BigFix server')]
        [string]$Path,
        [Parameter(HelpMessage = 'Print the "Add Prefetch Item" format instead of the default "Prefetch" format')]
        [switch]$AddPrefetchItem
    )
    
    ## Download the file if required
    if ($Url) {
        $Name = ($Url -split '/')[($Url -split '/').Length-1]
        $TempFile = "$env:TEMP\$Name"
        if (Test-Path -Path $TempFile) {
            Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
        }
        try {
            $Pref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $TempFile -ErrorAction Stop
            $ProgressPreference = $Pref
        }
        catch {
            throw $_
        }
        $File = Get-Item -Path $TempFile
    } else {
        $File = Get-Item -Path $Path
    }

    ## Derive name, size, hashes
    $Name = $($File.Name)
    $Size = $($File.Length)
    $Sha1 = (Get-FileHash -Path $File.FullName -Algorithm SHA1).Hash.ToLower()
    $Sha256 = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash.ToLower()

    ## Derive BigFix Software Distribution URL
    if ($Path) {
        $Url = 'SWDProtocol://127.0.0.1:52311/Uploads/{0}/{1}.bfswd' -f $Sha1, $Name
    }

    ## Print the prefetch statement in the desired format, and copy to clipboard
    $PrefetchStatement = switch ($AddPrefetchItem) {
        $true { 'add prefetch item name={0} sha1={1} size={2} url={3} sha256={4}' -f $Name, $Sha1, $Size, $Url, $Sha256 }
        Default {'prefetch "{0}" sha1:{1} size:{2} "{3}" sha256:{4}' -f $Name, $Sha1, $Size, $Url, $Sha256}
    }
    "$PrefetchStatement`n  $AddPrefetchItem" | Write-Output
    "$PrefetchStatement`n  $AddPrefetchItem" | clip.exe 
}