# Edited by @wetcoriginal for backup 2 tape jobs #


Add-PSSnapin -Name VeeamPSSnapIn -ErrorAction SilentlyContinue
function CheckOneJob {
    $JobCheck=get-vbrtapejob -Name 'Backup to Tape Job'
        if($global:OutMessageTemp -ne ""){$global:OutMessageTemp+="`r`n"}

        if($JobCheck.Enabled -eq $false){ # Disabled job -> WARNING
            if($JobCheck.Enabled -ne $true){
                $global:OutMessageTemp+=" WARNING - Le job '"+$JobCheck.Name+"' est desactive "
                $global:WarningDisabledCount++
                if($global:ExitCode -lt 2){$global:ExitCode=1} # if no previous Critical status then switch to WARNING
                }
            }
        else  # The job is enabled
        {
            $lastStatus=$JobCheck | Foreach-Object LastResult
			$lastState=$JobCheck | Foreach-Object LastState
            if($lastState -eq "Working"){
                $global:OutMessageTemp+="OK - Le job "+$JobCheck.Name+" est en cours de sauvegarde"
                $global:OkCount++ 
			}
           elseif($lastState -eq "WaitingTape"){
                $global:OutMessageTemp+="WARNING - Le job "+$JobCheck.Name+" est en attente d'une bande de sauvegarde"
                $global:WarningCount++ 
            }
            else {
                if($lastStatus -ne "Success"){ # Failed or None->never run before (probaly a newly created job)
                    if($lastStatus -eq "none"){
                        $global:OutMessageTemp+="WARNING: Le job "+$JobCheck.Name+" n a jamais ete execute"
                        $global:WarningCount++
                        if($global:ExitCode -ne 2) {$global:ExitCode=1}
                    }
                    elseif($lastStatus -eq "Warning"){
                        $global:OutMessageTemp+="WARNING - Le job "+$JobCheck.Name+" s est termine avec des messages d'alertes"
                        $global:WarningCount++
                        if($global:ExitCode -ne 2) {$global:ExitCode=1}
                    }
                    else {
                        $global:OutMessageTemp+="CRITICAL - Le job "+$JobCheck.Name+" a echoue"
                        $global:CriticalCount++
                        $global:ExitCode=2
                       }
                }
                else
                {  
                $LastRunSession=Get-VBRsession -Job $JobCheck -Last | select {$_.endtime}
                $LastRun=$LastRunSession.'$_.endtime'
                $EstRun=get-date
                $DiffTime=$EstRun - $LastRun
                    if ($DiffTime.Days -gt 1)
                    {
                        $global:ExitCode=2
                        $global:OutMessageTemp+="CRITICAL - Le job "+$JobCheck.Name+" n a pas ete execute lors de la derniere journee"
                        $global:CriticalCount++
                    }
                        else
                        {
                            $LastRunSession=Get-VBRsession -Job $JobCheck -Last | select {$_.endtime}
                            $LastRun=$LastRunSession.'$_.endtime'
                            $global:OutMessageTemp+="OK - "
                            $global:OutMessageTemp+=$JobCheck.Name+" "
                            $global:OutMessageTemp+="execute le "+$LastRun
                            $global:OkCount++
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

#Ajout de variables pour compter le nombre d'erreurs
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
        CheckOneJob($Vjob.Name)
    }
#Ajout du nombre total d'erreur dÃ©tectÃ©es
$TotalCount=$global:WarningDisabledCount + $global:WarningCount + $global:CriticalCount + $global:OkCount
$global:OutMessage="TOTAL=>" + $TotalCount + " / OK=>" + $global:OkCount + " / CRITICAL=>" + $global:CriticalCount + " / DISABLE=>" + $global:WarningDisabledCount + " / WARNING=>" + $global:WarningCount
#Ajout variable Graph pour visualisation graphique sur centreon
$global:Graph=" |  Ok=" + $global:OkCount + " Warning=" + $global:WarningCount + " Critical=" + $global:CriticalCount
write-host $global:OutMessageTemp
write-host $global:OutMessage
exit $global:Exitcode
