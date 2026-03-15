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

## Output Files

Each run creates:

- backup text file next to the script
- restore PowerShell script next to the script

Use the generated restore script to revert mappings.
