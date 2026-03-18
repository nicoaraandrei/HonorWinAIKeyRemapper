# Honor AI Key Mapping Script (Short Guide)

This guide covers how to use `honor_ai_key_map.ps1` and what parameters it accepts.

## What the Script Does

- Backs up current Honor AI key settings.
- Maps short press to either:
  - a package launcher activity, or
  - default assistant mode (voice-assist entry path).
- Maps double press to Google Wallet with configurable behavior.
- Supports USB and wireless ADB connection flows.

## Prerequisites

- ADB installed and available in PATH.
- Developer options enabled on phone.
- USB debugging or Wireless debugging enabled.
- For assistant voice behavior:
  - Google app set as default assistant.
  - Gemini selected inside Google app settings.

## Basic Usage

Run in PowerShell from the script folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\honor_ai_key_map.ps1
```

Default behavior now includes:

- `DoublePressMode = Hybrid`
  - unlocked: Wallet GlobalActions
  - lockscreen: Wallet Quickdraw

## Common Command Examples

### 1) Use defaults

```powershell
.\honor_ai_key_map.ps1
```

### 2) Force USB mode

```powershell
.\honor_ai_key_map.ps1 -ConnectionMode USB
```

### 3) Wireless with explicit values

```powershell
.\honor_ai_key_map.ps1 -ConnectionMode Wireless -WirelessIP 192.168.0.103 -WirelessPort 37787 -PairingPort 37787 -PairCode 435416
```

### 4) Short press to default assistant mode

```powershell
.\honor_ai_key_map.ps1 -ShortPressMode DefaultAssistant
```

### 5) Short press to custom package

```powershell
.\honor_ai_key_map.ps1 -ShortPressMode Package -ShortPressPackage com.parallelc.vistrigger
```

### 6) Test wallet double-press modes

```powershell
.\honor_ai_key_map.ps1 -DoublePressMode Quickdraw
.\honor_ai_key_map.ps1 -DoublePressMode GlobalActions
.\honor_ai_key_map.ps1 -DoublePressMode Component
.\honor_ai_key_map.ps1 -DoublePressMode Hybrid
```

## Parameters

| Parameter | Type | Allowed values | Default | Notes |
|---|---|---|---|---|
| `ConnectionMode` | string | `Auto`, `USB`, `Wireless` | `Auto` | In `Auto`, script prompts; Enter selects USB. |
| `ShortPressPackage` | string | any package name | `com.parallelc.vistrigger` | Used when `ShortPressMode=Package`. |
| `ShortPressMode` | string | `Package`, `DefaultAssistant` | `Package` | `DefaultAssistant` uses Google voice-assist entry path. |
| `DoublePressMode` | string | `Quickdraw`, `GlobalActions`, `Component`, `Hybrid` | `Hybrid` | `Hybrid` = unlocked GlobalActions + lockscreen Quickdraw. |
| `WirelessIP` | string | IPv4/host | none | Optional. Prompted if missing in wireless mode. |
| `WirelessPort` | int | numeric port | none | ADB connect port from Wireless debugging screen. |
| `PairingPort` | int | numeric port | none | Optional pairing port. |
| `PairCode` | string | pairing code | none | Optional pairing code. |

## DoublePressMode Behavior Summary

- `Quickdraw`: both unlocked and lockscreen use QUICKDRAW action.
- `GlobalActions`: both unlocked and lockscreen use GLOBALACTIONS action.
- `Component`: both unlocked and lockscreen use Wallet component intent.
- `Hybrid`: unlocked uses GLOBALACTIONS, lockscreen uses QUICKDRAW.

## Direct ADB Commands (Without Script)

Use these from PowerShell if you want to write mappings directly.

```powershell
# Optional: select a target device when multiple are connected
# $env:ANDROID_SERIAL = "<device-serial>"
```

## Tips:

You can also use in a separate powershell window the following command to check if the command has worked or if the provided json has errors and couldn't be parsed:
```powershell
adb logcat | Select-String -Pattern "ai_key|Aikey"
```

### 0) Raw ADB Commands Equivalent to Running Script With No Parameters (In case you don't want to run the script):

When you run `./honor_ai_key_map.ps1` with defaults:

- `ShortPressMode=Package`
- `ShortPressPackage=com.parallelc.vistrigger`
- `DoublePressMode=Hybrid`

Use these raw writes to match that default behavior:

```powershell
# Default short press (VisTrigger package/component)
adb --% shell settings put global ai_key_short_service_info '{"commonIntent":"intent:#Intent;package\u003dcom.parallelc.vistrigger;component\u003dcom.parallelc.vistrigger/com.parallelc.micts.ui.activity.MainActivity\u003bend","isSubService":false,"isSupportScreenLockStart":"1","launchAnim":"0","lockScreenIntent":"intent:#Intent;package\u003dcom.parallelc.vistrigger;component\u003dcom.parallelc.vistrigger/com.parallelc.micts.ui.activity.MainActivity\u003bend","packageName":"com.parallelc.vistrigger","serviceId":"ai_shorthand","startType":0}'

