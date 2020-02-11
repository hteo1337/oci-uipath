data "template_file" "uirobot_setup" {
  #count ="${var.instance_count}"
  template = <<EOF
<powershell>
    $UserName="${var.instance_username}"
    $Password="${var.instance_password}"
    $machineName =  "$Env:COMPUTERNAME"
    $temp = "C:\scripts"
    $link = "https://raw.githubusercontent.com/UiPath/Infrastructure/master/Setup/Install-UiRobot.ps1"
    $file = "Install-UiRobot.ps1"

    # create Robot local user 
    $robotRole = "${var.robot_local_account_role}"
    if($robotRole -eq "localuser") {
    $localRobotRole = "Remote Desktop Users"
    } else { $localRobotRole = "Administrators" }

    # Create or update existing user
    if($UserName -eq "opc") {
    $admin = [ADSI]("WinNT://./$UserName, user")
    $admin.SetPassword("$Password")
    } else {
    $Computer = [ADSI]"WinNT://$Env:COMPUTERNAME,Computer"
    $User = $Computer.Create("User", $UserName)
    $User.SetPassword("$Password")
    $User.SetInfo()
    $User.FullName = "$UserName"
    $User.SetInfo()
    $User.Put("Description", "UiPath Robot Admin Account")
    $User.SetInfo()
    $User.UserFlags = 65536
    $User.SetInfo()
    $Group = [ADSI]("WinNT://$Env:COMPUTERNAME/$localRobotRole,Group")
    $Group.add("WinNT://$Env:COMPUTERNAME/$UserName")
    }

    New-Item $temp -ItemType directory
    Set-Location -Path $temp
    Set-ExecutionPolicy Unrestricted -force
    Invoke-WebRequest -Uri $link -OutFile "$temp\$file"
    & "$temp\$file" -orchestratorUrl "${var.orchestrator_url}" -Tennant "${var.orchestrator_tennant}" -orchAdmin "${var.orchestrator_admin}" -orchPassword "${var.orchestrator_adminpw}" -adminUsername "$UserName" -machinePassword "$Password" -HostingType "Standard"  -credType "Default" -RobotType "${var.robot_type}" -addRobotsToExistingEnvs "${var.addRobotToExistingEnvs}"

</powershell>

EOF
}

data "template_cloudinit_config" "cloudinit_config" {
  gzip          = false
  base64_encode = true

  part {
    filename     = "cloudinit.ps1"
    content_type = "text/x-shellscript"
    content      = "${data.template_file.uirobot_setup.rendered}"
  }

}