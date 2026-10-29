import 'package:flutter/material.dart';

enum Purpose {
  paymentProof(
    label: 'Payment proof',
    subtitle: 'Share transaction status while hiding account numbers & phone',
    icon: Icons.receipt_long_rounded,
  ),
  collegeSubmission(
    label: 'College submission',
    subtitle: 'Submit assignments or admit cards without exposing personal contact details',
    icon: Icons.school_rounded,
  ),
  jobApplication(
    label: 'Job application',
    subtitle: 'Share resumes, portfolio proofs, or certificates without personal banking data',
    icon: Icons.work_outline_rounded,
  ),
  socialMedia(
    label: 'Social media',
    subtitle: 'Post screenshots publicly with maximum privacy and faces blurred',
    icon: Icons.public_rounded,
  ),
  customerSupport(
    label: 'Customer support',
    subtitle: 'Report app issues or bugs without leaking credentials or private chats',
    icon: Icons.support_agent_rounded,
  ),
  bankDispute(
    label: 'Bank dispute',
    subtitle: 'Dispute charges with verified transaction refs while masking card numbers',
    icon: Icons.account_balance_rounded,
  ),
  identityVerification(
    label: 'Identity verification',
    subtitle: 'Verify identity documents with required official IDs and face photo kept',
    icon: Icons.badge_outlined,
  ),
  marketplaceListing(
    label: 'Marketplace listing',
    subtitle: 'Sell items online without revealing home address, phone, or bank details',
    icon: Icons.storefront_rounded,
  ),
  personalDocSharing(
    label: 'Personal document sharing',
    subtitle: 'Share identity or legal records while shielding unneeded numbers',
    icon: Icons.folder_shared_rounded,
  ),
  general(
    label: 'General sharing',
    subtitle: 'Standard balanced privacy redaction for everyday screenshot sharing',
    icon: Icons.share_rounded,
  );

  const Purpose({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
}

enum Audience {
  privateAudience(
    label: 'Private Recipient',
    subtitle: 'Known individual, verified support representative, or banking desk',
    icon: Icons.lock_outline_rounded,
  ),
  publicAudience(
    label: 'Public Sharing',
    subtitle: 'Social media post, public forum, group chat, or broadcast',
    icon: Icons.public_rounded,
  );

  const Audience({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
}

// Backward compatibility alias
typedef SharingPurpose = Purpose;
