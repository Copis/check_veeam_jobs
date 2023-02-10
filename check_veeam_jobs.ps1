

# Parameters
#Get arguments 
param(
	[string]$excluded_jobs = "",
	[string]$pattern,
	[int]$run_warning = 5,
	[int]$run_critical = 10,
	[int]$run_copy_warning = 48,
	[int]$run_copy_critical = 72,
	[int]$run_disabled_critical = 24
)

if($excluded_jobs -ne ""){
	$excluded_jobs_array = $excluded_jobs.Split(",")
}

# Import Powershell moudle 
if (Get-Module -Name Veeam*){
    Get-Module -Name Veeam* | Import-Module -DisableNameChecking
}
else{
    Write-Host "Required PS Module not found!"
    exit 2
}

#-------------------------------------------------------------------------------
$output_jobs_failed 	= ""
$output_jobs_warning	= ""
$output_jobs_disabled	= ""
$output_jobs_working	= ""
$nagios_output 			= ""
$nagios_state 			= 0

$output_jobs_failed_counter 	= 0
$output_jobs_warning_counter 	= 0
$output_jobs_success_counter 	= 0
$output_jobs_none_counter 		= 0
$output_jobs_working_counter 	= 0
$output_jobs_skipped_counter 	= 0
$output_jobs_disabled_counter 	= 0

$jobtype = @(“Backup”,”Replica”)


#Get Veeam backup jobs
if ($pattern -eq $null) {
    $jobs = Get-VBRJob
}
else {
    $pattern = "*$pattern*"
    $jobs = Get-VBRJob -Name $pattern
}

#Loop through every backup job
ForEach($job in $jobs){
	$status 	= $job.GetLastResult()
	$state 		= $($job.findlastsession()).State
	$scheduled	= $job.IsScheduleEnabled
	
	#Parse the date when the job last run 
	$runtime = $job.GetScheduleOptions() | Select-Object LatestRunLocal

	#Skip excluded jobs
    if($job.Name -in $excluded_jobs_array ){
	$output_jobs_skipped_counter++
    continue
    }

	#Skip jobs that are currently disabled
	if($scheduled){
		if($status -eq "Failed"){
			$output_jobs_failed += $job.Name + " (" + $runtime.LatestRunLocal + "), "
			$nagios_state = 2
			$output_jobs_failed_counter++
		}
		elseif($status -eq "Warning"){
			$output_jobs_warning += $job.Name + " (" + $runtime.LatestRunLocal + "), "
			if($nagios_state -lt 1){
				$nagios_state = 1
			}
			$output_jobs_warning_counter ++
		}
		elseif($status -eq "None" -and $state -eq "Working"){
			$output_jobs_working_counter++
            $start_time =$(Get-Date).Add(-$runtime.LatestRunLocal).Hour
            if ( $job.JobType -in $jobtype){
                if ( $start_time -gt $run_warning -and $start_time -lt $run_critical){
                    $output_jobs_working += $job.Name + " (" + $runtime.LatestRunLocal + "), "
                    if($nagios_state -lt 1){ 
						$nagios_state = 1 
					}
			    }
                elseif($start_time -gt $run_critical){
                    $output_jobs_working += $job.Name + " (" + $runtime.LatestRunLocal + "), "
                    $nagios_state = 2
                }
		    }
            else{
                if ( $start_time -gt $run_copy_warning -and $start_time -lt $run_copy_critical){
                    $output_jobs_working += $job.Name + " (" + $runtime.LatestRunLocal + "), "
				    if($nagios_state -lt 1){
					    $nagios_state = 1 
				    }
                }
                elseif($start_time -gt $run_copy_critical){
				    $output_jobs_working += $job.Name + " (" + $runtime.LatestRunLocal + "), "
				    $nagios_state = 2
			    }
		}
			
		}
		elseif($status -eq "None" -and $state -ne "Idle"){
			$output_jobs_none_counter++
		}
        else{ 
			$output_jobs_success_counter++	
        }
	}
	else{
        $start_time = New-TimeSpan -End $(Get-Date) -Start $runtime.LatestRunLocal
        $start_time = $start_time.TotalHours
        $output_jobs_disabled_counter++
		$output_jobs_disabled += $job.Name + " (" + $runtime.LatestRunLocal + "), "
		if($nagios_state -lt 1){
			$nagios_state = 1
		}
        if($start_time -ge $run_disabled_critical){
			$nagios_state = 2
		}
    }
}

#We could display currently running jobs, but if we'd like to use the Nagios stalking option we just summarize "ok" and "working"
#$output_jobs_success_counter = $output_jobs_working_counter + $output_jobs_success_counter

if($output_jobs_failed -ne ""){
	$output_jobs_failed 	= $output_jobs_failed.Substring(0, $output_jobs_failed.Length-2)
	$nagios_output += "`nFailed: " + $output_jobs_failed
}

if($output_jobs_warning -ne ""){
	$output_jobs_warning 	= $output_jobs_warning.Substring(0, $output_jobs_warning.Length-2)
	$nagios_output += "`nWarning: " + $output_jobs_warning
}

if($output_jobs_working -ne ""){
	$output_jobs_working 	= $output_jobs_working.Substring(0, $output_jobs_working.Length-2)
	$nagios_output += "`nWorking: " + $output_jobs_working
}

if($output_jobs_disabled -ne ""){
	$output_jobs_disabled 	= $output_jobs_disabled.Substring(0, $output_jobs_disabled.Length-2)
	$nagios_output += "`nDisabled: " + $output_jobs_disabled
}

if($nagios_state -ne 0){
	Write-Host "Backup Status - Failed: "$output_jobs_failed_counter" / Warning: "$output_jobs_warning_counter" / OK: "$output_jobs_success_counter" / Working: "$output_jobs_working_counter" / None: "$output_jobs_none_counter" / Skipped: "$output_jobs_skipped_counter" / Disabled: "$output_jobs_disabled_counter $nagios_output
    exit $nagios_state
}
else{
	Write-Host "Backup Status - All "$output_jobs_success_counter" backups successful"
    exit $nagios_state
}
