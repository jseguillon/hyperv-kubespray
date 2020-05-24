param (
	[parameter( ValueFromPipeline )]
	[ValidateSet('destroy','up','prepare', 'install', 'all')]
	[string]$Command = 'all',
    [ValidateSet('xs','minimal','3_masters', '3_masters-3_nodes', 'xxl')]
    [string]$Env = 'minimal',
    [parameter( ValueFromPipeline )]
    [ValidateSet('generic/centos8', 'generic/debian10', 'None')]
    [string]$PreferredOs = 'none',
	[switch]$Hide,
	[switch]$Help
)

[string] $LaunchDate = Get-Date -Format "MM-dd-yyyy-HH-mm"
[string] $LaunchLog = "$pwd/inventory/$LaunchDate-$Env-$Command.log"

if ( $PreferredOs -ne "None" ) {
    $Env:K8S_BOX = "$PreferredOs"
}

Write-Host ( "** Applying '{0}' on env *** {1} *** (PreferredOS='$PreferredOs')" -f ($Command, "$Env")) | tee -a "$LaunchLog"
Write-Host ( "** Logs going to $LaunchLog" )  
sleep 7

function check {

    Get-WindowsOptionalFeature -Online -FeatureName *hyper*
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

## FIXME : dont continue if CTL+C during any phase

function destroy( ) {
    echo "** launching vagrant destroy -f" | tee -a "$LaunchLog"
    vagrant destroy -f | tee -a "$LaunchLog"
    if (!$?) { exit -1 }
}

function up( ) {
    Write-Host ( "** launching vagrant up" ) 
    vagrant up | tee -a "$LaunchLog"
    if (!$?) { exit -1 }
}

function prepare( ) {
    # TODO : var for inv 
    Write-Host ( "** launching ansible-playbook --become -i /.../$Env.yaml /.../playbooks/$Env.yaml " ) | tee -a "$LaunchLog"
    docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray ansible-playbook --become -i /opt/hyperv-kubespray/inventory/$Env.yaml /opt/hyperv-kubespray/playbooks/set-ips.yaml | tee -a $LaunchLog
    if (!$?) { exit -1 }
}

function install( ) {
    Write-Host ( "** launching ansible-playbook --become -i /.../minimal.yaml /.../cluster.yml" ) | tee -a "$LaunchLog"
    docker run -v ${PWD}:/opt/hyperv-kubespray -it quay.io/kubespray/kubespray bash -c "pip install -r /opt/hyperv-kubespray/kubespray/requirements.txt && ansible-playbook --become -i /opt/hyperv-kubespray/inventory/$Env.yaml /opt/hyperv-kubespray/kubespray/cluster.yml" | tee -a $LaunchLog
    if (!$?) { exit -1 }
}

[bool]$Debug = ( $PSBoundParameters.ContainsKey( 'Debug' ) )

if ( $Help ) {
	Clear-Host
	Write-Host ( "`"{0}`", Version {1}" -f ( "$PSCommandPath" -replace "$PSScriptRoot","" ), "0.0.0" ) -NoNewline

	Write-Host
	Get-Help $PSCommandPath -Full
	exit -1
}


if ( $Debug ) {
	Write-Host ( "Search Engine: {0}" -f $(Get-Date -format 'u') )
}

function all ( ){
    destroy
    
    up
    
    prepare
    
    install
}

if ( "$Command" -eq "all" ){
    check
    all
}
if ( "$Command" -eq "destroy" ){
    destroy 
}
if ( "$Command" -eq "up" ){
    up
}
if ( "$Command" -eq "prepare" ){
    prepare
}
if ( "$Command" -eq "instal" ){
    install
}

if ( "$Command" -eq "check" ){
    check
}