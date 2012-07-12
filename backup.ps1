#Drivesnapshot Backup Script by Michael Reischl http://www.gamorz.de /-/ Alpha 0.5
#Edited by Manuel Sychold http://www.sychold.ch
#This Script takes Images per Week, in every Week Folder you´ll find one full Image and 6 Differential Images.
#The Hash file is Stored on a specified Directory


#If you want to Connect to a UNC Share uncomment the Following Section and on the end of this Script the #Cleanup PSDrive Section.

&lt;#
#Connect Network Share

$drive = "V:" #Drive Letter
$uncpath = "\\192.168.0.1\usbdisk2\Images" #UNC Path you wan´t to get connected
$map = New-Object -ComObject WScript.Network
$map.MapNetworkDrive("$drive",$uncpath)

#&gt;


#Base Informations
$time = Get-Date -uFormat %T #Get Time when Backup Starts
$week = Get-Date -uFormat %V #Get Week Number
$Today = Get-Date #
$destbackup = "V:\backup_folder\$week" #Backup Destination Folder with Week Number
$destbackupmk = "V:\backup_folder\" #Backup Folder for creating Week Number Folders and Deleting old Images
$desthashfile = "-oV:\$destbackup\ihash_`$Computername_`$Disk.hsh"
$srchashfile = "-hV:\$destbackup\ihash_`$Computername_`$Disk.hsh"
$Source = "C:+D:" #Source Drives, more than one? then write "C:+D:+E:"
$fsize = "-L1500" #Maximum filesize in MB
$ooptions = "" #Place for other, additional Options you want to add to DriveSnapshot
$Logfile = "V:\backup_folder\image_$date.log" #The place for the Drivesnapshot Log Files
$Log = "--Logfile:" #Enable Logging
$vss = "--usevss" #VSS Options are --novss - don´t use vss: --usevss - use vss if available: --forcevss - use vss, if not available exit with error
$EmailFrom = "image_backup@mail.com" #Summary Email Sender Address
$EmailTo = "admin@mail.com" #Summary Email Receiver
$EmailSubject = "Image Completed" #Summary Email Subject
$SMTPServer = "192.168.0.1" #Mail Server Address
$delold = "1" # 1=delete all Images older than $kdays / 2=delete all Diff Images older than $kdays and keep Full / 3=delete all Diff Images older than $kdays and move Full Images to $fdirn / 0=turn off function
$kdays = "14" #How long do you wan´t to keep Images, only affected if delold="1,2 or 3"
$fdirn = "full_images" #Folder Destination Name for Full Images inside $destbackup folder

#Count how many Partitions or Disks are in Backup for later use on Testing the Images.
$countd = [regex]::matches($source,"[a-zA-Z]").count

#Create the Backup Destination Folder Based on Week Number, if the folder exists go further.
if (!(Test-Path -path $destbackupmk\$week))
{
New-Item $destbackupmk\$week -type directory
}

#Folder Check if its empty, yes = create full image no = create differential image
$check = (Get-Childitem $destbackup | Measure-Object).count

#Take the Image and Store the Hash file on C Drive for Diff backups!
if ($check -le 0)
{
c:\snapshot $source $destbackup\`$DISK_`$Type_`$Date_`$Computername.sna $desthashfile $vss $fsize $ooptions $Log$Logfile
}
else
{
c:\snapshot $source $destbackup\`$Disk_`$Type_`$Date_`$Computername.sna $srchashfile $vss $fsize $ooptions $Log$Logfile
}

#Now it´s Time for Verification, get the Last written Files sort it and catch the filenames.
if ($lastexitcode -eq 0)
{
$ifiles = @(get-childitem $destbackup -filter *.sna | sort-object lastwritetime -descending | select-object name -first $countd | foreach-object{$_.name})
foreach ($e in $ifiles)
{
c:\snapshot.exe -T $destbackup\$e -W $Log$Logfile
}
}
#Create the Email Body related to exit Code Success/Failed
if ($lastexitcode -eq 0) {
$html = ("&lt;tt&gt;Drivesnapshot Image Completed.&lt;br&gt;" +
"&lt;br&gt;Start time : &amp;nbsp;&amp;nbsp;" + [string]$time +
"&lt;br&gt;Source : &amp;nbsp;&amp;nbsp;" + "%computername%" +
"&lt;br&gt;Destination : &amp;nbsp;" + [string]$destbackup +
"`n&lt;pre&gt;")}

else {
$EmailSubject = "w2k8r2-exchpan Image Failed!!"
$html = ("&lt;tt&gt;Drivesnapshot Image Failed. See the Logs for Details&lt;br&gt;" +
"&lt;br&gt;Start time : &amp;nbsp;&amp;nbsp;" + [string]$time +
"&lt;br&gt;Source : &amp;nbsp;&amp;nbsp;" + "%computername%" +
"&lt;br&gt;Destination : &amp;nbsp;" + [string]$destbackup +
"`n&lt;pre&gt;")}

#New Mail Sending on Powershell v2
Send-MailMessage -SmtpServer $SMTPServer -From $EmailFrom -To $EmailTo -Subject $EmailSubject -Body $html -BodyAsHtml -Attachments $Logfile

#delold option 1 / remove all Images older than $kdays
if ($delold -eq 1)
{
Get-Childitem $destbackupmk -recurse | Where-Object {($Today - $_.LastWriteTime).Days -gt $kdays} | Remove-Item -recurse
}
#delold option 2 / remove all Diff Images older than $kdays and Keep full
if ($delold -eq 2)
{
Get-Childitem $destbackupmk -filter *dif*.* -recurse | Where-Object {($Today - $_.LastWriteTime).Days -gt $kdays} | Remove-Item -recurse
}
#delold option 3 / remove all Diff Images older than $kdays and move Full Images to $fdirn
if ($delold -eq 3) -and (Test-Path -path $destbackup\$fdirn)
{
New-Item $destbackup\$fdirn -type directory
}
if ($delold -eq 3)
{
Get-Childitem $destbackupmk -filter *dif*.* -recurse | Where-Object {($Today - $_.LastWriteTime).Days -gt $kdays} | Remove-Item -recurse;
Move-Item -path $destbackupmk -filter *ful*.* -destination $destbackup\$fdirn
}

#Unmap Backup Folders
$map.RemoveNetworkDrive($uncpath)