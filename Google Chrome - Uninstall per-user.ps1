<#  

AUTHOR: Kris Powell, Admin Arsenal
DATE: 4/27/2016

This will attempt to forcibly remove all per-user Google Chrome installations
Please test in your environments before rolling out for production.

Tested with Powershell v4

Modified by Toni Ojala for Education environment use

#>

taskkill /IM chrome.exe /F

$PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
$UserProfilesDirectory = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\').ProfilesDirectory
$NotInstalled = @()

# Get all profiles on the machine
$ProfileList = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} | Select  @{name="SID";expression={$_.PSChildName}}, @{name="UserClassesHive";expression={"$($_.ProfileImagePath)\AppData\Local\Microsoft\Windows\Usrclass.dat"}} , @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}

# Get all users found in HKEY_USERS
$LoadedHives = Get-ChildItem Registry::HKEY_USERS | Where-Object {$_.PSChildname -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}

# Get all users not found in HKEY_USERS
$UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name="SID";expression={$_.InputObject}}

Foreach ($item in $ProfileList) {
    # Load Local User Hives
    IF ($item.SID -in $UnloadedHives.SID) {
        reg load HKU\$($Item.SID) $($Item.UserHive) | Out-Null
        reg load HKU\$($Item.SID)_Classes $($item.userClassesHive) | Out-Null
    }

    $Installs = @()
    $Installs += Get-ItemProperty registry::HKEY_USERS\$($Item.SID)\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -eq "Google Chrome"}
    $Installs += Get-ItemProperty registry::HKEY_USERS\$($Item.SID)\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -eq "Google Chrome"} 

    If (!($Installs)) {
        $NotInstalled += $($item.Username)
    } Else {
        "{0}" -f $($item.Username) | Write-Output
        $Installs | Where-Object {$_} | Foreach-Object {
            "{0,-13} {1} {2}" -f "   Found:", $($_.DisplayName), $($_.DisplayVersion) | Write-Output
            "{0,-13} {1}" -f "   Location:", $($_.InstallLocation) | Write-Output
            Get-ChildItem $_.PSParentPath | Where-Object {($_ | Get-ItemProperty).DisplayName -eq "Google Chrome"} | Remove-Item -Force
        }

        ### Remove all per-user Google Chrome traces ###
        $RegKeysToDelete = $FilesAndFoldersToDelete = @()

        # Registry keys 
        $RegKeysToDelete += (Get-ChildItem "registry::HKEY_USERS\$($Item.SID)\Software\Google").PsPath
        $RegKeysToDelete += (Get-ChildItem "registry::HKEY_USERS\$($Item.SID)\Software\Clients\StartMenuInternet" | Where-Object {$_.PSChildName -like "Google Chrome*"}).Pspath
        $RegKeysToDelete += (Get-ChildItem "registry::HKEY_USERS\$($Item.SID)\Software\Microsoft\Windows\CurrentVersion\App Paths" | Where-Object {$_.PSChildName -like "Chrome.exe"}).PsPath
        $RegKeysToDelete += (Get-ChildItem "registry::HKEY_USERS\$($Item.SID)_Classes" | Where-Object {$_.PSChildName -like "Chrome*"}).PsPath
        $RegKeysToDelete | Foreach-Object {If (Test-Path $_) {"{0,-18} {1}" -f "      Deleting...", $_; Remove-Item $_ -Force -Recurse}}
        
        # Registry Values
        $RegValueToDelete = "registry::HKEY_USERS\$($Item.SID)\Software\RegisteredApplications"
        If (Test-path $RegValueToDelete) {"{0,-18} {1}" -f "      Deleting...", $RegValueToDelete; Remove-ItemProperty -Path $RegValueToDelete -Name "Google Chrome*"}

        # Chrome shortcuts and directories
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\Desktop\Google Chrome.lnk"
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Google Chrome.lnk"
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Google Chrome\"
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk"
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Google Chrome.lnk"
        $FilesAndFoldersToDelete += "$userprofilesdirectory\$($Item.Username)\AppData\Local\Google\Chrome\Application\"

        $FilesAndFoldersToDelete | Foreach-Object {If (Test-Path $_) {"{0,-18} {1}" -f "      Deleting...`n", $_; Remove-Item $_ -Force -Recurse}}


    }
    IF ($item.SID -in $UnloadedHives.SID) {
        ### Garbage collection and closing of hive ###
        [gc]::Collect()
        reg unload HKU\$($Item.SID) | Out-Null
        reg unload HKU\$($Item.SID)_Classes | Out-Null
    }
}

