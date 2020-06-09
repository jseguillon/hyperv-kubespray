

# Import-Module -DisableNameChecking
[String]$AnsibleDebug = ""
if ($Debug){
    $AnsibleDebug = "-vvv"
}

[string] $LaunchDate = Get-Date -Format "MM-dd-yyyy-HH-mm"

if ( ! [System.IO.Directory]::Exists("$pwd\current") ) { 
    Write-Verbose ( "* create 'current' dir' *" )
    
    $ret = mkdir $pwd/current/
    if(!$?) { 
        Write-Error ("** ERROR *** could not create  $pwd/current/ directory. $ret" )
       # exit -1
    }

}
if ( ! [System.IO.Directory]::Exists("$pwd\logs") ) {
    Write-Verbose ( "create 'logs' dir' *" )
    
    $ret=mkdir $pwd/logs/
    if(!$?) { 
        Write-Error ("** ERROR *** could not create  $pwd/logs/ directory. $ret" )
        # exit -1
    }
}

# Logfile name
[string] $LaunchLog = "$pwd/logs/$LaunchDate-$Command.log"

# FIXME : $PreferredOs no more handled via template => remove or inject in template ? 
Write-Host ( "** Logs : $LaunchLog" )

## FIXME : dont continue if CTL+C during any phase

function Remove-Winspray-VMs {
 
    [bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )

    Write-Host ( " ### Winspray : launching vagrant destroy -f" | tee -a "$LaunchLog" )

    vagrant destroy -f | tee -a "$LaunchLog"

    ####Check for any exit replace with throw
    
    if (!$?) { throw ("Exiting $?") }

    Write-Verbose( "### Winspray : Moving current to old-$LaunchDate" )
    #FIXME this cause problem if vagrant destroy not ok
    Get-ChildItem -Path "$pwd/current" -Recurse |  Move-Item -Destination "old-$LaunchDate" -Force 

    Write-Host ( "### Winspray : destroy done" ) -ForegroundColor DarkGreen
}

function New-Winspray-VMs {    
    Write-Host ( " ### Winspray : launching vagrant up" )
    vagrant up | tee -a "$LaunchLog" | Write-Host
    if (!$?) { throw "Exiting $?"; }
    Write-Host ( "### Winspray : VMs created" ) -ForegroundColor DarkGreen
}

function Backup-Winspray-VMs {
        [CmdletBinding()]
    Param(   
        [parameter( ValueFromPipeline )]
        [string]$BackupName = ""
    )
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Checkpoint-VM -Name $_.Name -SnapshotName "$BackupName"}
    if (!$?) { exit -1 }
}
function Restore-Winspray-VMs {    
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Restore-VMSnapshot -Confirm:$false -Name "$BackupName" -VMName $_.Name }
    if (!$?) { exit -1 }
}
function Start-Winspray-VMs {    
    Get-VM | Where-Object {$_.Name -like 'k8s-*' -and $_.State -ne "Running" } | ForEach-Object -Process { Start-VM $_.Name }
}

function Stop-Winspray-VMs {    
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Stop-VM  $_.Name }
}
function Prepare-Winspray-Hosts( ) {
    [bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )

    Write-Host ( "### Winspray : preparing VMs for kubernetes" )
    Write-Verbose ( " ### Winspray : launching ansible-playbook --become -i /.../$KubernetesInfra.yaml /.../playbooks/set-ips.yaml " ) | tee -a "$LaunchLog" | Write-Host
    
    docker run --rm -v "/var/run/docker.sock:/var/run/docker.sock"  -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json' | tee -a $LaunchLog | Write-Host
    if (!$?) { throw "Exiting $?" }
    Write-Host ( "### Winspray : VMs prepared for kubespray" ) -ForegroundColor DarkGreen

}
function Install-Winspray-Hosts( ) {    
    Write-Host ( "### Winspray : install kubernetes" )
    Write-Verbose ( "** launching ansible-playbook --become -i /...$KubernetesInfra /.../cluster.yml" ) | tee -a "$LaunchLog"
    docker run  --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt 1> /dev/null && ansible-playbook $AnsibleDebug  --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json'" | tee -a $LaunchLog
    if (!$?) { throw "Exiting $?" }
    Write-Host ( "### Winspray : kubernetes installed" ) -ForegroundColor DarkGreen
}

function Do-Winspray-Bash( ) {

    Write-Host ( "" )
    Write-Host ( "** Going to bash. Here are usefull commands : " )
    Write-Host ( "   pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt" )
    Write-Host ( "   ansible-playbook --network host --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json'  -e '@/opt/hyperv-kubespray/config/authent.vars.json'" )
    Write-Host ( "" )

    docker run -it --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash
    if (!$?) { throw "Exiting $?" }
}


function do_test( ) {
    # TODO
    # for in Envs
    # ./launch distrib
    # ./launch distrib2
    # ./launch no prefered
}


function Test-Winspray-Env {
    ##TODO : check_paths
    ##TODO : check mem

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ( ! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        throw ( "** ERROR *** Please launch Powershell as administrator" ) 
    }

    if( (Get-WindowsOptionalFeature -Online -FeatureName *hyperv* |  Measure-Object -Line).Lines -eq 0 ) {
        throw ( "** ERROR *** Please install and acivate HyperV" ) 
    }

    vagrant -v
    if(!$?) { 
        throw ( "** ERROR *** Please install vagrant" ) 
    }

    docker version
    if(!$?) { 
        throw ( "** ERROR *** Please install and start docker" )
    }
}


