export function moveItemToFront<T>(items: readonly T[], index: number): T[] {
  if (index <= 0 || index >= items.length) return [...items];
  return [items[index], ...items.slice(0, index), ...items.slice(index + 1)];
}
