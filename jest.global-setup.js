// Tes tanggal dijalankan di zona WIB supaya hasilnya sama di semua mesin.
module.exports = async () => {
  process.env.TZ = 'Asia/Jakarta';
};
