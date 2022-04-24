# Set Target Server
$global:uri = 'https://time.is'

# Set Variables
$global:stopwatch_master = New-Object System.Diagnostics.Stopwatch
$global:UserAgent = ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

$clock_pool = [System.Collections.ArrayList]@()
$pool_size = 20
$generation_delay = 250


class ServerClock {
    [System.Diagnostics.Stopwatch]$stopwatch = [System.Diagnostics.Stopwatch]::new()
    [DateTime]$server_clock
    [DateTime]$delta
    [Boolean]$invalid = $false

    ServerClock() {
        $r = curl.exe -s -I -L -X HEAD $global:uri -A $global:UserAgent -w "%{time_pretransfer}\n%{time_starttransfer}\n%{time_total}"
        $this.stopwatch.Start()
        if ($r.Length -le 3) {
            # Write-Host('Failed to reach!')
            $this.stopwatch.Stop()
            $this.invalid = $true
        } else {
            # Get "Date" in HTTP response header / Start backward in case of redirections
            For ($i=$r.Length-1;$i -ge 0;$i--) {
                if ($r[$i] -match "^Date:") {
                    $this.server_clock = [DateTime]$r[$i].Split(',')[1]
                    break
                }
            }

            # Get cURL (time_total - time_starttransfer) + (time_starttransfer - time_pretransfer)/2 in tick
            $time_to_respond = [int64](([decimal]$r[-1] - [decimal]$r[-2])*10000000) + [int64](([decimal]$r[-2] - [decimal]$r[-3])*5000000)
        
            # Roughly compensate for the time-to-respond
            $this.server_clock = $this.server_clock.AddTicks($time_to_respond)

            # Get Delta
            $this.delta = $this.GetClock().AddTicks(-$global:stopwatch_master.ElapsedTicks)
        }
    }


    [DateTime]GetDelta() {
        return $this.delta
    }


    [DateTime]GetClock() {
        return $this.server_clock.AddTicks($this.stopwatch.ElapsedTicks)
    }
}

# Resize Console Window
$pswindow = (Get-Host).ui.rawui
$newsize = $pswindow.windowsize
$newsize.height = 5
$newsize.width = 38
$pswindow.windowsize = $newsize
$newsize = $pswindow.buffersize
$newsize.height = 5
$newsize.width = 38
$pswindow.buffersize = $newsize


Write-Host("`n")
$global:stopwatch_master.Start()
$i = 1
While ($i -le $pool_size) {
    Write-Host("`r" + ' Generating a pool of clocks...({0}/{1})' -f $i,$pool_size) -NoNewline
    $clock_pool.Add([ServerClock]::new()) |Out-Null
    if ($clock_pool[-1].invalid) {$clock_pool.RemoveAt($i-1)}
    $i++
    Start-Sleep -Milliseconds $generation_delay
}
$global:stopwatch_master.Stop()


Clear-Host


# Process of finding the best guess, removing outliers
# Basically, it is finding a one-second timeframe with the most results

$i = 0
$candidate_done = $false
$candidate = [System.Collections.ArrayList]@()
$clock_pool = $clock_pool |Sort -Property delta -Descending

While ($i -lt $clock_pool.Count -and !$candidate_done) {
    For ($j=$clock_pool.Count-1;$j -ge 0;$j--) {
        if ($clock_pool[$i].Delta.Ticks - $clock_pool[$j].Delta.Ticks -lt 10000000) {
            if ($j -eq $clock_pool.Count-1) {$candidate_done = $true}
            $cc = $j-$i
            $candidate.Add([System.Tuple]::Create($cc,$i))| Out-Null
            break
        }
    }
    $i++
}

$candidate = $candidate |Sort -Descending
$the_clock = $clock_pool[$candidate[0].Item2]


Write-Host('Synced to', $the_clock.server_clock)
Write-Host('')

$newsize = $pswindow.windowsize
$newsize.width = 33
$pswindow.windowsize = $newsize
$newsize = $pswindow.buffersize
$newsize.width = 33
$pswindow.buffersize = $newsize


While ($true) {
    Write-Host("`r" + " "*8 + ($the_clock.GetClock()).ToString("hh:mm:ss:ff tt")) -NoNewline
    Start-Sleep -Milliseconds 20
}


