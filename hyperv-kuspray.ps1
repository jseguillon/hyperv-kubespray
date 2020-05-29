param (
	[parameter( ValueFromPipeline,Mandatory=$true )]
	[ValidateSet('destroy','up','prepare', 'install', 'all', 'restore', 'backup', 'bash', 'init')]
	[string]$Command = 'all',
    [parameter( ValueFromPipeline )]
    [ValidateSet('xs','minimal','3_masters', '3_masters-3_nodes', 'xxl')]
    [string]$KubernetesEnv = "",
    [parameter( ValueFromPipeline )]
    [ValidateSet('generic/centos8', 'generic/debian10', 'None')]
    [string]$PreferredOs = 'None',
	[switch]$Hide,
	[switch]$Help
)

[bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )
[bool]$Force = ( $PSBoundParameters.ContainsKey( 'Force' ) )

[String]$AnsibleDebug = ""
if ($Debug){
    $AnsibleDebug = "-vvv"
}

[string] $LaunchDate = Get-Date -Format "MM-dd-yyyy-HH-mm"

# TODO : avoid echo 
mkdir -Force $pwd/current/logs/
[string] $LaunchLog = "$pwd/current/logs/$LaunchDate-$Command.log"

if ( ("all", "init") -contains "$Command" ){
    if ( "$KubernetesEnv" -eq ""){
        echo "Please provide env as second script parameter"
        exit -1
    }
}

if ( $PreferredOs -ne "None" ) {
    $Env:K8S_BOX = "$PreferredOs"
}
else {
    $Env:K8S_BOX = ""
}
# Inject vagrant
$Env:K8S_CONFIG = "$KubernetesEnv"

echo ( "** Logs : $LaunchLog" )  
echo ( "** Applying '{0}' on env *** {1} *** (PreferredOS='$PreferredOs')" -f ($Command, "$KubernetesEnv")) | tee -a "$LaunchLog"
## FIXME make countdown sleep 7

function check {

    if( (Get-WindowsOptionalFeature -Online -FeatureName *hyperv* |  Measure-Object -Line).Lines -eq 0 ) {
        Write-Host ( "** ERROR *** Please install and acivate HyperV" ) 
        exit -1
    }

    vagrant version
    if(!$?) { 
        Write-Host ( "** ERROR *** Please install vagrant" ) 
        exit -1
    }

    docker version
    if(!$?) { 
        Write-Host ( "** ERROR *** Please install and start docker" )
        exit -1
    }
}

##TODO : check_paths
##TODO : check mem 
##TODO  rewrite as dump for vagrant and hosts.yaml ??? yes base + concat for invent! 

function init ( ) {
#TODO : test if current exists
#TODO : if so, ask for destroy

#fixme : esnure possible envs&group_vars outside of samples 
#TODO : avoid echo
mkdir -Force $pwd/current/
copy  ./samples/$KubernetesEnv.yml current/infra.yaml 

# launch ansible templates that renders in current/vagrant.vars.rb current/inventory.yaml + groups vars from example 
docker run -v "/var/run/docker.sock:/var/run/docker.sock" --rm -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  --limit=localhost /opt/hyperv-kubespray/playbooks/preconfig.yaml -e '@/opt/hyperv-kubespray/current/infra.yaml'
# TODO avoid anoying powershel message
copy -Force ./samples/group_vars/ current/
}

## FIXME : dont continue if CTL+C during any phase

function destroy( ) {
    echo "** launching vagrant destroy -f" | tee -a "$LaunchLog"
    #FIXME : export ENV for config
    #ENV['K8S_CONFIG'] = minimal
    vagrant destroy -f | tee -a "$LaunchLog"
    if (!$?) { exit -1 }
}

function up( ) {
    echo ( "** launching vagrant up" )
    #FIXME : export ENV for config
    #ENV['K8S_CONFIG'] = minimal
    vagrant up | tee -a "$LaunchLog"
    if (!$?) { exit -1 }
}

function prepare( ) {
    echo ( "** launching ansible-playbook --become -i /.../$KubernetesEnv.yaml /.../playbooks/set-ips.yaml " ) | tee -a "$LaunchLog"
    docker run --rm -v "/var/run/docker.sock:/var/run/docker.sock"  -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json' | tee -a $LaunchLog
    if (!$?) { exit -1 }
}

function install( ) {
    # TODO : set and dowload cache dire 
    echo ( "** launching ansible-playbook --become -i /...$KubernetesEnv /.../cluster.yml" ) | tee -a "$LaunchLog"
    docker run  --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt 1> /dev/null && ansible-playbook $AnsibleDebug  --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json' -e '@/opt/hyperv-kubespray/config/authent.vars.json'" | tee -a $LaunchLog
    if (!$?) { exit -1 }
}

function bash( ) {
    # TODO : set and dowload cache dire 
    echo ( "" )
    echo ( "** Going to bash. Usefull commands : " )
    echo ( "   pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt" )
    echo ( "   ansible-playbook $AnsibleDebug  --become  -i /opt/hyperv-kubespray/current/hosts.yaml /opt/hyperv-kubespray/kubespray/cluster.yml -e '@/opt/hyperv-kubespray/config/kubespray.vars.json' -e '@/opt/hyperv-kubespray/config/network.vars.json'  -e '@/opt/hyperv-kubespray/config/authent.vars.json'" )
    echo ( "" )

    docker run --rm -v "/var/run/docker.sock:/var/run/docker.sock" -v ${PWD}:/opt/hyperv-kubespray -t quay.io/kubespray/kubespray bash
    if (!$?) { exit -1 }
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
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Restore-VMSnapshot -Confirm:$false -Name "$BackupName" -VMName $_.Name }
    if (!$?) { exit -1 }
}

function all ( ){
    check
    echo "*Check OK"

    destroy
    echo "*Destroy OK"

    init
    echo "*init OK"

    up
    echo "*up OK"

    backup("vagrantInit")
    echo "*backup OK"

    sleep 3

    prepare
    echo "*prepare OK"

    install
    echo "*install OK"

    backup("kubernetesInit")
    echo "*backup OK"
}


if ( "$Command" -eq "all" ){
    all 
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

