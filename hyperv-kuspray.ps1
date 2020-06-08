# (Test-Connection -ComputerName $env:computername -count 1).ipv4address.IPAddressToString
param (
	[parameter( ValueFromPipeline,Mandatory=$true )]
	[ValidateSet('destroy','up','prepare', 'install', 'start', 'restore', 'backup', 'bash', 'init', 'startVMs', 'stopVMs')]
	[string]$Command = 'all',
    [parameter( ValueFromPipeline )]
    [string]$KubernetesInfra = "",
    [parameter( ValueFromPipeline )]
    [ValidateSet('generic/centos8', 'generic/debian10', 'None')]
    [string]$PreferredOs = 'None',
    [switch]$DestroyCurrent,
	[switch]$Hide,
	[switch]$Help
)

[bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )
#TODO for destroy plus prompt
[bool]$Force = ( $PSBoundParameters.ContainsKey( 'Force' ) ) 
[bool]$DestroyCurrent = ( $PSBoundParameters.ContainsKey( 'DestroyCurrent' ) ) 

[String]$AnsibleDebug = ""
if ($Debug){
    $AnsibleDebug = "-vvv"
}

[string] $LaunchDate = Get-Date -Format "MM-dd-yyyy-HH-mm"

if ( ! [System.IO.Directory]::Exists("$pwd\current") ) { 
    echo "* create 'current' dir' *"
    echo ""
    $ret = mkdir $pwd/current/
    if(!$?) { 
        echo "** ERROR *** could not create  $pwd/current/ directory. $ret" 
        exit -1
}

}
if ( ! [System.IO.Directory]::Exists("$pwd\logs") ) {
    echo "* create 'current\logs' dir' *"
    echo ""
    $ret=mkdir $pwd/logs/
    if(!$?) { 
        echo "** ERROR *** could not create  $pwd/current/ directory. $ret" 
        exit -1
}
}

# Logfile name
[string] $LaunchLog = "$pwd/logs/$LaunchDate-$Command.log"

# FIXME : $PreferredOs no more handled via template => remove or inject in template ? 
if ( $PreferredOs -ne "None" ) {
    $Env:K8S_BOX = "$PreferredOs"
}
else {
    $Env:K8S_BOX = ""
}
# Inject vagrant
$Env:K8S_CONFIG = "$KubernetesInfra"

echo ( "** Logs : $LaunchLog" )
## FIXME make countdown sleep 7

function check {

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ( ! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        Write-Host ( "** ERROR *** Please launch Powershell as administrator" ) 
        exit -1
    }

    if( (Get-WindowsOptionalFeature -Online -FeatureName *hyperv* |  Measure-Object -Line).Lines -eq 0 ) {
        Write-Host ( "** ERROR *** Please install and acivate HyperV" ) 
        exit -1
    }

    $checkvagrant = vagrant -v
    if(!$?) { 
        Write-Host ( "** ERROR *** Please install vagrant" ) 
        exit -1
    }

    $checkDocker = docker version
    if(!$?) { 
        Write-Host ( "** ERROR *** Please install and start docker" )
        exit -1
    }
}

##TODO : check_paths
##TODO : check mem
##TODO  rewrite as dump for vagrant and hosts.yaml ??? yes base + concat for invent!

function init ( ) {
    #TODO, *important* : validate config against JSON Schema 

    #TODO : test kubespray/plugins/mitogen if not exists => ansible-playbook -c local /opt/hyperv-kubespray/kubespray/mitogen.yml -vv 


    #TODO : avoid echo
    mkdir -Force $pwd/current/

    #TODO : ensure possible envs&group_vars outside of samples
    copy  ./samples/$KubernetesInfra.yml current/infra.yaml 

    # launch ansible templates that renders in current/vagrant.vars.rb current/inventory.yaml + groups vars from example 
    docker run -v "/var/run/docker.sock:/var/run/docker.sock" --rm -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  --limit=localhost /opt/hyperv-kubespray/playbooks/preconfig.yaml

    Copy-Item ./samples/ -Destination current/ -Recurse
}

## FIXME : dont continue if CTL+C during any phase

function destroy( ) {
    echo "** launching vagrant destroy -f" | tee -a "$LaunchLog"
    #FIXME : export ENV for config
    #ENV['K8S_CONFIG'] = minimal
    # TODO : also move current to old 
    vagrant destroy -f | tee -a "$LaunchLog"
    if (!$?) { echo "Exiting $?";exit -1 }

    echo "Moving current to old-$LaunchDate"
    Get-ChildItem -Path "$pwd/current" -Recurse |  Move-Item -Destination "old-$LaunchDate" -Force 

    echo "destroy done" 
}

function up( ) {
    echo ( "** launching vagrant up" )
    vagrant up | tee -a "$LaunchLog"
    if (!$?) { echo "Exiting $?"; exit -1 }
    echo "up done"
}

function prepare( ) {
    echo ( "** launching ansible-playbook --become -i /.../$KubernetesInfra.yaml /.../playbooks/set-ips.yaml " ) | tee -a "$LaunchLog"
    
    docker run --rm -v "/var/run/docker.sock:/var/run/docker.sock"  -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json' | tee -a $LaunchLog
    if (!$?) { echo "Exiting $?"; exit -1 }
    # echo fatal: [k8s-server-2.mshome.net]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: Shared connection to k8s-server-2.mshome.net closed.", "unreachable": true}
    # =>  try again prepare and install
    # Pleas ensure your not connected to Any VPN
    echo "prepare done"
}

