# Shared by the connection script and the application's DNS repair action.
# Only local rules carrying Ocelot's marker are managed here. Group Policy,
# MDM and effective policies without an identifiable local rule are read only.
Set-StrictMode -Version 2.0

function Get-OcelotDnsState {
    $path = 'HKLM:\SOFTWARE\SculkDev\Ocelot\DnsState'
    if (!(Test-Path -LiteralPath $path -ErrorAction Stop)) { return @() }
    $value = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
    if ($value.PSObject.Properties['Rules'] -and $value.Rules) {
        $parsed = $value.Rules | ConvertFrom-Json -ErrorAction Stop
        foreach ($record in $parsed) { $record }
        return
    }
    return @()
}

function Save-OcelotDnsState($Rules) {
    $path = 'HKLM:\SOFTWARE\SculkDev\Ocelot\DnsState'
    $null = New-Item -Path $path -Force -ErrorAction Stop
    $json = ConvertTo-Json -InputObject @($Rules) -Depth 6 -Compress
    $null = New-ItemProperty -LiteralPath $path -Name Rules -Value $json -PropertyType String -Force -ErrorAction Stop
}

function Get-OcelotDnsSignature($Namespaces, $Servers) {
    $zones = @($Namespaces | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Sort-Object -Unique)
    $addresses = @($Servers | ForEach-Object { ([string]$_) -split '[;,\s]+' } |
        Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    return ($zones -join ',') + '|' + ($addresses -join ',')
}

function Get-OcelotDnsSources {
    foreach ($root in @(
        'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters\DnsPolicyConfig',
        'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient\DnsPolicyConfig')) {
        if (!(Test-Path -LiteralPath $root -ErrorAction Stop)) { continue }
        foreach ($key in @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)) {
            $value = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
            if (!$value.PSObject.Properties['Name'] -or !$value.PSObject.Properties['GenericDNSServers']) { continue }
            $comment = ''; $displayName = ''
            if ($value.PSObject.Properties['Comment']) { $comment = [string]$value.Comment }
            if ($value.PSObject.Properties['DisplayName']) { $displayName = [string]$value.DisplayName }
            [pscustomobject]@{
                Path = $key.PSPath; Name = $key.PSChildName
                Namespace = @($value.Name); NameServers = @($value.GenericDNSServers)
                Comment = $comment; DisplayName = $displayName
                Source = $(if ($root -like '*\SOFTWARE\Policies\*') { 'GPO/MDM policy store' } else { 'Local registry' })
            }
        }
    }
}

function Test-OcelotDnsRecord($Rule, $Record) {
    return $Rule.Comment -eq 'ocelot' -and $Rule.DisplayName -eq $Record.DisplayName -and
        (Get-OcelotDnsSignature $Rule.Namespace $Rule.NameServers) -eq
        (Get-OcelotDnsSignature $Record.Namespace $Record.NameServers) -and
        (!$Record.Name -or $Rule.Name -eq $Record.Name)
}

function Remove-OcelotDnsRules {
    $records = @(Get-OcelotDnsState)
    $rules = @(Get-DnsClientNrptRule -ErrorAction Stop)
    $sources = @(Get-OcelotDnsSources)
    # Retain a journal even after deletion until Windows confirms that the
    # policy stopped applying. A crash or delayed policy reload is retryable.
    $localSources = @($sources | Where-Object { $_.Source -eq 'Local registry' })
    foreach ($rule in @($rules) + $localSources) {
        if ($rule.Comment -ne 'ocelot') { continue }
        if (!@($records | Where-Object {
            $_.Name -eq $rule.Name -or (!$_.Name -and $_.DisplayName -eq $rule.DisplayName)
        }).Count) {
            $records += [pscustomobject]@{ Name=$rule.Name; Namespace=@($rule.Namespace)
                NameServers=@($rule.NameServers); DisplayName=$rule.DisplayName }
        }
    }
    Save-OcelotDnsState $records
    foreach ($rule in $rules) {
        if ($rule.Comment -ne 'ocelot') { continue }
        # A journal entry whose content was changed by someone else is no
        # longer ours to remove, even if it kept the old comment.
        $sameId = @($records | Where-Object {
            $_.Name -eq $rule.Name -or (!$_.Name -and $_.DisplayName -eq $rule.DisplayName)
        })
        if ($sameId.Count -and !@($sameId | Where-Object { Test-OcelotDnsRecord $rule $_ }).Count) {
            throw "NRPT rule $($rule.Name) changed outside Ocelot; preserved."
        }
        Remove-DnsClientNrptRule -Name $rule.Name -Force -ErrorAction Stop
    }
    # A local, journalled rule can outlive the CIM view. Never remove entries
    # from the policy store, or infer ownership from a domain/server alone.
    foreach ($source in $sources) {
        if ($source.Source -ne 'Local registry') { continue }
        if (@($records | Where-Object { Test-OcelotDnsRecord $source $_ }).Count -and
            (Test-Path -LiteralPath $source.Path -ErrorAction Stop)) {
            Remove-Item -LiteralPath $source.Path -Recurse -Force -ErrorAction Stop
        }
    }
    Clear-DnsClientCache -ErrorAction Stop
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
        $remainingRules = @(Get-DnsClientNrptRule -ErrorAction Stop | Where-Object { $_.Comment -eq 'ocelot' })
        $remainingLocal = @(Get-OcelotDnsSources | Where-Object {
            $_.Source -eq 'Local registry' -and $_.Comment -eq 'ocelot'
        })
        $effective = @(Get-DnsClientNrptPolicy -Effective -ErrorAction Stop)
        $remainingPolicies = @($effective | Where-Object {
            $policy = $_
            @($records | Where-Object {
                (Get-OcelotDnsSignature $policy.Namespace $policy.NameServers) -eq
                (Get-OcelotDnsSignature $_.Namespace $_.NameServers)
            }).Count
        })
        if (!$remainingRules.Count -and !$remainingLocal.Count -and !$remainingPolicies.Count) { break }
        if ($attempt -lt 5) { Start-Sleep -Milliseconds 400 }
    }
    if ($remainingRules.Count -or $remainingLocal.Count -or $remainingPolicies.Count) {
        throw 'Ocelot DNS policy is still effective after cleanup. Journal retained; check policy sources and permissions.'
    }
    # Also surface an effective rule with no editable/source entry, as in a
    # stale DNS-client policy cache. Reporting success here hides the outage.
    $sources = @(Get-OcelotDnsSources)
    $unattributed = @($effective | Where-Object {
        $policy = $_
        !@($sources | Where-Object {
            (Get-OcelotDnsSignature $policy.Namespace $policy.NameServers) -eq
            (Get-OcelotDnsSignature $_.Namespace $_.NameServers)
        }).Count
    })
    if ($unattributed.Count) {
        $details = @($unattributed | ForEach-Object {
            (Get-OcelotDnsSignature $_.Namespace $_.NameServers) + ' [source: unresolved effective policy; not removed]'
        }) -join '; '
        throw "Effective DNS policy has no identifiable local source: $details"
    }
    Save-OcelotDnsState @()
    return [pscustomobject]@{ Removed=$records.Count; PreservedPolicies=$effective.Count }
}

