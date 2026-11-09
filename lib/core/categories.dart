import 'package:flutter/material.dart';

import 'models.dart';

const categoryLabel = {
  CategoryId.kuliah: 'Kuliah',
  CategoryId.tugas: 'Tugas',
  CategoryId.organisasi: 'Organisasi',
  CategoryId.magang: 'Magang',
  CategoryId.pribadi: 'Pribadi',
};

const categoryIcon = {
  CategoryId.kuliah: Icons.menu_book_rounded,
  CategoryId.tugas: Icons.edit_note_rounded,
  CategoryId.organisasi: Icons.groups_rounded,
  CategoryId.magang: Icons.work_outline_rounded,
  CategoryId.pribadi: Icons.favorite_border_rounded,
};

const priorityLabel = {Priority.rendah: 'Rendah', Priority.sedang: 'Sedang', Priority.tinggi: 'Tinggi'};

const freqLabel = {
  RecurrenceFreq.harian: 'Setiap hari',
  RecurrenceFreq.mingguan: 'Setiap minggu',
  RecurrenceFreq.duaMingguan: 'Setiap 2 minggu',
  RecurrenceFreq.bulanan: 'Setiap bulan',
};

const reminderOptions = <(int, String)>[
  (10, '10 menit'),
  (30, '30 menit'),
  (60, '1 jam'),
  (180, '3 jam'),
  (1440, '1 hari'),
  (4320, '3 hari'),
  (10080, '1 minggu'),
];

String reminderShort(int minutes) {
  for (final (m, l) in reminderOptions) {
    if (m == minutes) return l;
  }
  if (minutes % 1440 == 0) return '${minutes ~/ 1440} hari';
  if (minutes % 60 == 0) return '${minutes ~/ 60} jam';
  return '$minutes menit';
}

String reminderLabel(int minutes) => '${reminderShort(minutes)} sebelum';
