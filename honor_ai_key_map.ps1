<#
Honor AI Key Mapping Script

Quick usage:
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\honor_ai_key_map.ps1

Defaults:
    ConnectionMode  = Auto
    ShortPressMode  = Package
    ShortPressPackage = com.parallelc.vistrigger
    DoublePressMode = Hybrid

Parameters:
    -ConnectionMode    Auto|USB|Wireless
    -ShortPressMode    Package|DefaultAssistant
    -ShortPressPackage <package>
    -DoublePressMode   Quickdraw|GlobalActions|Component|Hybrid
    -WirelessIP        <ip>
    -WirelessPort      <port>
    -PairingPort       <port>
    -PairCode          <code>

Notes:
    - DefaultAssistant uses Google voice-assist entry behavior.
    - Hybrid wallet mode = unlocked GlobalActions + lockscreen Quickdraw.
    - Each run creates backup/restore files next to this script.
#>

Param(
    [ValidateSet('Auto', 'USB', 'Wireless')]
    [string]$ConnectionMode = 'Auto',
    [string]$ShortPressPackage = 'com.parallelc.vistrigger',
    [ValidateSet('Package', 'DefaultAssistant')]
    [string]$ShortPressMode = 'Package',
    [ValidateSet('Quickdraw', 'GlobalActions', 'Component', 'Hybrid')]
    [string]$DoublePressMode = 'Hybrid',
    [string]$WirelessIP,
    [int]$WirelessPort,
    [int]$PairingPort,
    [string]$PairCode
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Adb {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        throw "ADB not found in PATH. Install Android Platform Tools and ensure 'adb' is available."
    }
}

function Start-AdbServer {
    & adb kill-server | Out-Null
    & adb start-server | Out-Null
}

function Get-DevicesRaw {
    & adb devices
}

function Get-AuthorizedDevices {
    $raw = Get-DevicesRaw
    $lines = $raw -split "`n" | ForEach-Object { $_.Trim() }
    $serials = @()
    foreach ($l in $lines) {
        if ($l -match '^(?<s>\S+)\s+device$' -and ($l -notmatch '^List of devices')) {
            $serials += ($Matches['s'])
        }
    }
    return ,$serials
}

function Get-AnyDevices {
    $raw = Get-DevicesRaw
    $lines = $raw -split "`n" | ForEach-Object { $_.Trim() }
    $serials = @()
    foreach ($l in $lines) {
        if ($l -match '^(?<s>\S+)\s+(device|offline|unauthorized)$' -and ($l -notmatch '^List of devices')) {
            $serials += ($Matches['s'] + ' ' + ($l -replace '^\S+\s+', ''))
        }
    }
    return ,$serials
}

function Read-WirelessInfo {
    Write-Host "\nWireless ADB helper: provide details from Settings > Developer options > Wireless debugging" -ForegroundColor Cyan

    if (-not $script:WirelessIP) {
        $script:WirelessIP = Read-Host "Phone IP address (e.g., 192.168.0.57)"
    }

    if (-not $script:PairingPort) {
        $pp = Read-Host "Pairing port (from Pair device with pairing code) - optional"
        if ($pp) { $script:PairingPort = [int]$pp }
    }

    if (-not $script:PairCode -and $script:PairingPort) {
        $script:PairCode = Read-Host "6-digit pairing code"
    }

    if (-not $script:WirelessPort) {
        $cp = Read-Host "Connection port (shown as IP address and port) - press Enter to reuse pairing port"
        if ($cp) {
            $script:WirelessPort = [int]$cp
        } elseif ($script:PairingPort) {
            $script:WirelessPort = $script:PairingPort
        }
    }
}

function Select-TargetDevice {
    param(
        [string[]]$AuthorizedDevices
    )

    if ($AuthorizedDevices.Count -gt 1) {
        Write-Host "Multiple devices detected:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $AuthorizedDevices.Count; $i++) { Write-Host "[$i] $($AuthorizedDevices[$i])" }
        $idx = [int](Read-Host "Select index to target")
        $sel = $AuthorizedDevices[$idx]
        Write-Host "Targeting $sel"
        $env:ANDROID_SERIAL = $sel
    } else {
        $env:ANDROID_SERIAL = $AuthorizedDevices[0]
    }
}

