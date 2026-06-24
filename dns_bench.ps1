<#
.SYNOPSIS
    DNS benchmark.

.DESCRIPTION
    Times A-record lookups across a list of public resolvers and renders a
    live table that stays sorted by response time as each result comes in.

    Per-server queries use Resolve-DnsName, which ships with Windows
    (DnsClient module). On Linux/macOS PowerShell this cmdlet is not
    available, so the per-server timings will fail there.

.PARAMETER HostName
    The hostname to look up. Defaults to www.google.com.

.EXAMPLE
    .\dns_bench.ps1
    .\dns_bench.ps1 github.com
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$HostName = 'www.google.com'
)

$servers = [ordered]@{
    'OpenDNS_1'          = '208.67.222.222'
    'OpenDNS_2'          = '208.67.220.220'
    'L3_1'               = '209.244.0.3'
    'L3_2'               = '209.244.0.4'
    'Verisign'           = '64.6.64.6'
    'Google_1'           = '8.8.8.8'
    'Google_2'           = '8.8.4.4'
    'Quad9_1'            = '9.9.9.9'
    'CloudFlare'         = '1.1.1.1'
    'Quad9_2'            = '149.112.112.112'
    'DNSINC_1'           = '216.146.35.35'
    'DNSINC_2'           = '216.146.36.36'
    'CensurFriDNS'       = '89.233.43.71'
    'DNSWatch_1'         = '84.200.69.80'
    'DNSWatch_2'         = '84.200.70.40'
    'Hurricane Electric' = '74.82.42.42'
    'OpenNIC'            = '94.247.43.254'
    'DNS4EU Protective'  = '86.54.11.1'
    'DNS4EU Child'       = '86.54.11.12'
    'DNS4EU Adblock'     = '86.54.11.13'
    'DNS4EU Unfiltered'  = '86.54.11.100'
}

function Measure-DnsLookup {
    <# Time a single A-record lookup against one nameserver.
       Returns elapsed seconds, or throws on failure. #>
    param(
        [Parameter(Mandatory)][string]$HostName,
        [Parameter(Mandatory)][string]$Server
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = Resolve-DnsName -Name $HostName -Server $Server -Type A `
                            -DnsOnly -QuickTimeout -ErrorAction Stop
    $sw.Stop()
    return $sw.Elapsed.TotalSeconds
}

class LiveTable {
    # Reprints a time-sorted table in place each time a row is added.
    [string] $HostName
    [System.Collections.Generic.List[object]] $Rows
    [int] $PrevLines
    hidden [string] $Esc = [char]27

    LiveTable([string] $hostName) {
        $this.HostName  = $hostName
        $this.Rows      = [System.Collections.Generic.List[object]]::new()
        $this.PrevLines = 0
    }

    [void] Add([string] $name, [string] $ip, [double] $elapsed) {
        $this.Rows.Add([pscustomobject]@{ Name = $name; IP = $ip; Time = $elapsed })
        $this.Render()
    }

    [void] Render() {
        $ordered = $this.Rows | Sort-Object Time

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('')
        $lines.Add("Timing lookups for $($this.HostName)")
        $lines.Add('')
        $lines.Add(('{0,-20} {1,-15} {2,10}' -f 'Server', 'IP', 'Time'))
        $lines.Add('-' * 47)
        foreach ($r in $ordered) {
            $lines.Add(('{0,-20} {1,-15} {2,10:F5}' -f $r.Name, $r.IP, $r.Time))
        }

        # Move the cursor up over the previous render and clear it, so the
        # table refreshes in place instead of scrolling.
        if ($this.PrevLines -gt 0) {
            [Console]::Write("$($this.Esc)[$($this.PrevLines)A$($this.Esc)[J")
        }
        foreach ($line in $lines) { [Console]::WriteLine($line) }
        $this.PrevLines = $lines.Count
    }
}

$table     = [LiveTable]::new($HostName)
$errorList = [System.Collections.Generic.List[string]]::new()

# OS default resolver
try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = [System.Net.Dns]::GetHostAddresses($HostName)
    $sw.Stop()
    $table.Add('OS_Default', 'local', $sw.Elapsed.TotalSeconds)
}
catch {
    $errorList.Add(('{0,-10} {1,-15} failed: {2}' -f 'OS_Default', 'local', $_.Exception.Message))
}

foreach ($entry in $servers.GetEnumerator()) {
    try {
        $elapsed = Measure-DnsLookup -HostName $HostName -Server $entry.Value
        $table.Add($entry.Key, $entry.Value, $elapsed)
    }
    catch {
        $errorList.Add(('{0,-10} {1,-15} failed: {2}' -f $entry.Key, $entry.Value, $_.Exception.Message))
    }
}

Write-Host ''
foreach ($err in $errorList) { Write-Host $err }
Write-Host ''