function install( ) {
    # TODO : set and dowload cache dire
    echo ( "** launching ansible-playbook --become -i /...$KubernetesInfra /.../cluster.yml" ) | tee -a "$LaunchLog"
    docker run  --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt 1> /dev/null && ansible-playbook $AnsibleDebug  --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json'" | tee -a $LaunchLog
    if (!$?) { echo "Exiting $?"; exit -1 }
    echo "install done"
}

function bash( ) {
    # TODO : set and dowload cache dire
    echo ( "" )
    echo ( "** Going to bash. Usefull commands : " )
    echo ( "   pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt" )
    echo ( "   ansible-playbook --network host --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json'  -e '@/opt/hyperv-kubespray/config/authent.vars.json'" )
    echo ( "" )

    docker run -it --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash
    if (!$?) { echo "Exiting $?"; exit -1 }
}

if ( $Help ) {
	Clear-Host
	echo ( "`"{0}`", Version {1}" -f ( "$PSCommandPath" -replace "$PSScriptRoot","" ), "0.0.0" ) -NoNewline

	echo
	Get-Help $PSCommandPath -Full
	exit -1
}

#TODO : keep copy of config in previous/current inventory (with same date as log file)
function do_test( ) {
    # for in Envs
    # ./launch distrib
    # ./launch distrib2
    # ./launch no prefered
}

function backup( $BackupName="latest" ) {
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Checkpoint-VM -Name $_.Name -SnapshotName "$BackupName"}
    if (!$?) { exit -1 }
}

function restore( $BackupName="kubernetesInit" ) {
    #TODO : pass argument for backup name in main parameters
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Restore-VMSnapshot -Confirm:$false -Name "$BackupName" -VMName $_.Name }
    if (!$?) { exit -1 }
}

function startVMs ( ) {
    Get-VM | Where-Object {$_.Name -like 'k8s-*' -and $_.State -ne "Running" } | ForEach-Object -Process { Start-VM $_.Name }
}

function stopVMs ( ) {
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Stop-VM  $_.Name }
}

function bashAll( $AdHocCmd="" ) {
    # TODO run adhoc command on inventory

}

#TODO function stop and #function start (handle one vm): Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process { Start-VM -Name $_.Name }


#TODO : rename as "start", deal with current plus option --destroy  
function run ( ) {
    check
    echo ""
    echo "*Check OK*"

    # Is this a new cluster ? 
    $newEnv = 0
    if ( [System.IO.File]::Exists("$pwd\current\vagrant.vars.rb") ) {
        if ( $DestroyCurrent ){
            if ( "$KubernetesInfra" -eq ""){
                echo "Please provide env as second script parameter. Example : start minimal -DestroyCurrent "
                exit -1
            }
            
            echo "Found current env, destroying..."
            destroy

            # Destroyed => new VMs needed
            $newEnv=1
        } 
    }


    # no current vagrant conf ? creates plus ansible inventory
    if ( ! [System.IO.File]::Exists("$pwd\current\vagrant.vars.rb") ) {
        init
        echo "*init OK*"
        echo ""

        # New vagrant => new VMs needed
        $newEnv=1
    }

    if ( $newEnv ) {
        up

        echo "*up OK*"
        echo ""
    }
    # not new VMS ? => start without vagrant (too slow) 
    else {
        startVMs
        
        echo "*quick start VMs OK*"
        echo ""
    }

    #cluster was not prepared ? run playbook 
    if ( ! [System.IO.File]::Exists("$pwd\current\prepared.ok") ) {
        prepare
        echo "*prepare OK*"
        
        echo "ok" > $pwd\current\prepared.ok

        backup("prepared")
        echo "*backup OK*"    
        echo ""
    }
    else {
        echo "Platform is already prepared for kubernetes"
    }

    # kubernetes not installed ? run cluster playbook 
    if ( ! [System.IO.File]::Exists("$pwd\current\installed.ok") ) {
        install
        echo "*install OK*"

        echo "ok" > $pwd\current\installed.ok
    
        backup("kubernetesInit")
        echo "*backup OK*"
        echo ""
        }
        else {
            echo "Kubernetes already installed. Nothing to do."
            echo ""
        }

        echo ""
        echo "*Kubernetes now running.*"
}


if ( "$Command" -eq "start" ){
    run #start is reserved kyword in powershell
}
elseif ( "$Command" -eq "destroy" ){
    destroy 
}
elseif ( "$Command" -eq "up" ){
    up
}
elseif ( "$Command" -eq "prepare" ){
    prepare
}
elseif ( "$Command" -eq "install" ){
    install
}
elseif ( "$Command" -eq "check" ){
    check
}
elseif ( "$Command" -eq "backup" ){
    backup
}
elseif ( "$Command" -eq "restore" ){
    restore
}
elseif ( "$Command" -eq "bash" ){
    bash
}
elseif ( "$Command" -eq "init" ){
    init
}
elseif ( "$Command" -eq "startVMs" ){
    startVMs
}
elseif ( "$Command" -eq "stopVMs" ){
    stopVMs
}

