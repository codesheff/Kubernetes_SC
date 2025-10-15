# Migration Summary: ig-all.yml → ig-itosbl.yml

## Files Updated

The following files have been updated to use `ig-itosbl.yml` instead of `ig-all.yml`:

### 1. `ingress-test/deploy-and-test.sh`
- ✅ Updated to deploy `ig-itosbl.yml`
- ✅ Updated cleanup to remove `ig-itosbl.yml`
- ✅ Updated file existence checks
- ✅ Added itosbl.com endpoints to test suite

### 2. `ingress-test/README.md`
- ✅ Updated file description to mention both domains
- ✅ Updated kubectl commands to use `ig-itosbl.yml`
- ✅ Added itosbl.com routing examples
- ✅ Updated ingress routing documentation

### 3. `ingress-test/setup-ingress-prerequisites.sh`
- ✅ Updated next steps to reference `ig-itosbl.yml`
- ✅ Added itosbl.com curl test examples

### 4. `test-ingress-windows.ps1`
- ✅ Updated manual test commands to include itosbl.com
- ✅ Added itosbl.com URLs to test documentation

### 5. `ingress-test/migrate-to-itosbl.ps1` (NEW)
- ✅ Created migration script for safe transition
- ✅ Includes backup, rollback, and dry-run capabilities
- ✅ Provides step-by-step migration guidance

## Migration Process

To migrate from `ig-all.yml` to `ig-itosbl.yml`:

```powershell
# From the ingress-test directory
cd ingress-test

# Show migration plan
.\migrate-to-itosbl.ps1

# Perform dry run
.\migrate-to-itosbl.ps1 -DryRun

# Execute migration
.\migrate-to-itosbl.ps1 -Apply

# If needed, rollback
.\migrate-to-itosbl.ps1 -Rollback
```

## What Changes

### BEFORE (ig-all.yml)
- Supported only `mcu.com` domain
- Host routing: `shield.mcu.com`, `hydra.mcu.com`
- Path routing: `mcu.com/shield`, `mcu.com/hydra`

### AFTER (ig-itosbl.yml)
- Supports BOTH `mcu.com` AND `itosbl.com` domains
- Host routing: `shield.mcu.com`, `hydra.mcu.com`, `shield.itosbl.com`, `hydra.itosbl.com`
- Path routing: `mcu.com/shield`, `mcu.com/hydra`, `itosbl.com/shield`, `itosbl.com/hydra`
- Maintains full backward compatibility

## Benefits

✅ **Backward Compatible**: All existing mcu.com URLs continue to work
✅ **Multi-Domain Support**: Adds itosbl.com domain support
✅ **Zero Downtime**: Same backend services, just more routing rules
✅ **Future Proof**: Easy to add more domains later
✅ **Consistent Experience**: Same applications available on both domains

## DNS Configuration Required

After migration, configure these DNS records:

```
A Record: itosbl.com → 146.198.242.247
A Record: shield.itosbl.com → 146.198.242.247
A Record: hydra.itosbl.com → 146.198.242.247
A Record: *.itosbl.com → 146.198.242.247
```

## Testing After Migration

Test both domains work:

```bash
# MCU.com domain (should still work)
curl -H 'Host: shield.mcu.com' http://146.198.242.247
curl -H 'Host: hydra.mcu.com' http://146.198.242.247
curl -H 'Host: mcu.com' http://146.198.242.247/shield
curl -H 'Host: mcu.com' http://146.198.242.247/hydra

# ITOSBL.com domain (new functionality)
curl -H 'Host: shield.itosbl.com' http://146.198.242.247
curl -H 'Host: hydra.itosbl.com' http://146.198.242.247
curl -H 'Host: itosbl.com' http://146.198.242.247/shield
curl -H 'Host: itosbl.com' http://146.198.242.247/hydra
```

## Rollback Plan

If issues occur, rollback is simple:

```powershell
.\migrate-to-itosbl.ps1 -Rollback
```

Or manually:
```bash
kubectl delete -f ig-itosbl.yml
kubectl apply -f ig-all.yml
```

The migration maintains service continuity while adding new domain support.