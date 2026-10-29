import { abilityAccessCtrl, common } from '@kit.AbilityKit';

/** Runtime permission for BLE. Already-granted requests return immediately. */
export async function ensureBluetoothPermission(context: common.UIAbilityContext): Promise<boolean> {
  try {
    const manager = abilityAccessCtrl.createAtManager();
    const result = await manager.requestPermissionsFromUser(context, ['ohos.permission.ACCESS_BLUETOOTH']);
    if (result.authResults.length > 0 && result.authResults[0] === 0) {
      return true;
    }
    return false;
  } catch (error) {
    return false;
  }
}
