import type { UploadIntentToken } from "./token";
import { canImmediatelyDelete } from "./lifecycle";
import { isMediaKeyReferenced } from "./references-server";
import { deleteR2UploadObject, headR2UploadObject } from "./r2-server";

async function remainsUnreferencedAfterSecondCheck(key: string) {
  if (await isMediaKeyReferenced(key)) return false;
  return !(await isMediaKeyReferenced(key));
}

export async function deleteOwnedPendingAfterReferenceCheck(
  intent: UploadIntentToken,
  reason: "failed-upload" | "promoted-pending"
) {
  await headR2UploadObject(intent.key);
  const unreferenced = await remainsUnreferencedAfterSecondCheck(intent.key);
  if (!canImmediatelyDelete({
    reason,
    ownership: "verified",
    referenceCheck: unreferenced ? "unreferenced" : "referenced",
  })) return false;
  await deleteR2UploadObject(intent.key);
  return true;
}