function Add-OcelotDnsRules([string[]]$Namespaces, [string[]]$Servers) {
    if (!$Namespaces.Count -or !$Servers.Count) { throw 'DNS namespaces and servers are required.' }
    foreach ($server in $Servers) {
        $address = $null
        if (![Net.IPAddress]::TryParse($server, [ref]$address)) { throw 'Invalid DNS server address.' }
    }
    $null = Remove-OcelotDnsRules
    $records = @()
    try {
        $foreign = @(Get-DnsClientNrptPolicy -Effective -ErrorAction Stop)
        foreach ($zone in @($Namespaces | Sort-Object -Unique)) {
            if ($zone -ne '.' -and $zone -notmatch '^\.[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)*\.?$') {
                throw 'Invalid split DNS namespace.'
            }
            if (@($foreign | Where-Object { @($_.Namespace) -contains $zone }).Count) {
                throw "DNS namespace $zone is already managed by another policy; preserved."
            }
            $record = [pscustomobject]@{ Name=''; Namespace=@($zone); NameServers=@($Servers)
                DisplayName=('Ocelot/' + [guid]::NewGuid().ToString()) }
            $records += $record
            # Persist the unique intent before adding the rule. If interrupted
            # before the returned ID is saved, the marker still identifies it.
            Save-OcelotDnsState $records
            $rule = Add-DnsClientNrptRule -Namespace $zone -NameServers $Servers -Comment 'ocelot' `
                -DisplayName $record.DisplayName -PassThru -ErrorAction Stop
            if (!$rule -or !$rule.Name) { throw 'Windows did not return the created NRPT rule ID.' }
            $record.Name = $rule.Name
            Save-OcelotDnsState $records
        }
        Clear-DnsClientCache -ErrorAction Stop
        $effective = @()
        for ($attempt = 0; $attempt -lt 6; $attempt++) {
            $effective = @(Get-DnsClientNrptPolicy -Effective -ErrorAction Stop)
            $missing = @($records | Where-Object {
                $record = $_
                !@($effective | Where-Object {
                    (Get-OcelotDnsSignature $_.Namespace $_.NameServers) -eq
                    (Get-OcelotDnsSignature $record.Namespace $record.NameServers)
                }).Count
            })
            if (!$missing.Count) { break }
            if ($attempt -lt 5) { Start-Sleep -Milliseconds 400 }
        }
        if ($missing.Count) { throw 'The requested DNS rules are not effective; a managed policy may override local NRPT.' }
        return [pscustomobject]@{ Applied=$records.Count }
    } catch {
        $failure = $_.Exception.Message
        try { $null = Remove-OcelotDnsRules } catch { $failure += ' Cleanup: ' + $_.Exception.Message }
        throw $failure
    }
}

function Invoke-OcelotDns([ValidateSet('Apply','Cleanup')] [string]$Action,
    [string[]]$Namespaces = @(), [string[]]$Servers = @(), [string]$GatewayHost = '') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required to repair VPN DNS policies.'
    }
    if ($Action -eq 'Apply') { return Add-OcelotDnsRules $Namespaces $Servers }
    $result = Remove-OcelotDnsRules
    if ($GatewayHost) {
        try { $null = [Net.Dns]::GetHostAddresses($GatewayHost) }
        catch { throw "Ocelot rules were removed, but DNS lookup for $GatewayHost still failed. Preserved policies: $($result.PreservedPolicies). $($_.Exception.Message)" }
    }
    return $result
}
