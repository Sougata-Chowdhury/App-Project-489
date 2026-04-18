String friendlyRequestType(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return '';

  switch (v) {
    case 'MedicineHelp':
    case 'medicine':
      return 'Medicine Help';
    case 'GroceryHelp':
    case 'grocery':
      return 'Grocery Help';
    case 'GeneralAssistance':
    case 'general':
      return 'General Assistance';
    default:
      // Fall back to a mildly-friendly version.
      return v
          .replaceAll('_', ' ')
          .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
  }
}
