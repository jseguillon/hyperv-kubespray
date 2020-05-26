param (
	[parameter( ValueFromPipeline,Mandatory=$true )]
	[ValidateSet('destroy','up','prepare', 'install', 'all', 'restore', 'backup')]
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

[String]$AnsibleDebug = ""
if ($Debug){
    $AnsibleDebug = "-vvv"
}

[string] $LaunchDate = Get-Date -Format "MM-dd-yyyy-HH-mm"
[string] $LaunchLog = "$pwd/inventory/$LaunchDate-$KubernetesEnv-$Command.log"

if ( ("all", "destroy", "up,", "prepare", "install") -contains "$Command" ){
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
sleep 7

function check {

    Get-WindowsOptionalFeature -Online -FeatureName *hyper*
# FIXME Rewrite
# PS C:\temp\hyperv-kubespray-master> $a=Get-WindowsOptionalFeature -Online -FeatureName *hyperv* |  Measure-Object -Line
# PS C:\temp\hyperv-kubespray-master> echo $a.Lines
# 2
# PS C:\temp\hyperv-kubespray-master> $a=Get-WindowsOptionalFeature -Online -FeatureName *hyaaperv* |  Measure-Object -Line
# PS C:\temp\hyperv-kubespray-master> echo $a.Lines
# 0

    if(!$?) { 
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
        Write-Host ( "** ERROR *** Please install docker" ) 
        exit -1
    }
}

##TODO : check_paths
##TODO : check mem 
##TODO  rewrite as dump for vagrant and hosts.yaml ??? yes base + concat for invent! 
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
    echo ( "** launching ansible-playbook --become -i /.../$KubernetesEnv.yaml /.../playbooks/$KubernetesEnv.yaml " ) | tee -a "$LaunchLog"
    docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook $AnsibleDebug --become -i /opt/hyperv-kubespray/inventory/$KubernetesEnv.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml | tee -a $LaunchLog
    if (!$?) { exit -1 }
}

function install( ) {
    # TODO : set and dowload cache dire 
    echo ( "** launching ansible-playbook --become -i /.../minimal.yaml /.../cluster.yml" ) | tee -a "$LaunchLog"
    docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt && ansible-playbook $AnsibleDebug  --become -i /opt/hyperv-kubespray/inventory/$KubernetesEnv.yaml /opt/hyperv-kubespray/kubespray/cluster.yml" | tee -a $LaunchLog
    if (!$?) { exit -1 }
}


if ( $Help ) {
	Clear-Host
	echo ( "`"{0}`", Version {1}" -f ( "$PSCommandPath" -replace "$PSScriptRoot","" ), "0.0.0" ) -NoNewline

	echo
	Get-Help $PSCommandPath -Full
	exit -1
}

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

function restore( $BackupName="vagrantInit" ) {
    Get-VM | Where-Object {$_.Name -like 'k8s-*'} | ForEach-Object -Process {Restore-VMSnapshot -Confirm:$false -Name "$BackupName" -VMName $_.Name }
    if (!$?) { exit -1 }
}

function all ( ){
    check
    echo "*Check OK"

    destroy
    echo "*Destroy OK"
    
    up
    echo "*up OK"
    
    backup("vagrantInit")
    echo "*backup OK"

    sleep 10 

    prepare
    echo "*prepare OK"

    install
    echo "*install OK"
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
elseif ( "$Command" -eq "instal" ){
    install
}
elseif ( "$Command" -eq "check" ){
    check
}
elseif ( "$Command" -eq "backup" ){
    backup
}
if ( "$Command" -eq "restore" ){
    restore
}