function Resolve-ConnectionMode {
    if ($ConnectionMode -ne 'Auto') {
        return $ConnectionMode
    }

    $choice = Read-Host "Connection mode (USB/Wireless). Press Enter for USB"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        return 'USB'
    }

    switch ($choice.Trim().ToLowerInvariant()) {
        'usb' { return 'USB' }
        'wireless' { return 'Wireless' }
        default { throw "Invalid connection mode '$choice'. Use USB or Wireless." }
    }
}

function Confirm-DeviceConnected {
    Start-AdbServer

    $auth = Get-AuthorizedDevices
    if ($auth.Count -gt 0) {
        Select-TargetDevice -AuthorizedDevices $auth
        return
    }

    $effectiveMode = Resolve-ConnectionMode

    if ($effectiveMode -eq 'USB') {
        throw "No authorized USB device found. Connect phone via USB, accept debugging prompt, then run again (or use -ConnectionMode Wireless)."
    }

    # If the user provided IP/ports by parameters, use them; otherwise prompt.
    if (-not $WirelessIP) { Read-WirelessInfo }

    if ($PairingPort -and $PairCode) {
        Write-Host ("Pairing with {0}:{1} ..." -f $WirelessIP, $PairingPort)
        try {
            $pairTarget = "{0}:{1}" -f $WirelessIP, $PairingPort
            $pairOut = & adb pair $pairTarget $PairCode
            Write-Host $pairOut
            if ($pairOut -notmatch 'Successfully paired') {
                Write-Warning "Pairing did not report success. You can continue if already paired."
            }
        } catch {
            Write-Warning "Pairing command failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "Skipping pairing (no pairing port/code provided). Assuming previously paired."
    }

    if (-not $WirelessPort) {
        $WirelessPort = Read-Host "Enter connection port (as shown under Wireless debugging 'IP address & port')"
    }

    Write-Host ("Connecting to {0}:{1} ..." -f $WirelessIP, $WirelessPort)
    $connectTarget = "{0}:{1}" -f $WirelessIP, $WirelessPort
    $connOut = & adb connect $connectTarget
    Write-Host $connOut

    Start-Sleep -Seconds 1
    $auth = Get-AuthorizedDevices
    if ($auth.Count -eq 0) {
        $any = Get-AnyDevices -join "; "
        throw "No authorized device after wireless connect. adb devices: $any. Accept the 'Allow USB debugging' prompt on the phone (wireless) and run again."
    }

    Select-TargetDevice -AuthorizedDevices $auth
}

function Get-LaunchableComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $resolved = (& adb shell cmd package resolve-activity --brief $PackageName 2>$null) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }

    $component = $resolved | Where-Object { $_ -match '/' } | Select-Object -Last 1
    if (-not $component -or $component -match '^No activity found') {
        throw "Could not resolve launcher activity for '$PackageName'. Share 'adb shell dumpsys package $PackageName' output and I can wire it exactly."
    }

    return $component
}

