import 'package:uuid/uuid.dart';
import 'db.dart';
import 'models.dart';

const _uuid = Uuid();

const _sourcesRaw = [
  ('5d6e6f47-4299-40b1-8b46-da141af0f7fa', 'BCA Kredit',          'credit'),
  ('6a4c8c9b-6fd1-40ea-a103-d91e18d62f69', 'Mandiri',             'debit'),
  ('7b703002-7e1f-4a39-a568-91a9f0ca0a93', 'Shopeepay',           'ewallet'),
  ('833dd628-791e-41c3-b078-836c9521cd97', 'Blu by BCA',          'debit'),
  ('9f21e48c-b28f-4cee-ad02-c686f4f983db', 'Cash',                'cash'),
  ('9f7c8371-cd76-4577-8770-870ceb297913', 'BCA-Pocket-Tabungan', 'savings'),
  ('ce36cae6-3dc5-419c-b8b5-731a49ce9b08', 'BluSaving-Tabungan',  'savings'),
  ('dec5a650-4c13-4821-bb1d-9b5c120b009c', 'Gopay',               'ewallet'),
  ('f535abb3-b4b0-4d28-9bf7-6e3c98cabf77', 'BCA Debit',           'debit'),
];

const _earnCats = [
  'Narik Investasi', 'Others', 'Recount', 'Bayar patungan jajan', 'Gaji',
];
const _spendCats = [
  'Investasi', 'Belanja', 'Transport Kantor', 'Jajan', 'Motor',
  'Maintenance Motor', 'Others', 'Medications/Health', 'Subscription',
  'Spending Bulanan', 'Akomodasi Ngantor', 'Bulanan Rumah', 'Recount', 'Bulanan Motor',
];

