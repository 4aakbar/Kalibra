import type { CategoryId, Priority } from './types';

export interface CategoryMeta {
  id: CategoryId;
  label: string;
  /** Nama ikon Feather. */
  icon: 'book-open' | 'edit-3' | 'users' | 'briefcase' | 'heart';
}

export const CATEGORIES: CategoryMeta[] = [
  { id: 'kuliah', label: 'Kuliah', icon: 'book-open' },
  { id: 'tugas', label: 'Tugas', icon: 'edit-3' },
  { id: 'organisasi', label: 'Organisasi', icon: 'users' },
  { id: 'magang', label: 'Magang', icon: 'briefcase' },
  { id: 'pribadi', label: 'Pribadi', icon: 'heart' },
];

export const categoryMeta = (id: CategoryId): CategoryMeta =>
  CATEGORIES.find((c) => c.id === id) ?? CATEGORIES[4];

export const PRIORITY_LABEL: Record<Priority, string> = {
  rendah: 'Rendah',
  sedang: 'Sedang',
  tinggi: 'Tinggi',
};

export const REMINDER_OPTIONS = [
  { minutes: 10, label: '10 menit' },
  { minutes: 30, label: '30 menit' },
  { minutes: 60, label: '1 jam' },
  { minutes: 180, label: '3 jam' },
  { minutes: 1440, label: '1 hari' },
  { minutes: 4320, label: '3 hari' },
  { minutes: 10080, label: '1 minggu' },
];

export function reminderLabel(minutes: number): string {
  const found = REMINDER_OPTIONS.find((r) => r.minutes === minutes);
  if (found) return `${found.label} sebelum`;
  if (minutes % 1440 === 0) return `${minutes / 1440} hari sebelum`;
  if (minutes % 60 === 0) return `${minutes / 60} jam sebelum`;
  return `${minutes} menit sebelum`;
}
