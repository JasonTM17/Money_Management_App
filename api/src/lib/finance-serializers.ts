export function serializeBigInts<T>(value: T): T {
  return JSON.parse(
    JSON.stringify(value, (_key, nestedValue) =>
      typeof nestedValue === 'bigint' ? Number(nestedValue) : nestedValue,
    ),
  ) as T;
}
