function Rename-AzVM {
	<#
	.Synopsis
		Renames Azure Virtual Machine by recreating the object
		and attaching associated resources.
	.Description
		Retrieves the VM object.
		Checks if the virtual machine is in a "deallocated state".
		If the VM is not deallocated, shutdown and deallocate the VM.
		Deletes the virtual machine object. 
		Recreate the virtual machine object, attaching the existing 
		NIC(s) and disk(s). 
	.Example
		> Rename-AzVM -VMName "Ubuntu01" -ResourceGroupName "MyRG" -OperatingSystem "Linux" -NewVMName "Ubuntu02"
	.Link
		https://github.com/sjohnsonsf/azure-renanme-vm
	.Inputs
		None
	.Outputs
		None
	#>
	[CmdletBinding(SupportsShouldProcess=$True)]
		Param
		(
			[Parameter(Mandatory=$true,HelpMessage="Provide the Resource Group.")]
			[string]$ResourceGroupName,
			[Parameter(Mandatory=$true,HelpMessage="Provide the VM name.")]
			[string]$VMName,
			[Parameter(Mandatory=$true,HelpMessage="Provide the Operating System.")]
			[ValidateSet("Windows","Linux")]
			[string]$OperatingSystem,
			[Parameter(Mandatory=$true,HelpMessage="Provide a new VM name.")]
			[string]$NewVMName
		)
		PROCESS {
			if ($pscmdlet.ShouldProcess("Continue?")) {
				Try {
					$OriginalVM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction "Stop"

				} Catch {
					Write-Host "$VMName was not found in Resource Group $ResourceGroupName. Aborting..."
					Break
				}
				Write-Host 'Deallocating and renaming...' $originalVM.Name

				#Retrieve the VM status and pull the PowerState from the last index position
				$VMState = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).statuses.code[-1]
				if ($VMState -ne "PowerState/deallocated") {
					Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force
				}
				Remove-AzVM -ResourceGroupName $ResourceGroupName -Name $originalVM.Name -Force
				Sleep 30 
				
				$NewVM = New-AzVMConfig -VMName $NewVMName -VMSize $OriginalVM.HardwareProfile.VmSize
				if ($OperatingSystem -eq "Linux") {
					$params = @{
						VM = $NewVM
						CreateOption = "Attach"
						ManagedDiskId = $OriginalVM.StorageProfile.OsDisk.ManagedDisk.Id
						Name = $originalVM.StorageProfile.OsDisk.Name
						Linux = $True
					}
					Set-AzVMOSDisk @params
				} elseif ($OperatingSystem -eq "Windows") {
					$params = @{
						VM = $NewVM
						CreateOption = "Attach"
						ManagedDiskId = $OriginalVM.StorageProfile.OsDisk.ManagedDisk.Id
						Name = $originalVM.StorageProfile.OsDisk.Name
						Windows = $True
					}
					Set-AzVMOSDisk @params
				}
				ForEach ($Disk in $OriginalVM.StorageProfile.DataDisks) {
					$params = @{
						VM = $NewVM
						Name = $Disk.Name
						ManagedDiskId = $Disk.ManagedDisk.Id
						Caching = $Disk.Caching
						Lun = $Disk.Lun
						DiskSizeinGB = $Disk.DiskSizeGB
						CreateOption = "Attach"
					}
					Add-AzVMDataDisk @params
				}
				ForEach ($NIC in $OriginalVM.NetworkProfile.NetworkInterfaces) {	
					if ($NIC.Primary -eq $True) {
						Add-AzVMNetworkInterface -VM $NewVM -Id $NIC.Id -Primary
					} else {
						Add-AzVMNetworkInterface -VM $NewVM -Id $NIC.Id
					}
				}
				New-AzVM -ResourceGroupName $ResourceGroupName -Location $OriginalVM.Location -VM $NewVM -DisableBginfoExtension
			}
			else {
				Write "Aborting..."
			}
		}
	} #End function