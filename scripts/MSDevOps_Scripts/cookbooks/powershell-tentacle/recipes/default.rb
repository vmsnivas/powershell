#
# Cookbook:: powershell
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

# Recipe to run powershell script

powershell_script 'InstallTentacle' do
	code <<-EOH
	############### Install tentacle ##################

	Start-Process msiexec.exe -ArgumentList @('/qn', '/lv C:\\FTPFiles\\tentacle-log.txt', '/i C:\\FTPFiles\\Tentacle.msi') -NoNewWindow -Wait

	##########Install  Nuget Octoposh #################

	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
	start-sleep 30
	Install-Module -Name Octoposh -force
	start-sleep 40
	Import-Module Octoposh

	###################################################

	################# Install IIS #####################

	Start-Process msiexec.exe -ArgumentList @('/qn', '/lv C:\\FTPFiles\\IIS-log.txt', '/i C:\\FTPFiles\\iisexpress.msi') -NoNewWindow -Wait

	###################################################
	EOH
end

powershell_script 'RegisterTentacle' do
	code <<-EOH
	$OctopusAPI = 'API-SZTBBJGPAVIJJKK68D5CLJGCNOO'
	$OctopusServerURL = 'http://150.150.150.88/'

	Set-OctopusConnectionInfo -URL $OctopusServerURL -APIKey $OctopusAPI
	$OctopusThumbPrint =  Get-OctopusServerThumbprint
	#######################################

	#### Get Host Details  ######
	$TentacleIP = Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address
	###############################

	######################
	##### Octo Config ####
	######################
	cd "C:\\Program Files\\Octopus Deploy\\Tentacle"
	$OctoEnv = 'Dev'
	$OctoRole = 'webserver'
	 #### tentacle config generation
	.\\Tentacle.exe create-instance --instance $TentacleIP --config "C:\\Octopus\\Tentacle.config" --console
	.\\Tentacle.exe new-certificate --instance $TentacleIP --if-blank --console
	.\\Tentacle.exe configure --instance $TentacleIP --reset-trust --console
	.\\Tentacle.exe configure --instance $TentacleIP --home "C:\\Octopus" --app "C:\\Octopus\\Applications" --port "10933" --console
	.\\Tentacle.exe configure --instance $TentacleIP --trust $OctopusThumbPrint --console
	#"netsh" advfirewall firewall add rule "name=Octopus Deploy Tentacle" dir=in action=allow protocol=TCP localport=10933
	.\\Tentacle.exe register-with --instance $TentacleIP --server $OctopusServerURL --apiKey=$OctopusAPI --role $OctoRole --environment $OctoEnv --comms-style TentaclePassive --console
	.\\Tentacle.exe service --instance $TentacleIP --install --start --console

	$file = "C:\\Octopus\\Tentacle.config"
	$xml = [xml](Get-Content $file)
	$TentacleThumbPrint = ($xml.'octopus-settings'.set | Where-Object {$_.key -eq 'Tentacle.CertificateThumbprint'}).'#text'

 	##### Tentacle Registration #####
 	Add-Type -Path 'Newtonsoft.Json.dll'
 	Add-Type -Path 'Octopus.Client.dll'

 	$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusServerURL, $OctopusAPI
 	$repository = new-object Octopus.Client.OctopusRepository $endpoint

	$Random = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
	$Hostname = ($Hostname -Replace [Environment]::NewLine,"").ToString() + '-' + $Random
 
	$tentacle = New-Object Octopus.Client.Model.MachineResource
 	$tentacle.name = $Hostname
 	$tentacle.EnvironmentIds.Clear()
 	$tentacle.EnvironmentIds.Add($OctoEnv)
 	$tentacle.Roles.Clear()
 	$tentacle.Roles.Add($OctoRole)

 	$tentacleEndpoint = New-Object Octopus.Client.Model.Endpoints.ListeningTentacleEndpointResource
 	$tentacle.EndPoint = $tentacleEndpoint
 	$tentacle.Endpoint.Uri = "https://"+$TentacleIP+":10933"
 	$tentacle.Endpoint.Thumbprint = $TentacleThumbPrint

 	$repository.machines.create($tentacle)
	EOH
end
