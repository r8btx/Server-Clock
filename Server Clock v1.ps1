# Set Target Server
$uri = 'https://time.is'

# Set Variables
$stopwatch = New-Object System.Diagnostics.Stopwatch
$stopwatch_internal = New-Object System.Diagnostics.Stopwatch
$UserAgent = ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

$global:server_clock = $null
$global:sync_corrected = $false
$sync_attempt_min = 20
$sync_attempt_max = 30
$sync_delay = 250

function Init-Clock(){
    $r = curl.exe -s -I -L -X HEAD $uri -A $UserAgent -w "%{time_pretransfer}\n%{time_starttransfer}\n%{time_total}"
    if ($r.Length -le 3) {
        Write-Host('Failed to reach',$uri)
    } else {
        $stopwatch.Start()

        # Get "Date" in HTTP response header / Start backward in case of redirections
        For ($i=$r.Length-1;$i -ge 0;$i--) {if ($r[$i] -match "^Date:") {$server_time = [DateTime]$r[$i].Split(',')[1]; break}}

        # Get cURL (time_total - time_starttransfer) + (time_starttransfer - time_pretransfer)/2 in tick
        $time_to_respond = [int64](([decimal]$r[-1] - [decimal]$r[-2])*10000000) + [int64](([decimal]$r[-2] - [decimal]$r[-3])*5000000)
        
        # Roughly compensate for the time-to-respond
        $server_time = $server_time.AddTicks($time_to_respond)

        $global:server_clock = $server_time
    }
}



function Sync-Clock(){
    $r = curl.exe -s -I -L -X HEAD $uri -A $UserAgent -w "%{time_pretransfer}\n%{time_starttransfer}\n%{time_total}"
    $stopwatch_internal.Restart()
    if ($r.Length -le 3) {
        Write-Host('Failed to reach',$uri)
    } else {
        For ($i=$r.Length-1;$i -ge 0;$i--) {if ($r[$i] -match "^Date:") {$server_time = [DateTime]$r[$i].Split(',')[1]; break}}

        $time_to_respond = [int64](([decimal]$r[-1] - [decimal]$r[-2])*10000000) + [int64](([decimal]$r[-2] - [decimal]$r[-3])*5000000)
        
        $server_time = $server_time.AddTicks($time_to_respond)
        $expected_clock = [DateTime]($server_clock.Ticks + $stopwatch.ElapsedTicks - $stopwatch_internal.ElapsedTicks)
        $diff =  $expected_clock.Ticks - $server_time.Ticks
        
        # if new time is greater than expected clock, update
        # if expected clock is greater than server time by more than 1 sec, update
        if ($diff -lt 0) {
            $stopwatch.Restart()
            $global:sync_corrected = $true
            $global:server_clock = [DateTime]($server_time.Ticks + $stopwatch_internal.ElapsedTicks)
        } elseif ($diff -ge 10000000){
            $stopwatch.Restart()
            $global:server_clock = [DateTime]($server_time.Ticks + $stopwatch_internal.ElapsedTicks)
        }
    }
    $stopwatch_internal.Stop()    
}


# Resize Console Window
$pswindow = (Get-Host).ui.rawui
$newsize = $pswindow.windowsize
$newsize.height = 5
$newsize.width = 30
$pswindow.windowsize = $newsize
$newsize = $pswindow.buffersize
$newsize.height = 5
$newsize.width = 30
$pswindow.buffersize = $newsize


Init-Clock

$i = 1
While ($i -le $sync_attempt_min -or ($i -le $sync_attempt_max -and !$global:sync_corrected)) {
    Write-Host("`r" + 'Synchronizing...({0}/{1})' -f $i,$sync_attempt_min) -NoNewline
    Sync-Clock
    $i++
    Start-Sleep -Milliseconds $sync_delay
}
Write-Host("`r" + 'Synced to', $global:server_clock)

While ($true) {
    Write-Host("`r" + ($server_clock.AddTicks($stopwatch.ElapsedTicks)).ToString("HH:mm:ss:ff")) -NoNewline
    Start-Sleep -Milliseconds 20
}