$NotInstalled | Sort | Foreach-Object {"{1} {0}" -f $_, "Google Chrome not found:" | Write-Output}
# SIG # Begin signature block
# MIIbaQYJKoZIhvcNAQcCoIIbWjCCG1YCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC93vmzWodyDMMx
# 9J8at7P3FuWg6KWrPQo8QmIa+as6MKCCCjowggTZMIIDwaADAgECAhB333Q9blgq
# lN8VYTchtwybMA0GCSqGSIb3DQEBCwUAMH8xCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3Qg
# TmV0d29yazEwMC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBT
# aWduaW5nIENBMB4XDTE3MDkxMzAwMDAwMFoXDTE5MTAxODIzNTk1OVowcTELMAkG
# A1UEBhMCVVMxDTALBgNVBAgMBFV0YWgxFzAVBgNVBAcMDlNhbHQgTGFrZSBDaXR5
# MRwwGgYDVQQKDBNQRFEuQ09NIENPUlBPUkFUSU9OMRwwGgYDVQQDDBNQRFEuQ09N
# IENPUlBPUkFUSU9OMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAya0x
# 1zSpBpjBsUJOY/rJf0LX2K641qXiH82Lz0wRlrvt/y5saQDvYbiz8IAXLNsKcfWt
# IxZfwCiuDa4RudN2RJePcpyZ0Dd8/f1O1X8bvGMqwLmaSzi8jqglqu2/+r0Z8ANO
# 842yT+fj9MlBx7gOFQY6X6oBxQY4JJy0TljZKBfRDQBT0TNaPLTAKW+6D2AkY7HD
# UDa4bplf7npRAL0LDvb1k2XmhDEJsMijudeuxxawJj26y3DvwUUUE1odPohFSCgN
# XDgA6x3IQOdjaQ14kQ9ouzgSYSQE97AqssIj0Y0R4qezyzQz45vbbEtc4/zf0pVV
# j2Wr4qMLL7EJZRicXQIDAQABo4IBXTCCAVkwCQYDVR0TBAIwADAOBgNVHQ8BAf8E
# BAMCB4AwKwYDVR0fBCQwIjAgoB6gHIYaaHR0cDovL3N2LnN5bWNiLmNvbS9zdi5j
# cmwwYQYDVR0gBFowWDBWBgZngQwBBAEwTDAjBggrBgEFBQcCARYXaHR0cHM6Ly9k
# LnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGQwXaHR0cHM6Ly9kLnN5bWNiLmNv
# bS9ycGEwEwYDVR0lBAwwCgYIKwYBBQUHAwMwVwYIKwYBBQUHAQEESzBJMB8GCCsG
# AQUFBzABhhNodHRwOi8vc3Yuc3ltY2QuY29tMCYGCCsGAQUFBzAChhpodHRwOi8v
# c3Yuc3ltY2IuY29tL3N2LmNydDAfBgNVHSMEGDAWgBSWO1PweTOXr32D7y4rzMq3
# hh5yZjAdBgNVHQ4EFgQUcc7yjRZ9e0F2NrW+slcRNE7DTiEwDQYJKoZIhvcNAQEL
# BQADggEBAHnDUdVkBJGhswkBuXkXIloHPiVt880y+jya20yx6mphFARP7RIIl1wu
# FS38q9n1Km2/Dc4alxYIvzjjgosZ24P86UY/b8FmUgLXYMSeGlRQFrtoRcxlCioW
# O7gjOPDcmAv4j/fobrAybVYZMlN7cDN1GcOoZESylMoQMBUjSYIrDKqWoT3mIocF
# 3OpfDP9H77sQLhxuu9XBYve1PzQ7nAAOnPrVMWwHE+B6c24U6FwPKlRhS862LKqF
# qz6oOBjDMTHJX9L0/E3KcSlgbq8Bbih4bTHPk6FswzWDC9rq8dG5M8dlgic0Tpka
# /G7UKV/c0ir+MOqDIzt8bCtdOXYwL1EwggVZMIIEQaADAgECAhA9eNf5dklgsmF9
# 9PAeyoYqMA0GCSqGSIb3DQEBCwUAMIHKMQswCQYDVQQGEwJVUzEXMBUGA1UEChMO
# VmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsx
# OjA4BgNVBAsTMShjKSAyMDA2IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6
# ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZlcmlTaWduIENsYXNzIDMgUHVibGljIFBy
# aW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHNTAeFw0xMzEyMTAwMDAw
# MDBaFw0yMzEyMDkyMzU5NTlaMH8xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1h
# bnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29y
# azEwMC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5n
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl4MeABavLLHSCMTX
# aJNRYB5x9uJHtNtYTSNiarS/WhtR96MNGHdou9g2qy8hUNqe8+dfJ04LwpfICXCT
# qdpcDU6kDZGgtOwUzpFyVC7Oo9tE6VIbP0E8ykrkqsDoOatTzCHQzM9/m+bCzFhq
# ghXuPTbPHMWXBySO8Xu+MS09bty1mUKfS2GVXxxw7hd924vlYYl4x2gbrxF4Gpiu
# xFVHU9mzMtahDkZAxZeSitFTp5lbhTVX0+qTYmEgCscwdyQRTWKDtrp7aIIx7mXK
# 3/nVjbI13Iwrb2pyXGCEnPIMlF7AVlIASMzT+KV93i/XE+Q4qITVRrgThsIbnepa
# ON2b2wIDAQABo4IBgzCCAX8wLwYIKwYBBQUHAQEEIzAhMB8GCCsGAQUFBzABhhNo
# dHRwOi8vczIuc3ltY2IuY29tMBIGA1UdEwEB/wQIMAYBAf8CAQAwbAYDVR0gBGUw
# YzBhBgtghkgBhvhFAQcXAzBSMCYGCCsGAQUFBwIBFhpodHRwOi8vd3d3LnN5bWF1
# dGguY29tL2NwczAoBggrBgEFBQcCAjAcGhpodHRwOi8vd3d3LnN5bWF1dGguY29t
# L3JwYTAwBgNVHR8EKTAnMCWgI6Ahhh9odHRwOi8vczEuc3ltY2IuY29tL3BjYTMt
# ZzUuY3JsMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzAOBgNVHQ8BAf8E
# BAMCAQYwKQYDVR0RBCIwIKQeMBwxGjAYBgNVBAMTEVN5bWFudGVjUEtJLTEtNTY3
# MB0GA1UdDgQWBBSWO1PweTOXr32D7y4rzMq3hh5yZjAfBgNVHSMEGDAWgBR/02Wn
# wt3su/AwCfNDOfoCrzMxMzANBgkqhkiG9w0BAQsFAAOCAQEAE4UaHmmpN/egvaSv
# fh1hU/6djF4MpnUeeBcj3f3sGgNVOftxlcdlWqeOMNJEWmHbcG/aIQXCLnO6SfHR
# k/5dyc1eA+CJnj90Htf3OIup1s+7NS8zWKiSVtHITTuC5nmEFvwosLFH8x2iPu6H
# 2aZ/pFalP62ELinefLyoqqM9BAHqupOiDlAiKRdMh+Q6EV/WpCWJmwVrL7TJAUwn
# ewusGQUioGAVP9rJ+01Mj/tyZ3f9J5THujUOiEn+jf0or0oSvQ2zlwXeRAwV+jYr
# A9zBUAHxoRFdFOXivSdLVL4rhF4PpsN0BQrvl8OJIrEfd/O9zUPU8UypP7WLhK9k
# 8tAUITGCEIUwghCBAgEBMIGTMH8xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1h
# bnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29y
# azEwMC4GA1UEAxMnU3ltYW50ZWMgQ2xhc3MgMyBTSEEyNTYgQ29kZSBTaWduaW5n
# IENBAhB333Q9blgqlN8VYTchtwybMA0GCWCGSAFlAwQCAQUAoIGUMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MCgGCisGAQQBgjcCAQwxGjAYoRaAFGh0dHBzOi8vd3d3LnBkcS5jb20gMC8GCSqG
# SIb3DQEJBDEiBCAC2Ff3XaF9dKdX/lbGWuej6SURj/3DHj27K/fHrs1rxjANBgkq
# hkiG9w0BAQEFAASCAQANahXxqMyPktAMTteMu4AMQUpg4Acc5h+x7E3KtAkC7YWm
# wopZ3vSM/JBwuvPIfAa4jBAdya89I11fwCU9Dgs5gX+V1rONq90zJsz1vGiuas7O
# d431O2RccxgbVoKjvSiZ+hSe9LonPCUJ8uLYX0v0NWlszjReDL43B4MRidU14EaS
# 6By/40/lslaYWEfpoxReMN58qSxn6ifKzRYSSGNZ7FRHlGviRBkKmTtZ43gN93oY
# /Ko7xxvV0u1pb0soMyGoc+tiIzlUv+87oTyDwmLe0kt4iy7YzSnxmQ1EOQ0pMBx5
# RMOLg1mbPmSD5ONN5HqgN1IdGk5RBnEFEkzcJR1uoYIOKzCCDicGCisGAQQBgjcD
# AwExgg4XMIIOEwYJKoZIhvcNAQcCoIIOBDCCDgACAQMxDTALBglghkgBZQMEAgEw
# gf4GCyqGSIb3DQEJEAEEoIHuBIHrMIHoAgEBBgtghkgBhvhFAQcXAzAhMAkGBSsO
# AwIaBQAEFKLPFpWnBgUDMd1xtXdTqvvVW+OpAhRvy7r2zFIqcAH8/Rg6MLhZRGX/
# EBgPMjAxNzExMDkwMTQ3MjRaMAMCAR6ggYakgYMwgYAxCzAJBgNVBAYTAlVTMR0w
# GwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMg
# VHJ1c3QgTmV0d29yazExMC8GA1UEAxMoU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFt
# cGluZyBTaWduZXIgLSBHMqCCCoswggU4MIIEIKADAgECAhB7BbHUSWhRRPfJidKc
# GZ0SMA0GCSqGSIb3DQEBCwUAMIG9MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVy
# aVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4
# BgNVBAsTMShjKSAyMDA4IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQg
# dXNlIG9ubHkxODA2BgNVBAMTL1ZlcmlTaWduIFVuaXZlcnNhbCBSb290IENlcnRp
# ZmljYXRpb24gQXV0aG9yaXR5MB4XDTE2MDExMjAwMDAwMFoXDTMxMDExMTIzNTk1
# OVowdzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9u
# MR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMSgwJgYDVQQDEx9TeW1h
# bnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOC
# AQ8AMIIBCgKCAQEAu1mdWVVPnYxyXRqBoutV87ABrTxxrDKPBWuGmicAMpdqTclk
# FEspu8LZKbku7GOz4c8/C1aQ+GIbfuumB+Lef15tQDjUkQbnQXx5HMvLrRu/2JWR
# 8/DubPitljkuf8EnuHg5xYSl7e2vh47Ojcdt6tKYtTofHjmdw/SaqPSE4cTRfHHG
# Bim0P+SDDSbDewg+TfkKtzNJ/8o71PWym0vhiJka9cDpMxTW38eA25Hu/rySV3J3
# 9M2ozP4J9ZM3vpWIasXc9LFL1M7oCZFftYR5NYp4rBkyjyPBMkEbWQ6pPrHM+dYr
# 77fY5NUdbRE6kvaTyZzjSO67Uw7UNpeGeMWhNwIDAQABo4IBdzCCAXMwDgYDVR0P
# AQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwZgYDVR0gBF8wXTBbBgtghkgB
# hvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2IuY29tL2NwczAl
# BggrBgEFBQcCAjAZGhdodHRwczovL2Quc3ltY2IuY29tL3JwYTAuBggrBgEFBQcB
# AQQiMCAwHgYIKwYBBQUHMAGGEmh0dHA6Ly9zLnN5bWNkLmNvbTA2BgNVHR8ELzAt
# MCugKaAnhiVodHRwOi8vcy5zeW1jYi5jb20vdW5pdmVyc2FsLXJvb3QuY3JsMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1l
# U3RhbXAtMjA0OC0zMB0GA1UdDgQWBBSvY9bKo06FcuCnvEHzKaI4f4B1YjAfBgNV
# HSMEGDAWgBS2d/ppSEefUxLVwuoHMnYH0ZcHGTANBgkqhkiG9w0BAQsFAAOCAQEA
# deqwLdU0GVwyRf4O4dRPpnjBb9fq3dxP86HIgYj3p48V5kApreZd9KLZVmSEcTAq
# 3R5hF2YgVgaYGY1dcfL4l7wJ/RyRR8ni6I0D+8yQL9YKbE4z7Na0k8hMkGNIOUAh
# xN3WbomYPLWYl+ipBrcJyY9TV0GQL+EeTU7cyhB4bEJu8LbF+GFcUvVO9muN90p6
# vvPN/QPX2fYDqA/jU/cKdezGdS6qZoUEmbf4Blfhxg726K/a7JsYH6q54zoAv86K
# lMsB257HOLsPUqvR45QDYApNoP4nbRQy/D+XQOG/mYnb5DkUvdrk08PqK1qzlVhV
# BH3HmuwjA42FKtL/rqlhgTCCBUswggQzoAMCAQICEFRY8qrXQdZEvISpe6CWUuYw
# DQYJKoZIhvcNAQELBQAwdzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVj
# IENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMSgw
# JgYDVQQDEx9TeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTE3MDEw
# MjAwMDAwMFoXDTI4MDQwMTIzNTk1OVowgYAxCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3Qg
# TmV0d29yazExMC8GA1UEAxMoU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFtcGluZyBT
# aWduZXIgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJnz/NgE
# CQOG+ddcppPAQnzqfGPPXQDijvPAkN+PKfUY6pS3kuXXsKBzgejpCptKfAH/nY+k
# OacO6kX0Igw6cO05RYvkxRtc8EVoRiQFY3abHPyebCqxVuWKf1JxrvI11UYjBhzP
# SC0dtM242XYjjhz/Pr+7BlxpB6ZlDvhern0u7U2uNe/J1wBC/SiVDp9dckIJvMPa
# RNLtzEeE5PzKLaxYvq73rtlEDQi3wnfWGkNw0W4D3lKSxBAIcdm6IlXyH7ztm507
# 4l4dTIP/lw97C+dVg07SDeu+1+yubke5n9+l1lG8BFXt/ydwTMntKksT4bG5TA/J
# Ae5VZV9pAnhmyz8CAwEAAaOCAccwggHDMAwGA1UdEwEB/wQCMAAwZgYDVR0gBF8w
# XTBbBgtghkgBhvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2Iu
# Y29tL2NwczAlBggrBgEFBQcCAjAZGhdodHRwczovL2Quc3ltY2IuY29tL3JwYTBA
# BgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vdHMtY3JsLndzLnN5bWFudGVjLmNvbS9z
# aGEyNTYtdHNzLWNhLmNybDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8B
# Af8EBAMCB4AwdwYIKwYBBQUHAQEEazBpMCoGCCsGAQUFBzABhh5odHRwOi8vdHMt
# b2NzcC53cy5zeW1hbnRlYy5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly90cy1haWEu
# d3Muc3ltYW50ZWMuY29tL3NoYTI1Ni10c3MtY2EuY2VyMCgGA1UdEQQhMB+kHTAb
# MRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC01MB0GA1UdDgQWBBQJtcH+lnKXKUOa
# yeACuq74/S+69jAfBgNVHSMEGDAWgBSvY9bKo06FcuCnvEHzKaI4f4B1YjANBgkq
# hkiG9w0BAQsFAAOCAQEAF7MKiOlcWl4gazsKFbJsxamKMofTsfQcU66Fvj+b/9e8
# t5SFtMdSfpTove1hstSnmeTDyZPBNT0L6GgKXVaYvbEiO9FEete/8G1RMorVI984
# ATf24lMreisRj7dNbHozAxt8awmUF7vk21jUIRNl5+zRJcosdZqcf/zJuypoq8R9
# tM+jyWyn2cQAnIkKd5H0TaL7MTuGbvbmH1ADhpu/y0Kr5nabcloRAYrG76Vvlefd
# rrrmImXwGFkbEcnNgLfYl0cfQgj4rHEfsEZTs9Sy1aOrUHVIEheCrc/gQU8yfs2V
# HL+Rigg9pKdnApbfJEyl0EHAgmCjihcyS9O8z6S0jDGCAlowggJWAgEBMIGLMHcx
# CzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0G
# A1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEoMCYGA1UEAxMfU3ltYW50ZWMg
# U0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQVFjyqtdB1kS8hKl7oJZS5jALBglghkgB
# ZQMEAgGggaQwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJ
# BTEPFw0xNzExMDkwMTQ3MjRaMC8GCSqGSIb3DQEJBDEiBCCOTRmyDSrxstbAGWfj
# q4OkHtEOFXBBPi7rXcwlmdTagjA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDPesF6
# 0Efs1f3DaCIDGxLU7weLbytMXmukH4/yz0utZzALBgkqhkiG9w0BAQEEggEAQaI6
# 5GOE3O4LgRn6+WslHYlgKs94G/rx1993oT/25G6Jd83WG6kzv55LzSWFqNMPqe1Q
# zYKp8ITnKFxnASsKpWFamQyPm9M7MnZfftAwkptp1yJCQY435uAO5llcaMP3CLhs
# EU6fuPcmFOoUHRgM1JwzAjvvftVb21DsgZgv/09Fzx62S/eljCf2t28XKjM0MZn7
# oJfv8X3hgCntlz/7qX/gROpsQzYFLRadRBEXP9ZVDavCzic4LfgGR0Ybcv3C1CyJ
# +dexSkbc1BhFHEWG+rHPCSFBppIklneAe6m/9EPw1JhU9Ao9qIPE1Cp5X0JOeQSV
# nlSH/PsTzaSnaxzUzg==
# SIG # End signature block
