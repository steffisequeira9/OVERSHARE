enum SensitiveType {
  email(displayName: 'Email Address'),
  phone(displayName: 'Phone Number'),
  senderUpiId(displayName: 'Sender UPI ID'),
  recipientUpiId(displayName: 'Recipient UPI ID'),
  upiId(displayName: 'UPI ID'),
  url(displayName: 'Web URL'),
  aadhaar(displayName: 'Aadhaar Number'),
  pan(displayName: 'PAN Card Number'),
  voterId(displayName: 'Voter ID (EPIC)'),
  dob(displayName: 'Date of Birth'),
  credential(displayName: 'Password / OTP / Secret'),
  card(displayName: 'Payment Card Number'),
  ifsc(displayName: 'IFSC Code'),
  accountNumber(displayName: 'Account Reference'),
  transactionId(displayName: 'Transaction / UTR ID'),
  amount(displayName: 'Payment Amount'),
  dateTime(displayName: 'Date / Time'),
  personName(displayName: 'Person Name'),
  face(displayName: 'Detected Face');

  const SensitiveType({required this.displayName});

  final String displayName;
}
