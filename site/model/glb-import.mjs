const MAX_GLB_BYTES = 16 * 1024 * 1024;
const MAGIC = 0x46546c67;
const JSON_CHUNK = 0x4e4f534a;
const BIN_CHUNK = 0x004e4942;

export async function readLibraryGlb(file) {
  if (file.size > MAX_GLB_BYTES) throw new Error("Файл больше 16 МБ.");
  if (file.size < 20) throw new Error("Файл GLB повреждён.");
  const bytes = await file.arrayBuffer();
  const data = new DataView(bytes);
  if (data.getUint32(0, true) !== MAGIC || data.getUint32(4, true) !== 2 ||
      data.getUint32(8, true) !== bytes.byteLength ||
      data.getUint32(16, true) !== JSON_CHUNK)
    throw new Error("Нужен двоичный файл GLB версии 2.");
  const jsonSize = data.getUint32(12, true);
  const jsonEnd = 20 + jsonSize;
  if (!jsonSize || jsonSize % 4 || jsonEnd > bytes.byteLength)
    throw new Error("Файл GLB повреждён.");
  const binSize = jsonEnd === bytes.byteLength ? 0 : readBinarySize(data, jsonEnd);
  const model = JSON.parse(new TextDecoder("utf-8", { fatal: true })
    .decode(new Uint8Array(bytes, 20, jsonSize)));
  if (model?.asset?.version !== "2.0" || !model.meshes?.some(mesh => mesh.primitives?.length))
    throw new Error("В файле нет геометрии GLB 2.0.");
  if ([...(model.buffers ?? []), ...(model.images ?? [])].some(entry =>
    typeof entry?.uri === "string" && !entry.uri.startsWith("data:")))
    throw new Error("Экспортируй GLB со встроенными текстурами и геометрией.");
  const embedded = model.buffers?.[0];
  if (embedded && !embedded.uri && (!binSize || embedded.byteLength > binSize))
    throw new Error("Встроенная геометрия GLB повреждена.");
  return new Blob([bytes], { type: "model/gltf-binary" });
}

function readBinarySize(data, offset) {
  if (offset + 8 > data.byteLength || data.getUint32(offset + 4, true) !== BIN_CHUNK)
    throw new Error("Файл GLB повреждён.");
  const size = data.getUint32(offset, true);
  if (size % 4 || offset + 8 + size !== data.byteLength)
    throw new Error("Файл GLB повреждён.");
  return size;
}
