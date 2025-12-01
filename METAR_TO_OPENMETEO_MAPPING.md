# METAR to Open-Meteo Code Mapping

This document explains how METAR weather conditions are converted to Open-Meteo weather codes and icons in the SkyPulse app.

## METAR Weather Phenomena Codes

| METAR Code | Description | Mapped Code | Day Icon | Night Icon | Interpretation |
|------------|-------------|------------|----------|-----------|-----------------|
| **TS** | Thunderstorm | 95 | ⛈️ | ⛈️ | Severe weather - highest priority |
| **TSRA** | Thunderstorm with Rain | 95 | ⛈️ | ⛈️ | Combined thunderstorm |
| **TSGR** | Thunderstorm with Hail | 96 | ⛈️ | ⛈️ | Severe with hail |

| **SN** | Snow | 71 | ❄️ | ❄️ | Snow precipitation |
| **SG** | Snow Grains | 77 | 🌨️ | 🌨️ | Light snow particles |
| **RASN** | Rain and Snow | 71 | ❄️ | ❄️ | Mixed precipitation - snow dominant |

| **RA** | Rain | 61 | 🌧️ | 🌧️ | General rain |
| **-RA** | Light Rain | 61 | 🌧️ | 🌧️ | Light rain shower |
| **+RA** | Heavy Rain | 61 | 🌧️ | 🌧️ | Heavy rain shower |
| **SHRA** | Rain Showers | 80 | 🌧️ | 🌧️ | Shower activity |

| **DZ** | Drizzle | 51 | 🌦️ | 🌦️ | Light precipitation |
| **-DZ** | Light Drizzle | 51 | 🌦️ | 🌦️ | Very light precipitation |

| **FG** | Fog | 45 | 🌫️ | 🌫️ | Dense fog (visibility < 1 km) |
| **BR** | Mist | 45 | 🌫️ | 🌫️ | Mist (visibility 1-10 km) |

| **HZ** | Haze | 1 | 🌤️ | 🌙 | Reduced visibility due to suspended particles |
| **VA** | Volcanic Ash | 3 | ☁️ | ☁️ | Ash particles in air |
| **DU** | Dust | 3 | ☁️ | ☁️ | Dust storm conditions |
| **SA** | Sand | 3 | ☁️ | ☁️ | Sand storm conditions |
| **PY** | Spray | 3 | ☁️ | ☁️ | Sea spray conditions |

## Open-Meteo Cloud Coverage Codes

When no significant weather phenomena present, METAR cloud cover is used:

| Cloud Code | Description | Mapped Code | Day Icon | Night Icon |
|-----------|-------------|-----------|----------|-----------|
| **OVC** | Overcast (8/8 coverage) | 3 | ☁️ | ☁️ |
| **BKN** | Broken (5-7/8 coverage) | 3 | ☁️ | ☁️ |
| **SCT** | Scattered (3-4/8 coverage) | 2 | ⛅ | 🌙 |
| **FEW** | Few (1-2/8 coverage) | 1 | 🌤️ | 🌙 |
| **SKC** | Sky Clear | 0 | ☀️ | 🌙 |
| **CLR** | Clear | 0 | ☀️ | 🌙 |
| **NSC** | No Sky Condition | 0 | ☀️ | 🌙 |

## Priority Order (as implemented)

The METAR code mapping follows this severity priority:

1. **Thunderstorms** (TS, THUNDER) → Code 95
2. **Snow** (SN, SNOW, SG) → Code 71/77
3. **Rain** (RA, SHRA, RASN) → Code 61/80
4. **Drizzle** (DZ) → Code 51
5. **Fog** (FG, FOG) → Code 45
6. **Mist** (BR, MIST) → Code 45
7. **Haze** (HZ, HAZE) → Code 1
8. **Dust/Ash** (VA, DU, SA, PY) → Code 3
9. **Cloud cover** (if no phenomena)

## Example METAR Strings

```
OIMM 291900Z 27015KT 9999 FG BKN020 OVC050 15/08 Q1013
  → Weather Condition: "FG" → Code 45 → Icon: 🌫️

OPKC 291830Z 31008KT 10000 RA BKN030 OVC080 28/24 Q1010
  → Weather Condition: "RA" → Code 61 → Icon: 🌧️

OPMR 291900Z 00000KT 10000 SKC 32/20 Q1012
  → Weather Condition: None → Cloud: "SKC" → Code 0 → Icon: ☀️/🌙

OPMR 291900Z 27010KT 4000 TSRA OVC015 18/16 Q1011
  → Weather Condition: "TSRA" → Code 95 → Icon: ⛈️
```

## Implementation Details

- **Fog & Mist** now correctly mapped to Code 45 (was incorrectly Code 1)
- **Haze** mapped to Code 1 (appropriate for light visibility reduction)
- **Night mode** properly shows weather phenomena (rain, snow, storms) with correct icons
- **METAR priority** ensures most significant weather is displayed
- **Cloud cover fallback** used when no weather phenomena reported

## Integration with App UI

When METAR data arrives:
1. Weather code is determined from METAR condition
2. Corresponding icon is displayed based on code + time of day
3. Weather description shown from Open-Meteo code interpretation
4. METAR badge displayed to show real-time airport data is active
