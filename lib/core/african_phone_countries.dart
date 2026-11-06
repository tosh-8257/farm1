import 'package:flutter/material.dart';

/// African calling codes used by login and registration.
/// Kenya is the default. The list is the product's supported set.
const Map<String, String> kDefaultLoginCountry = {
  'name': 'Kenya',
  'iso': 'KE',
  'code': '+254',
  'flag': '🇰🇪',
};

const List<Map<String, String>> kAfricanPhoneCountries = [
    {'name': 'Algeria', 'iso': 'DZ', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Angola', 'iso': 'AO', 'code': '+244', 'flag': '🇦🇴'},
    {'name': 'Benin', 'iso': 'BJ', 'code': '+229', 'flag': '🇧🇯'},
    {'name': 'Botswana', 'iso': 'BW', 'code': '+267', 'flag': '🇧🇼'},
    {'name': 'Burkina Faso', 'iso': 'BF', 'code': '+226', 'flag': '🇧🇫'},
    {'name': 'Burundi', 'iso': 'BI', 'code': '+257', 'flag': '🇧🇮'},
    {'name': 'Cabo Verde', 'iso': 'CV', 'code': '+238', 'flag': '🇨🇻'},
    {'name': 'Cameroon', 'iso': 'CM', 'code': '+237', 'flag': '🇨🇲'},
    {
      'name': 'Central African Republic',
      'iso': 'CF',
      'code': '+236',
      'flag': '🇨🇫'
    },
    {'name': 'Chad', 'iso': 'TD', 'code': '+235', 'flag': '🇹🇩'},
    {'name': 'Comoros', 'iso': 'KM', 'code': '+269', 'flag': '🇰🇲'},
    {'name': 'Congo', 'iso': 'CG', 'code': '+242', 'flag': '🇨🇬'},
    {'name': 'DR Congo', 'iso': 'CD', 'code': '+243', 'flag': '🇨🇩'},
    {'name': 'Cote d\'Ivoire', 'iso': 'CI', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Djibouti', 'iso': 'DJ', 'code': '+253', 'flag': '🇩🇯'},
    {'name': 'Egypt', 'iso': 'EG', 'code': '+20', 'flag': '🇪🇬'},
    {'name': 'Equatorial Guinea', 'iso': 'GQ', 'code': '+240', 'flag': '🇬🇶'},
    {'name': 'Eritrea', 'iso': 'ER', 'code': '+291', 'flag': '🇪🇷'},
    {'name': 'Eswatini', 'iso': 'SZ', 'code': '+268', 'flag': '🇸🇿'},
    {'name': 'Ethiopia', 'iso': 'ET', 'code': '+251', 'flag': '🇪🇹'},
    {'name': 'Gabon', 'iso': 'GA', 'code': '+241', 'flag': '🇬🇦'},
    {'name': 'Gambia', 'iso': 'GM', 'code': '+220', 'flag': '🇬🇲'},
    {'name': 'Ghana', 'iso': 'GH', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Guinea', 'iso': 'GN', 'code': '+224', 'flag': '🇬🇳'},
    {'name': 'Guinea-Bissau', 'iso': 'GW', 'code': '+245', 'flag': '🇬🇼'},
    {'name': 'Kenya', 'iso': 'KE', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Lesotho', 'iso': 'LS', 'code': '+266', 'flag': '🇱🇸'},
    {'name': 'Liberia', 'iso': 'LR', 'code': '+231', 'flag': '🇱🇷'},
    {'name': 'Libya', 'iso': 'LY', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'Madagascar', 'iso': 'MG', 'code': '+261', 'flag': '🇲🇬'},
    {'name': 'Malawi', 'iso': 'MW', 'code': '+265', 'flag': '🇲🇼'},
    {'name': 'Mali', 'iso': 'ML', 'code': '+223', 'flag': '🇲🇱'},
    {'name': 'Mauritania', 'iso': 'MR', 'code': '+222', 'flag': '🇲🇷'},
    {'name': 'Mauritius', 'iso': 'MU', 'code': '+230', 'flag': '🇲🇺'},
    {'name': 'Morocco', 'iso': 'MA', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'Mozambique', 'iso': 'MZ', 'code': '+258', 'flag': '🇲🇿'},
    {'name': 'Namibia', 'iso': 'NA', 'code': '+264', 'flag': '🇳🇦'},
    {'name': 'Niger', 'iso': 'NE', 'code': '+227', 'flag': '🇳🇪'},
    {'name': 'Nigeria', 'iso': 'NG', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'Rwanda', 'iso': 'RW', 'code': '+250', 'flag': '🇷🇼'},
    {
      'name': 'Sao Tome and Principe',
      'iso': 'ST',
      'code': '+239',
      'flag': '🇸🇹'
    },
    {'name': 'Senegal', 'iso': 'SN', 'code': '+221', 'flag': '🇸🇳'},
    {'name': 'Seychelles', 'iso': 'SC', 'code': '+248', 'flag': '🇸🇨'},
    {'name': 'Sierra Leone', 'iso': 'SL', 'code': '+232', 'flag': '🇸🇱'},
    {'name': 'Somalia', 'iso': 'SO', 'code': '+252', 'flag': '🇸🇴'},
    {'name': 'South Africa', 'iso': 'ZA', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'South Sudan', 'iso': 'SS', 'code': '+211', 'flag': '🇸🇸'},
    {'name': 'Sudan', 'iso': 'SD', 'code': '+249', 'flag': '🇸🇩'},
    {'name': 'Tanzania', 'iso': 'TZ', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Togo', 'iso': 'TG', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Tunisia', 'iso': 'TN', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'Uganda', 'iso': 'UG', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Zambia', 'iso': 'ZM', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'iso': 'ZW', 'code': '+263', 'flag': '🇿🇼'},
  ];

/// Same searchable list as login. Returns the selected row, or null if dismissed.
Future<Map<String, String>?> showAfricanCountryPicker(
  BuildContext context,
  Map<String, String> current,
) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _AfricanCountrySheet(current: current),
  );
}

class _AfricanCountrySheet extends StatefulWidget {
  const _AfricanCountrySheet({required this.current});
  final Map<String, String> current;
  @override
  State<_AfricanCountrySheet> createState() => _AfricanCountrySheetState();
}

class _AfricanCountrySheetState extends State<_AfricanCountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = kAfricanPhoneCountries.where((c) {
      if (q.isEmpty) return true;
      return (c['name'] ?? '').toLowerCase().contains(q) ||
          (c['code'] ?? '').toLowerCase().contains(q) ||
          (c['iso'] ?? '').toLowerCase().contains(q);
    }).toList();
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (_, i) {
                  final c = matches[i];
                  final selected = c['iso'] == widget.current['iso'];
                  return ListTile(
                    leading: Text(c['flag'] ?? '', style: const TextStyle(fontSize: 22)),
                    title: Text(c['name'] ?? ''),
                    trailing: Text(c['code'] ?? ''),
                    selected: selected,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