function Get-DefaultAssistantComponent {
    # Prefer Google voice assist entry point to avoid generic assistant routes
    # that may open Lens on some ROMs.
    $gsbPkg = 'com.google.android.googlequicksearchbox'
    $voiceAssistEntry = "$gsbPkg/.GoogleAppVoiceAssistEntrypoint"
    $pkgDump = & adb shell dumpsys package $gsbPkg 2>$null
    if ($pkgDump -match [regex]::Escape($voiceAssistEntry)) {
        $voiceIntent = "intent:#Intent;action\u003dandroid.intent.action.VOICE_ASSIST;package\u003d$gsbPkg;component\u003d$voiceAssistEntry\u003bend"
        return @{ Package = $gsbPkg; Component = $voiceAssistEntry; IntentUri = $voiceIntent }
    }

    # Next prefer Google assistant gateway entry point.
    # This is the closest non-Xposed equivalent to MiCTS/VISTrigger behavior.
    $assistGateway = "$gsbPkg/.GoogleAppImplicitActionAssistGatewayInternal"
    $pkgDump = & adb shell dumpsys package $gsbPkg 2>$null
    if ($pkgDump -match [regex]::Escape($assistGateway)) {
        $assistIntent = "intent:#Intent;action\u003dandroid.intent.action.ASSIST;package\u003d$gsbPkg;component\u003d$assistGateway\u003bend"
        return @{ Package = $gsbPkg; Component = $assistGateway; IntentUri = $assistIntent }
    }

    # Then prefer Gemini app launcher if installed
    $geminiPkg = 'com.google.android.apps.bard'
    $geminiPath = (& adb shell pm path $geminiPkg 2>$null).Trim()
    if ($geminiPath -match 'package:') {
        try {
            $component = Get-LaunchableComponent -PackageName $geminiPkg
            return @{ Package = $geminiPkg; Component = $component }
        } catch { }
    }

    # Fall back to Google voice assistant entry point (Robin / Google Assistant voice)
    $voiceActivity = "$gsbPkg/com.google.android.apps.search.assistant.surfaces.voice.robin.launcher.RobinEntryPointActivity"
    $pkgDump = & adb shell dumpsys package $gsbPkg 2>$null
    if ($pkgDump -match [regex]::Escape($voiceActivity)) {
        return @{ Package = $gsbPkg; Component = $voiceActivity }
    }

    # Last resort: whatever is set as default assistant
    $componentStr = (& adb shell settings get secure assistant 2>$null).Trim()
    if (-not $componentStr -or $componentStr -eq 'null') {
        throw "No default assistant configured. Set one in Settings > Apps > Default apps > Digital assistant app."
    }
    $pkg = ($componentStr -split '/')[0]
    return @{ Package = $pkg; Component = $componentStr }
}

function Get-PreferredWalletComponent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $preferred = "$PackageName/com.google.android.apps.wallet.GooglePayActivity"
    $pkgDump = & adb shell dumpsys package $PackageName 2>$null
    if ($pkgDump -match [regex]::Escape($preferred)) {
        return $preferred
    }

    return Get-LaunchableComponent -PackageName $PackageName
}

