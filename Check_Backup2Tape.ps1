# Install NsClient++ and configure it properly for tyour environment in the Veeam Backup Server
# Add the following lines to the nsclient.ini file removing the hash character at the beggining
# /settings/external scripts/scripts]
# check_veeam_jobs = cmd /c echo scripts\Check_Veeam_Jobs.ps1 ; exit($lastexitcode) | powershell.exe -command -
# Copy this script to the %programfiles%\nsclient++\scripts folder and restart nsclient service
# By default this script checks all the backup jobs defined and warns when a job fails or is disabled
# if you donï¿½t want to be warned when a job is disabled, use the -d switch
# if you want to check one specific backup job, use -j switch followed by the Job Name 
# This is a sample of how to add those parameters to the nsclient.ini file:
# check_veeam_jobs = cmd /c echo scripts\Check_Veeam_Jobs.ps1  "-d" "$ARG1$" "-f" ; exit($lastexitcode) | powershell.exe -command -
# Good luck 
# @javichumellamo

Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
function CheckOneJob {
    $JobCheck=get-vbrtapejob -Name 'Backup2Tape'
        if($global:OutMessageTemp -ne ""){$global:OutMessageTemp+="`r`n"}

        if($JobCheck.Enabled -eq $false){ # Disabled job -> WARNING
            if($JobCheck.Enabled -ne $true){
                $global:OutMessageTemp+=" WARNING - Le job '"+$JobCheck.Name+"' est desactive "
                $global:WarningDisabledCount++  #exo
                if($global:ExitCode -lt 2){$global:ExitCode=1} # if no previous Critical status then switch to WARNING
                }
            }
        else  # The job is enabled
        {
            $lastStatus=$JobCheck | Foreach-Object LastResult
            if($lastStatus -eq "Working"){
                $global:OutMessageTemp+="OK - Le job "+$JobCheck.Name+" est en cours de sauvegarde"
                $global:OutMessageTemp+="OK "+$LastRun+" est le temps"
                $global:OkCount++  #exo
            }
            else {
                if($lastStatus -ne "Success"){ # Failed or None->never run before (probaly a newly created job)
                    if($lastStatus -eq "none"){
                        $global:OutMessageTemp+="WARNING: Le job "+$JobCheck.Name+" n a jamais ete execute"
                        $global:WarningCount++  #exo
                        if($global:ExitCode -ne 2) {$global:ExitCode=1}
                    }
                    elseif($lastStatus -eq "Warning"){
                        $global:OutMessageTemp+="WARNING - Le job "+$JobCheck.Name+" s est termine avec des messages d'alertes"
                        $global:WarningCount++  #exo
                        if($global:ExitCode -ne 2) {$global:ExitCode=1}
                    }
                    else {
                        $global:OutMessageTemp+="CRITICAL - Le job "+$JobCheck.Name+" a echoue"
                        $global:CriticalCount++  #exo
                        $global:ExitCode=2
                       }
                }
                else
                {  
                $LastRunSession=Get-VBRsession -Job $JobCheck -Last | select {$_.endtime}
                $LastRun=$LastRunSession.'$_.endtime'
                $EstRun=get-date
                $DiffTime=$EstRun - $LastRun
                    if ($DiffTime.TotalDays -gt 1)
                    {
                        $global:ExitCode=2
                        $global:OutMessageTemp+="CRITICAL - Le job "+$JobCheck.Name+" n a pas ete execute lors de la derniere journee"
                        $global:CriticalCount++  #exo
                    }
                        else
                        {
                            $LastRunSession=Get-VBRsession -Job $JobCheck -Last | select {$_.endtime}
                            $LastRun=$LastRunSession.'$_.endtime'
                            $global:OutMessageTemp+="OK - "
                            $global:OutMessageTemp+=$JobCheck.Name+" "
                            $global:OutMessageTemp+="execute le "+$LastRun
                            $global:OkCount++  #exo
                        }
                    }
                }
            }
        }

######################################################
#           Main loop (well, not exactly a loop)     #
######################################################

$nextIsJob=$false
$oneJob=$false
$jobToCheck=""
$WrongParam=$false
$DisabledJobs=$true
$global:OutMessageTemp=""
$global:OutMessage=""
$global:Exitcode=""
$WarningPreference = 'SilentlyContinue'

#exo - Ajout de variables pour compter le nombre d'erreurs
$global:WarningDisabledCount=0
$global:WarningCount=0
$global:CriticalCount=0
$global:OkCount=0
$TotalCount=0
$global:Graph=""

if( $args.Length -ge 1)
 {
     foreach($value in $args) {
       if($nextIsJob -eq $true) { # parameter coming after -j switch
            if(($value.Length -eq 2) -and ($value.substring(0,1) -eq '-')){
                $WrongParam=$true
                }
            $nextIsJob=$false
            $jobToCheck=$value
            $onejob=$true
            }
       elseif($value -eq '-j') { # -j -> check only one job and its name goes in the following parameter (default is to check all backup jobs)
            $nextIsJob=$true
            }
       elseif($value -eq '-d') { # -d -> Do not warn for disabled jobs (default is to warn)
            $DisabledJobs=$false
            }
       else {$WrongParam=$true}
       }
  }

if($WrongParam -eq $true){
    write-host "Wrong parameters"
    write-host "Syntax: Check_Veeam_Jobs [-j JobNameToCheck] [-d]"
    write-host "       -j switch to check only one job (default is to check all backup jobs)"
    Write-Host "       -d switch to not inform when there is any disabled job"
    exit 1
    }

$VJobList=get-vbrjob
$ExitCode=0

IF($oneJob -eq $true){
    CheckOneJob($jobToCheck)}
else {
    foreach($Vjob in $VJobList){
        CheckOneJob($Vjob.Name)
    }
}
#exo - Ajout du nombre total d'erreur dÃ©tectÃ©es
$TotalCount=$global:WarningDisabledCount + $global:WarningCount + $global:CriticalCount + $global:OkCount
$global:OutMessage="TOTAL=>" + $TotalCount + " / OK=>" + $global:OkCount + " / CRITICAL=>" + $global:CriticalCount + " / DISABLE=>" + $global:WarningDisabledCount + " / WARNING=>" + $global:WarningCount
#exo - Ajout variable Graph pour visualisation graphique sur centreon
$global:Graph=" |  Ok=" + $global:OkCount + " Warning=" + $global:WarningCount + " Critical=" + $global:CriticalCount
$global:OutMessage+="`r`n" + $global:OutMessageTemp + $global:Graph
write-host $global:OutMessage
exit $global:Exitcode
