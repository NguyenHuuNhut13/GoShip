// Dịch vụ kết nối trực tiếp 2 chiều với Firebase Cloud Firestore (Project: goship-145a0)
// Đồng bộ 100% với App Mobile Flutter (Khách hàng, Tài xế & Mobile Admin)

const PROJECT_ID = 'goship-145a0';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Chuyển đổi Firestore Value sang JS Value
export function parseFirestoreValue(val: any): any {
  if (!val || typeof val !== 'object') return null;
  if ('stringValue' in val) return val.stringValue;
  if ('integerValue' in val) return Number(val.integerValue);
  if ('doubleValue' in val) return Number(val.doubleValue);
  if ('booleanValue' in val) return Boolean(val.booleanValue);
  if ('timestampValue' in val) return val.timestampValue;
  if ('nullValue' in val) return null;
  if ('arrayValue' in val) {
    const values = val.arrayValue?.values || [];
    return values.map(parseFirestoreValue);
  }
  if ('mapValue' in val) {
    const fields = val.mapValue?.fields || {};
    const obj: Record<string, any> = {};
    for (const k of Object.keys(fields)) {
      obj[k] = parseFirestoreValue(fields[k]);
    }
    return obj;
  }
  return null;
}

// Chuyển đổi Firestore Document sang JS Object
export function parseFirestoreDoc(doc: any): Record<string, any> {
  const nameParts = (doc.name || '').split('/');
  const docId = nameParts[nameParts.length - 1] || '';
  const fields = doc.fields || {};
  const result: Record<string, any> = { _docId: docId, _UpdatedAt: doc.updateTime };
  for (const key of Object.keys(fields)) {
    result[key] = parseFirestoreValue(fields[key]);
  }
  return result;
}

// Chuyển đổi JS Value sang Firestore Value
export function toFirestoreValue(val: any): any {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: String(val) };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields: Record<string, any> = {};
    for (const k of Object.keys(val)) {
      if (val[k] !== undefined) {
        fields[k] = toFirestoreValue(val[k]);
      }
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

// Đọc toàn bộ danh sách tài liệu của 1 collection từ Cloud Firestore
export async function fetchCollection(collectionName: string, pageSize = 200): Promise<Record<string, any>[]> {
  try {
    const res = await fetch(`${BASE_URL}/${collectionName}?pageSize=${pageSize}`);
    if (!res.ok) return [];
    const data = await res.json();
    const docs = data.documents || [];
    return docs.map(parseFirestoreDoc);
  } catch (err) {
    console.warn(`[FirestoreCloud] fetchCollection(${collectionName}) warning:`, err);
    return [];
  }
}

// Đọc 1 tài liệu cụ thể từ Cloud Firestore
export async function fetchDocument(collectionName: string, docId: string): Promise<Record<string, any> | null> {
  try {
    const res = await fetch(`${BASE_URL}/${collectionName}/${encodeURIComponent(docId)}`);
    if (!res.ok) return null;
    const doc = await res.json();
    return parseFirestoreDoc(doc);
  } catch (err) {
    console.warn(`[FirestoreCloud] fetchDocument(${collectionName}/${docId}) warning:`, err);
    return null;
  }
}

// Cập nhật một phần (merge) các trường của 1 tài liệu trên Cloud Firestore
export async function patchDocumentFields(
  collectionName: string,
  docId: string,
  fieldsToUpdate: Record<string, any>
): Promise<boolean> {
  try {
    const keys = Object.keys(fieldsToUpdate);
    const maskParams = keys.map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
    const url = `${BASE_URL}/${collectionName}/${encodeURIComponent(docId)}?${maskParams}`;
    const firestoreFields: Record<string, any> = {};
    for (const k of keys) {
      firestoreFields[k] = toFirestoreValue(fieldsToUpdate[k]);
    }
    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: firestoreFields }),
    });
    return res.ok;
  } catch (err) {
    console.error(`[FirestoreCloud] patchDocumentFields(${collectionName}/${docId}) error:`, err);
    return false;
  }
}

// Xóa 1 tài liệu trên Cloud Firestore (dùng khi ngắt kết nối GPS tài xế bị khóa)
export async function deleteDocument(collectionName: string, docId: string): Promise<boolean> {
  try {
    const res = await fetch(`${BASE_URL}/${collectionName}/${encodeURIComponent(docId)}`, {
      method: 'DELETE',
    });
    return res.ok;
  } catch {
    return false;
  }
}

// Tạo mới hoặc cập nhật toàn bộ 1 tài liệu trên Cloud Firestore
export async function createDocument(
  collectionName: string,
  docId: string | undefined,
  data: Record<string, any>
): Promise<boolean> {
  try {
    const firestoreFields: Record<string, any> = {};
    for (const k of Object.keys(data)) {
      firestoreFields[k] = toFirestoreValue(data[k]);
    }
    const url = docId
      ? `${BASE_URL}/${collectionName}/${encodeURIComponent(docId)}`
      : `${BASE_URL}/${collectionName}`;
    const method = docId ? 'PATCH' : 'POST';
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: firestoreFields }),
    });
    return res.ok;
  } catch (err) {
    console.error(`[FirestoreCloud] createDocument(${collectionName}/${docId}) error:`, err);
    return false;
  }
}