function Winspray-Validate-Config () {
    # TODO run python validation against schema 
}
function Set-Winspray-Inventory ( ) {
    #TODO, *important* : validate config against JSON Schema 

    #TODO : test kubespray/plugins/mitogen if not exists => ansible-playbook -c local /opt/hyperv-kubespray/kubespray/mitogen.yml -vv 

    #TODO : ensure possible envs&group_vars outside of samples
    copy  ./samples/$KubernetesInfra.yml current/infra.yaml 

    # launch ansible templates that renders in current/vagrant.vars.rb current/inventory.yaml + groups vars from example 
    docker run -v "/var/run/docker.sock:/var/run/docker.sock" --rm -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  --limit=localhost /opt/hyperv-kubespray/playbooks/preconfig.yaml | Write-Host

    if (!$?) {
        throw ( "** ERROR *** Found error while creating inventory" )
    }
    # todo clean
    Copy-Item ./samples/group_vars -Destination current/ -Recurse
}

function Start-Winspray-Cluster ( ) {
    [CmdletBinding()]
    Param(   
        [parameter( ValueFromPipeline )]
        [string]$KubernetesInfra = "",
        [switch]$DestroyCurrent
    )

    Write-Host ("* Starting") -ForegroundColor DarkGreen

    # FIXME debug
    [bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )
    [bool]$DestroyCurrent = ( $PSBoundParameters.ContainsKey( 'DestroyCurrent' ) ) 
    
    Write-Host ("# Winspray  -  check env" ) 

    Test-Winspray-Env

    Write-Host ( "## Winspray  -  check ok " ) -ForegroundColor DarkGreen

    
    # Is this a new cluster ? 
    $newEnv = 0
    if ( [System.IO.File]::Exists("$pwd\current\vagrant.vars.rb") ) {
        if ( $DestroyCurrent ){
            Write-Host ("# Winspray  -  should destroy env " ) 
            if ( "$KubernetesInfra" -eq ""){
                throw ( "Please provide env as second script parameter. Example : start minimal -DestroyCurrent " )
            }
            
            Write-Host ( "## Winspray  -  found current env, destroying...")  
            Remove-Winspray-VMs 

            Write-Host ( "## Winspray  -  VM destroyed ")  -ForegroundColor DarkGreen
            # Destroyed => new VMs needed   
            $newEnv=1
        } 
    }

    
    # no current vagrant conf ? creates plus ansible inventory
    if ( ! [System.IO.File]::Exists("$pwd\current\vagrant.vars.rb") ) {
        Write-Host ("# Winspray  -  init if needed" ) 
        Set-Winspray-Inventory 

        Write-Host ( "## Winspray  -  init ok")   -ForegroundColor DarkGreen

        # New vagrant => new VMs needed
        $newEnv=1
    }

    if ( $newEnv ) {
        Write-Host ("# Winspray  -  new VMs wanted" )
        New-Winspray-VMs
        Write-Host ( "## Winspray  -  Vms created ok")   -ForegroundColor DarkGreen
    }
    # not new VMS ? => start without vagrant (too slow) 
    else {
        Write-Host ("# Winspray  -  start VMS" )
        Start-Winspray-VMs
        Write-Host ( "## Winspray  -  VMS started ok")  -ForegroundColor DarkGreen
    }

    #cluster was not prepared ? run playbook 
    if ( ! [System.IO.File]::Exists("$pwd\current\prepared.ok") ) {
        Write-Host ("# Winspray  -   prepare VMS for kubespray" )
        Prepare-Winspray-Hosts
        echo "ok" > $pwd\current\prepared.ok
        Write-Host ( "## Winspray  -  VMS prepared ok")   -ForegroundColor DarkGreen 
  
        Backup-Winspray-VMs ("prepared")

        Write-Host ( "## Winspray  -  backup named 'prepared' done")   -ForegroundColor DarkGreen
    }
    else {
        Write-Host (" ## Winspray  -   VMS already prepared" ) 
    }

    # kubernetes not installed ? run cluster playbook 
    if ( ! [System.IO.File]::Exists("$pwd\current\installed.ok") ) {
        Write-Host ("# Winspray  -   install VMS with kubespray" )
        Install-Winspray-Hosts
        echo "ok" > $pwd\current\installed.ok
        Write-Host ( "## Winspray  -  kubernetes now installed")   -ForegroundColor DarkGreen
  
        Backup-Winspray-VMs ("installed")

        Write-Host ( "## Winspray  -  backup named 'prepared' done")  -ForegroundColor DarkGreen
    }
    else {
        Write-Host ("## Winspray  -   Kubernetes already installed. Nothing to do" ) 
    }

    Write-Host ""
    Write-Host "# Kubernetes now running.*" -ForegroundColor DarkGreen
}


Export-ModuleMember -Function Remove-Winspray-VMs, New-Winspray-VMs, Backup-Winspray-VMs, Restore-Winspray-VMs, Start-Winspray-VMs, Stop-Winspray-VMs, Prepare-Winspray-Hosts, Install-Winspray-Hosts, Do-Winspray-Bash, Test-Winspray-Env, Set-Winspray-Inventory, Start-Winspray-Cluster 