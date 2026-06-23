# Org VM Apps tag strategy

The VM Apps catalog should expose deployment intent and let Aria Automation resolve the concrete infrastructure through tags. This keeps the catalog item stable when networks, storage profiles, datastores, or cloud zones change.

## Required tags

Apply these tags to the VM Apps organization infrastructure mappings before installing the catalog item:

| Intent | Tag format | Apply to |
| --- | --- | --- |
| Placement | `vmapps.location:<location>` | Cloud Zone / compute placement |
| Network | `vmapps.network:<network>` | Network profile or existing network |
| Storage | `vmapps.storage:<tier>` | Storage profile / datastore |
| Flavor | `vmapps.flavor:<size>` | Flavor mapping |

## Current catalog values

| Input | Values |
| --- | --- |
| `location` | `mgmt`, `wl1`, `wl2` |
| `network` | `default`, `app`, `mgmt` |
| `storageTier` | `standard`, `performance`, `capacity` |
| `flavor` | `small`, `medium`, `large` |

## Notes

- The `flavor` input must still match an Aria Automation flavor mapping name, for example `small`, `medium`, or `large`. The matching tag is kept as the infrastructure contract and deployment metadata.
- The blueprint records the selected tag intent in outputs, custom properties, and the post-deployment payload for validation and lifecycle automation.
- If a deployment fails during allocation, check that the selected intent has exactly one valid resolution path across Cloud Zone, network, storage, and flavor mappings.
