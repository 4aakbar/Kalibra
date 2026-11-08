import { create } from 'zustand';

import type { ScheduleInput } from './store';

/** Data awal untuk Form jadwal saat dibuka dari kartu draf chat atau tombol "Isi manual". */
interface FormPrefill {
  input?: Partial<ScheduleInput>;
  draftRef?: { messageId: string; index: number };
  set: (p: { input?: Partial<ScheduleInput>; draftRef?: { messageId: string; index: number } }) => void;
  clear: () => void;
}

export const useFormPrefill = create<FormPrefill>((set) => ({
  set: (p) => set({ input: p.input, draftRef: p.draftRef }),
  clear: () => set({ input: undefined, draftRef: undefined }),
}));