// [type, amount, description, category, source, fromSource, toSource, date]
const _txnsRaw = [
  ('earning',  12596000.0, 'Gaji',            'Gaji',        'BCA Debit', null, null, '2026-02-05T09:19:27'),
  ('earning',  12596000.0, 'Gaji bulanan',    'Gaji',        'BCA Debit', null, null, '2026-01-05T08:16:23'),
  ('spending',  4000000.0, 'Reksadana invest','Investasi',   'BCA Debit', null, null, '2026-02-05T09:25:51'),
  ('spending',  4000000.0, 'Invest Reksadana','Investasi',   'BCA Debit', null, null, '2026-01-05T08:28:57'),
  ('spending',   392034.0, 'Listrik',         'Bulanan Rumah','BCA Debit',null, null, '2026-02-05T09:28:57'),
  ('spending',   392034.0, 'Listrik',         'Bulanan Rumah','BCA Debit',null, null, '2026-01-05T09:14:06'),
  ('spending',   750000.0, 'Starlink',        'Bulanan Rumah','BCA Kredit',null,null,'2026-01-26T16:49:50'),
  ('spending',  1946500.0, 'Coursera Learning','Subscription','BCA Debit',null, null, '2026-01-05T08:35:44'),
  ('spending',   306000.0, 'Cetta Course English','Subscription','BCA Debit',null,null,'2026-01-14T13:36:10'),
  ('spending',   154290.0, 'Youtube',         'Subscription','BCA Kredit', null, null,'2026-01-28T14:02:25'),
  ('spending',    75000.0, 'Chatgpt subscription','Subscription','BCA Kredit',null,null,'2026-01-29T04:42:09'),
  ('spending',    65000.0, 'Netflix',         'Subscription','BCA Kredit', null, null,'2026-01-19T00:08:18'),
  ('spending',    50000.0, 'Kuota xl',        'Subscription','Blu by BCA', null, null,'2026-01-25T11:48:04'),
  ('spending',    32190.0, 'Google Play Pass','Subscription','BCA Kredit', null, null,'2026-01-27T17:41:29'),
  ('spending',    19300.0, 'Nambah kuota XL', 'Subscription','Blu by BCA', null, null,'2026-02-10T19:20:53'),
  ('spending',   570350.0, 'Bmbb ber 4',      'Jajan',       'BCA Debit', null, null, '2026-02-09T16:27:30'),
  ('spending',   346000.0, 'Udon double poin','Jajan',       'BCA Kredit', null, null,'2026-01-14T16:27:04'),
  ('spending',   193000.0, 'Udon kbp',        'Jajan',       'BCA Kredit', null, null,'2026-01-25T16:54:13'),
  ('spending',   190300.0, 'Simplisio ramen', 'Jajan',       'Blu by BCA', null, null,'2026-01-10T17:10:29'),
  ('spending',   133000.0, 'Mrs Karee',       'Jajan',       'Blu by BCA', null, null,'2026-01-29T18:21:10'),
  ('spending',   105501.0, 'Hokben',          'Jajan',       'BCA Debit', null, null, '2026-02-05T02:02:07'),
  ('spending',   105000.0, 'Bayar kue ke soyaa','Jajan',     'Blu by BCA', null, null,'2026-02-03T13:31:09'),
  ('spending',    92000.0, 'Marugame Udon KBP','Jajan',      'BCA Debit', null, null, '2026-01-04T16:34:43'),
  ('spending',    86625.0, 'Momiji Cafe',     'Jajan',       'BCA Debit', null, null, '2026-02-05T02:02:33'),
  ('spending',    63000.0, 'Seblak mang aru', 'Jajan',       'BCA Debit', null, null, '2026-02-09T16:29:26'),
  ('spending',   233620.0, 'Alat Cuci motor', 'Belanja',     'BCA Kredit', null, null,'2026-02-05T09:53:02'),
  ('spending',   183500.0, 'Belanja rsb',     'Belanja',     'BCA Kredit', null, null,'2026-01-15T18:37:42'),
  ('spending',   139000.0, 'Tas eiger kecil', 'Belanja',     'Blu by BCA', null, null,'2026-02-09T16:23:24'),
  ('spending',   275000.0, 'Whoosh balik ngantor','Transport Kantor','BCA Debit',null,null,'2026-02-10T19:18:20'),
  ('spending',   154000.0, 'Travel ke kantor','Transport Kantor','Blu by BCA',null,null,'2026-01-21T04:41:09'),
  ('spending',   149000.0, 'Travel ke kantor','Transport Kantor','Blu by BCA',null,null,'2026-02-09T16:26:15'),
  ('spending',    89000.0, 'Pertamax turbo fulltank','Motor','Cash', null, null, '2026-02-09T16:29:44'),
  ('spending',    83693.0, 'Bensin Shell fulltank','Motor',  'Blu by BCA', null, null, '2026-01-14T17:18:02'),
  ('spending',    75000.0, 'Bongkar CVT + Clean CVT','Maintenance Motor','BCA Debit',null,null,'2026-01-27T17:44:43'),
  ('spending',    41500.0, 'Oli motor Castrol','Bulanan Motor','BCA Debit',null, null, '2026-01-04T17:00:41'),
  ('spending',    94000.0, 'Rhinos SR',       'Medications/Health','BCA Debit',null,null,'2026-01-04T15:33:31'),
  ('transfer', 2770944.0,  'Bayar cc',         null,          null, 'BCA Debit', 'BCA Kredit', '2026-02-05T09:19:09'),
  ('transfer', 2582850.0,  'Bayar kredit',     null,          null, 'BCA Debit', 'BCA Kredit', '2026-01-05T08:17:33'),
  ('transfer', 3000000.0,  'Transfer ke blu',  null,          null, 'BCA Debit', 'Blu by BCA', '2026-01-05T08:37:53'),
  ('transfer', 2500000.0,  'Bca ke blu',       null,          null, 'BCA Debit', 'Blu by BCA', '2026-02-05T09:34:50'),
  ('transfer', 1250000.0,  'Transfer ke cash', null,          null, 'BCA Debit', 'Cash',        '2026-01-06T17:59:05'),
  ('transfer', 1000000.0,  'Nabung',           null,          null, 'Blu by BCA','BluSaving-Tabungan','2026-01-05T08:58:17'),
  ('transfer', 1000000.0,  'Nabung tipid',     null,          null, 'BCA Debit', 'BCA-Pocket-Tabungan','2026-02-05T09:31:19'),
];

Future<bool> seedIfEmpty() async {
  final existing = await AppDb.instance.getSources();
  if (existing.isNotEmpty) return false;

  final now = DateTime.now().toIso8601String();
  for (final (id, name, kind) in _sourcesRaw) {
    await AppDb.instance.putSource(Source(id: id, name: name, kind: kind, syncState: 'synced', updatedAt: now));
  }
  for (final name in _earnCats) {
    await AppDb.instance.putCategory(Category(id: _uuid.v4(), name: name, kind: 'earning', syncState: 'synced', updatedAt: now));
  }
  for (final name in _spendCats) {
    await AppDb.instance.putCategory(Category(id: _uuid.v4(), name: name, kind: 'spending', syncState: 'synced', updatedAt: now));
  }
  for (final (type, amount, description, category, source, fromSource, toSource, date) in _txnsRaw) {
    await AppDb.instance.putTransaction(Transaction(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      description: description,
      category: category,
      source: source,
      fromSource: fromSource,
      toSource: toSource,
      date: date,
      syncState: 'synced',
      updatedAt: now,
    ));
  }
  return true;
}