try {
    Assert-Adb
    Confirm-DeviceConnected

    $timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $backupPath  = Join-Path $outputDir ("honor_ai_key_backup_" + $timestamp + ".txt")
    $restorePath = Join-Path $outputDir ("honor_ai_key_restore_" + $timestamp + ".ps1")

    Write-Host "Backing up current AI key settings..."
    $shortCur  = (& adb shell settings get global ai_key_short_service_info).Trim()
    $doubleCur = (& adb shell settings get global ai_key_double_click_service_info).Trim()
    $longCur   = (& adb shell settings get global ai_key_long_service_info).Trim()

    "ai_key_short_service_info=$shortCur"              | Set-Content -Encoding UTF8 $backupPath
    "ai_key_double_click_service_info=$doubleCur"     | Add-Content -Encoding UTF8 $backupPath
    "ai_key_long_service_info=$longCur"               | Add-Content -Encoding UTF8 $backupPath

    # Restore helper script
    $restoreBody = @"
# Restore Honor AI key mappings (generated $timestamp)
# Usage: Right-click > Run with PowerShell (device must be connected via ADB)
# If using wireless ADB, ensure 'adb connect <ip>:<port>' beforehand.
adb --% shell settings put global ai_key_short_service_info '$shortCur'
adb --% shell settings put global ai_key_double_click_service_info '$doubleCur'
adb --% shell settings put global ai_key_long_service_info '$longCur'
"@
    Set-Content -Encoding UTF8 $restorePath $restoreBody

    Write-Host "Backup saved to: $backupPath"
    Write-Host "Restore script saved to: $restorePath"

    # ===== Desired mappings =====
    $shortIntentUri = $null
    if ($ShortPressMode -eq 'DefaultAssistant') {
        $assistantInfo    = Get-DefaultAssistantComponent
        $resolvedShortPkg = $assistantInfo.Package
        $shortPressComponent = $assistantInfo.Component
        if ($assistantInfo.ContainsKey('IntentUri')) {
            $shortIntentUri = [string]$assistantInfo['IntentUri']
        }
    } else {
        $resolvedShortPkg    = $ShortPressPackage
        $shortPressComponent = Get-LaunchableComponent -PackageName $ShortPressPackage
    }
    $walletPackage = 'com.google.android.apps.walletnfcrel'
    $walletComponent = Get-PreferredWalletComponent -PackageName $walletPackage
    $walletQuickdrawIntent = "intent:#Intent;action\u003dcom.google.android.apps.wallet.main.QUICKDRAW;package\u003d$walletPackage\u003bend"
    $walletGlobalActionsIntent = "intent:#Intent;action\u003dcom.google.android.apps.wallet.globalactions.START;package\u003d$walletPackage\u003bend"
    $walletComponentIntent = "intent:#Intent;package\u003d$walletPackage;component\u003d$walletComponent\u003bend"

    $walletCommonIntent = switch ($DoublePressMode) {
        'Quickdraw'     { $walletQuickdrawIntent }
        'GlobalActions' { $walletGlobalActionsIntent }
        'Component'     { $walletComponentIntent }
        'Hybrid'        { $walletGlobalActionsIntent }
    }

    $walletLockscreenIntent = switch ($DoublePressMode) {
        'Quickdraw'     { $walletQuickdrawIntent }
        'GlobalActions' { $walletGlobalActionsIntent }
        'Component'     { $walletComponentIntent }
        'Hybrid'        { $walletQuickdrawIntent }
    }

    $lockSupport = '1'

    $shortCommonIntent = if ($shortIntentUri) {
        $shortIntentUri
    } else {
        "intent:#Intent;package\u003d$resolvedShortPkg;component\u003d$shortPressComponent\u003bend"
    }

    $shortLockIntent = if ($shortIntentUri) {
        $shortIntentUri
    } else {
        "intent:#Intent;package\u003d$resolvedShortPkg;component\u003d$shortPressComponent\u003bend"
    }

    $shortJson = @"
{"commonIntent":"$shortCommonIntent","isSubService":false,"isSupportScreenLockStart":"$lockSupport","launchAnim":"0","lockScreenIntent":"$shortLockIntent","packageName":"$resolvedShortPkg","serviceId":"ai_shorthand","startType":0}
"@.Trim()

    $doubleJson = @"
{"commonIntent":"$walletCommonIntent","isSubService":false,"isSupportScreenLockStart":"$lockSupport","launchAnim":"1","lockScreenIntent":"$walletLockscreenIntent","packageName":"$walletPackage","serviceId":"google_wallet","startType":0}
"@.Trim()

    if ($ShortPressMode -eq 'DefaultAssistant') {
        Write-Host "DefaultAssistant mode note: for Gemini Ask-about-screen behavior, set Google as default assistant and choose Gemini inside Google app settings." -ForegroundColor Yellow
    }

    Write-Host "Applying Short press -> $resolvedShortPkg ($ShortPressMode) ..."
    $shortPutScript = @"
settings put global ai_key_short_service_info "`$(cat <<'JSON'
$shortJson
JSON
)"
"@
    $shortPutScript | & adb shell

    Write-Host "Applying Double press -> Google Wallet ..."
    $doublePutScript = @"
settings put global ai_key_double_click_service_info "`$(cat <<'JSON'
$doubleJson
JSON
)"
"@
    $doublePutScript | & adb shell

    Write-Host "Verifying..."
    $shortNew  = (& adb shell settings get global ai_key_short_service_info).Trim()
    $doubleNew = (& adb shell settings get global ai_key_double_click_service_info).Trim()

    Write-Host "Short press setting:"  $shortNew
    Write-Host "Double press setting:" $doubleNew

    Write-Host "Done. Test the AI key: short = $resolvedShortPkg, double = Wallet."
    Write-Host "If needed, run the restore script: $restorePath"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