# Default double press (Hybrid: unlocked GlobalActions, lockscreen Quickdraw)
adb --% shell settings put global ai_key_double_click_service_info '{"commonIntent":"intent:#Intent;action\u003dcom.google.android.apps.wallet.globalactions.START;package\u003dcom.google.android.apps.walletnfcrel\u003bend","isSubService":false,"isSupportScreenLockStart":"1","launchAnim":"1","lockScreenIntent":"intent:#Intent;action\u003dcom.google.android.apps.wallet.main.QUICKDRAW;package\u003dcom.google.android.apps.walletnfcrel\u003bend","packageName":"com.google.android.apps.walletnfcrel","serviceId":"google_wallet","startType":0}'
```

If your VisTrigger launcher activity differs, resolve it first:

```powershell
adb shell cmd package resolve-activity --brief com.parallelc.vistrigger
```

### 1) Short Press -> Custom Package/Component

Replace `com.example.app` and `.MainActivity` with your target app.

```powershell
adb --% shell settings put global ai_key_short_service_info '{"commonIntent":"intent:#Intent;package\u003dcom.example.app;component\u003dcom.example.app/.MainActivity\u003bend","isSubService":false,"isSupportScreenLockStart":"1","launchAnim":"0","lockScreenIntent":"intent:#Intent;package\u003dcom.example.app;component\u003dcom.example.app/.MainActivity\u003bend","packageName":"com.example.app","serviceId":"ai_shorthand","startType":0}'
```

### 2) Double Press -> Custom Package/Component

Replace `com.example.wallet` and `.MainActivity` with your target app.

```powershell
adb --% shell settings put global ai_key_double_click_service_info '{"commonIntent":"intent:#Intent;package\u003dcom.example.wallet;component\u003dcom.example.wallet/.MainActivity\u003bend","isSubService":false,"isSupportScreenLockStart":"1","launchAnim":"1","lockScreenIntent":"intent:#Intent;package\u003dcom.example.wallet;component\u003dcom.example.wallet/.MainActivity\u003bend","packageName":"com.example.wallet","serviceId":"google_wallet","startType":0}'
```

### 3) Double Press Wallet Hybrid Example

This matches script `Hybrid` behavior: unlocked `GlobalActions`, lockscreen `Quickdraw`.

```powershell
adb --% shell settings put global ai_key_double_click_service_info '{"commonIntent":"intent:#Intent;action\u003dcom.google.android.apps.wallet.globalactions.START;package\u003dcom.google.android.apps.walletnfcrel\u003bend","isSubService":false,"isSupportScreenLockStart":"1","launchAnim":"1","lockScreenIntent":"intent:#Intent;action\u003dcom.google.android.apps.wallet.main.QUICKDRAW;package\u003dcom.google.android.apps.walletnfcrel\u003bend","packageName":"com.google.android.apps.walletnfcrel","serviceId":"google_wallet","startType":0}'
```

### 4) Verify Current Values

```powershell
adb shell settings get global ai_key_short_service_info
adb shell settings get global ai_key_double_click_service_info
```

## Output Files

Each run creates:

- backup text file next to the script
- restore PowerShell script next to the script

Use the generated restore script to revert mappings.
