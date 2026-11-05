/// The privacy policy text shown in the app (Profile → About → Privacy policy).
///
/// Keep this in sync with store/privacy-policy.html, which is the copy you host
/// online for Google Play.
const privacyPolicyUpdated = '5 November 2026';

const privacyPolicyIntro =
    'FinTrack is a personal finance app for recording expenses, income, budgets, savings goals, loans and bills. '
    'This policy explains what happens to the information you enter.';

/// Short promises shown at the top of the screen.
const privacyHighlights = <(String, String)>[
  ('phone-portrait-outline', 'Stored only on your phone'),
  ('cloud-offline-outline', 'No internet access'),
  ('person-outline', 'No account or sign-in'),
  ('eye-off-outline', 'No ads, analytics or tracking'),
];

/// (icon, title, paragraphs). A paragraph starting with "• " is a bullet;
/// text before the first ": " in a bullet is shown in bold.
const privacyPolicySections = <(String, String, List<String>)>[
  (
    'phone-portrait-outline',
    'Information the app stores',
    [
      'Everything you enter is stored only on your device, in the app\'s private storage. Other apps can\'t read it.',
      'This includes your transactions, budgets, goals, loans, bills and payments, and the optional name and email on the profile screen.',
      'The app has no account system and no server, and it does not send your data anywhere.',
    ],
  ),
  (
    'shield-checkmark-outline',
    'Information we collect',
    [
      'None. The app does not collect, transmit, sell or share personal or financial data.',
      'It contains no analytics, advertising or tracking software, and it does not request internet access.',
    ],
  ),
  (
    'finger-print',
    'App lock',
    [
      'If you turn on App lock, Android checks your fingerprint, face or screen lock and only tells the app whether it matched.',
      'The app never sees, stores or sends your fingerprint, face data or PIN.',
    ],
  ),
  (
    'notifications-outline',
    'Notifications',
    [
      'If you allow notifications, the app schedules reminders on your device before EMI and bill due dates. They are created and delivered entirely on the device.',
      'With Private reminders on (the default), notifications don\'t include amounts, because they can appear on the lock screen.',
    ],
  ),
  (
    'key-outline',
    'Permissions',
    [
      '• Notifications: to show payment reminders.',
      '• Run at startup: to restore scheduled reminders after the phone restarts.',
      '• Vibration: for reminder notifications.',
      '• Biometrics: only used when you turn on App lock.',
    ],
  ),
  (
    'trash-outline',
    'Deleting your data',
    [
      'To delete everything, use Profile & settings → Erase all data, or uninstall the app. Uninstalling removes everything the app stored.',
      'If Android backup is turned on in your phone\'s settings, it may keep a copy of the app\'s data in your own Google account.',
    ],
  ),
  (
    'people-outline',
    'Children',
    ['The app is intended for adults and is not directed at children under 13.'],
  ),
  (
    'refresh-outline',
    'Changes to this policy',
    ['If this policy changes, the updated version will be shown here and on the website, with a new date.'],
  ),
];
