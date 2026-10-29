import '../scanner/models/sensitive_type.dart';
import 'purpose.dart';

enum RedactionAction {
  keep(label: 'KEEP'),
  hide(label: 'HIDE'),
  blurFace(label: 'BLUR FACE'),
  coverFace(label: 'COVER FACE'),
  optional(label: 'OPTIONAL');

  const RedactionAction({required this.label});
  final String label;

  bool get isKeep => this == RedactionAction.keep;
  bool get isHide => this == RedactionAction.hide;
  bool get isBlurFace => this == RedactionAction.blurFace;
  bool get isCoverFace => this == RedactionAction.coverFace;
  bool get isOptional => this == RedactionAction.optional;
  bool get isFaceAction => isBlurFace || isCoverFace;
}

class RuleDecision {
  final RedactionAction action;
  final String reason;

  const RuleDecision(this.action, this.reason);
}

class RulesTable {
  const RulesTable._();

  /// Returns the rule decision for a given [type], [purpose], and [audience].
  /// This is the SINGLE SOURCE OF TRUTH for all recommendations and UI explanations.
  static RuleDecision getDecision(
    SensitiveType type,
    Purpose purpose, [
    Audience audience = Audience.privateAudience,
  ]) {
    final purposeMap = _rules[purpose];
    if (purposeMap != null) {
      final audienceMap = purposeMap[audience] ?? purposeMap[Audience.privateAudience];
      if (audienceMap != null && audienceMap.containsKey(type)) {
        return audienceMap[type]!;
      }
    }
    return _defaultFallback(type, audience);
  }

  static RuleDecision _defaultFallback(SensitiveType type, Audience audience) {
    if (type == SensitiveType.face) {
      return audience == Audience.publicAudience
          ? const RuleDecision(RedactionAction.blurFace, 'Blurs face to protect biometric identity.')
          : const RuleDecision(RedactionAction.optional, 'Face detection present; review before sharing.');
    }
    return const RuleDecision(
      RedactionAction.hide,
      'Confidential personal data not required for this recipient.',
    );
  }

  static final Map<Purpose, Map<Audience, Map<SensitiveType, RuleDecision>>> _rules = {
    // -------------------------------------------------------------------------
    // 1. PAYMENT PROOF
    // -------------------------------------------------------------------------
    Purpose.paymentProof: {
      Audience.privateAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Essential reference for recipient to verify payment status.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Payment amount confirms the transferred sum.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Timestamp proves when transaction took place.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.keep, 'Recipient identifier verifies correct destination account.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.keep, 'Branch code helps recipient confirm correct bank routing.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Portal URL; keep if recipient needs verification link.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.optional, 'Recipient name confirms payee; sender name optional.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Sender VPA is confidential personal banking detail.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Generic VPA is confidential banking detail.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number should not be visible to third parties.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal phone number is unneeded for payment confirmation.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address is unneeded for payment confirmation.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth is confidential personal data.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'Profile photo present; review before sharing.'),
      },
      Audience.publicAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Transaction reference validates authentic public proof.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Disclosed payment total verifies transaction size.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Date and time establishes chronological record.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'Public merchant handle; check if personal before sharing.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.optional, 'Public bank branch routing code.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public portal address.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal names must not be broadcast to public audiences.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal sender UPI handle must not be publicly broadcast.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Private VPA handle must remain hidden from public.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number must remain hidden from public.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal phone number must remain hidden from public.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address must remain hidden from public.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Card credentials must remain hidden from public.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID must remain hidden from public.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must remain hidden from public.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID must remain hidden from public.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain hidden from public.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to prevent facial recognition in public domain.'),
      },
    },

    // -------------------------------------------------------------------------
    // 2. COLLEGE SUBMISSION
    // -------------------------------------------------------------------------
    Purpose.collegeSubmission: {
      Audience.privateAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Student name identifies authorship for instructors and grading.'),
        SensitiveType.email: const RuleDecision(RedactionAction.keep, 'Academic email confirms student ownership of submission.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Fee or challan reference validates registration.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Submission timestamp establishes deadline compliance.'),
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Educational link, repository, or cited resource.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Student contact phone; review whether personal or faculty requested.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'Fee or tuition amount; keep only if submitting fee clearance verification.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'College fee collection account; keep only if verifying institutional fee transfer.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'Student portrait; review whether required on assignment cover page.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth is unnecessary for academic coursework submission.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Personal bank account must remain hidden in coursework submissions.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch routing code is unnecessary for coursework submissions.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden in coursework submissions.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden in coursework submissions.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
      },
      Audience.publicAudience: {
        SensitiveType.email: const RuleDecision(RedactionAction.optional, 'Public student contact; hide if personal address.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Public author attribution for academic work.'),
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Public citation or repository link.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Publication date and time.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'Tuition or project grant figure.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Transaction reference must not be publicly published.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'College account handle not required in public papers.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal contact phone must remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank routing code not needed publicly.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number must remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Card details must remain hidden.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID must remain hidden.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must remain hidden.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID must remain hidden.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain hidden.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to protect student privacy in public domain.'),
      },
    },

    // -------------------------------------------------------------------------
    // 3. JOB APPLICATION
    // -------------------------------------------------------------------------
    Purpose.jobApplication: {
      Audience.privateAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Candidate name is primary identifier on resume.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Employment and graduation dates clarify timeline.'),
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Portfolio, LinkedIn, or GitHub profile link.'),
        SensitiveType.email: const RuleDecision(RedactionAction.optional, 'Contact email; review whether professional or personal address is needed.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Personal phone number; review whether direct phone contact is needed at initial application.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'Professional headshot; optional based on hiring preference and regional norms.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Full date of birth is unnecessary at application stage and exposes age discrimination/identity risk.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Historical salary figures are private negotiation data.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Financial transaction IDs are irrelevant to job applications.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Payment handle is irrelevant to job application.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'Payment handle is irrelevant to job application.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Payment handle is irrelevant to job application.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account is irrelevant prior to formal payroll onboarding.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch code is irrelevant to job application.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data unnecessary prior to formal onboarding.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data unnecessary prior to formal onboarding.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data unnecessary prior to formal onboarding.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
      },
      Audience.publicAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Professional candidate name for portfolio display.'),
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Public portfolio or LinkedIn web link.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General career dates and milestones.'),
        SensitiveType.email: const RuleDecision(RedactionAction.optional, 'Public contact email; hide if personal inbox.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal phone number should not be posted publicly.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to protect candidate biometric privacy.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain private.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Salary data must remain private.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Financial ID must remain private.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Payment details must remain private.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'Payment details must remain private.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Payment details must remain private.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account must remain private.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must remain private.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Card details must remain private.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID must remain private.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must remain private.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID must remain private.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 4. SOCIAL MEDIA
    // -------------------------------------------------------------------------
    Purpose.socialMedia: {
      Audience.privateAudience: {
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Web link; keep if public content, hide if internal link.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.optional, 'Name tag; keep if public persona, hide if private citizen.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Post timestamp provides context to viewers.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to protect individual likeness from indexing.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Financial numbers must not be disclosed on social platforms.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal phone number must not be exposed on social media.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address must not be exposed on social media.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Payment transaction reference must not be exposed.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must not be exposed.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'Payment handle must not be exposed.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must not be exposed.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number must not be exposed.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank routing details must not be exposed.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must not be exposed on social media.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be exposed on social media.'),
      },
      Audience.publicAudience: {
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public web link or channel handle.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General timestamp for post audience.'),
        SensitiveType.face: const RuleDecision(RedactionAction.coverFace, 'Solid mask over face to prevent automated facial scraping.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Names must not be broadcast to public social media.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Financial amounts must not be exposed.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone numbers must not be broadcast publicly.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Email addresses must not be broadcast publicly.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Transaction IDs must not be broadcast publicly.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'UPI handles must not be broadcast publicly.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'UPI handles must not be broadcast publicly.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'UPI handles must not be broadcast publicly.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account must not be broadcast publicly.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must not be broadcast publicly.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must not be broadcast to public.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 5. CUSTOMER SUPPORT
    // -------------------------------------------------------------------------
    Purpose.customerSupport: {
      Audience.privateAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Order or transaction ID is required by support to locate ticket.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Incident timestamp assists support team with audit logs.'),
        SensitiveType.email: const RuleDecision(RedactionAction.keep, 'Account email confirms registered customer identity.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Disputed charge amount needed to calculate refund.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Customer name matches registered account profile.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.keep, 'Merchant identifier verifies vendor in dispute.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Contact phone; keep if agent requested callback number.'),
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Product or error page URL helps support diagnose the problem.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.optional, 'Sender payment handle; keep if proving source account.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.optional, 'Payment handle; keep if proving source account.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.optional, 'Branch IFSC code; keep if verifying bank wire.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'User photo; keep only if biometric support verification required.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.optional, 'Date of birth; share only if requested for account recovery verification.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number should not be visible to general agents.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Support agents will never legitimately ask for passwords or OTPs.'),
      },
      Audience.publicAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Ticket reference for public support thread.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Incident date confirms timeline for public ticket.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Reported charge amount.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal name should not be posted on public forum.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address should not be posted on public forum.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone number must remain private on public ticket.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public documentation or product URL.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Sender UPI handle must remain hidden.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'Vendor support handle.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal UPI handle must remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch code must remain hidden.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Account numbers must remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain hidden on public forum.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to prevent facial scraping on public support forum.'),
      },
    },

    // -------------------------------------------------------------------------
    // 6. BANK DISPUTE
    // -------------------------------------------------------------------------
    Purpose.bankDispute: {
      Audience.privateAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'UTR or reference number is required to trace disputed transfer.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Exact disputed transaction sum is essential for bank review.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Transaction date and time correlates with bank ledger entries.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.keep, 'Account reference confirms originating bank balance.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.keep, 'IFSC code confirms clearing branch for interbank dispute.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Account holder name matches bank KYC records; do not blur customer identity in dispute documentation.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.keep, 'Payee VPA identifies beneficiary of disputed payment.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.keep, 'Sender VPA verifies remitter account origin.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.keep, 'VPA identifier verifies remitter account origin.'),
        SensitiveType.email: const RuleDecision(RedactionAction.keep, 'Bank communications email address.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.keep, 'Registered phone number on bank file.'),
        SensitiveType.face: const RuleDecision(RedactionAction.keep, 'Account holder photo portrait confirms claimant identity; do not automatically blur in bank claim.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Netbanking or portal link.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.optional, 'Date of birth; share only if required by bank verification officer.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.optional, 'Tax number; share only if dispute exceeds statutory limits.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Full card number should not be visible in dispute documentation.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data unless formal statutory verification is demanded.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Bank officials never require account passwords, PINs or OTPs.'),
      },
      Audience.publicAudience: {
        SensitiveType.transactionId: const RuleDecision(RedactionAction.keep, 'Public dispute grievance reference number.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Disputed amount figure.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Incident date and time.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal identity must remain confidential in public.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number must remain confidential in public.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.optional, 'General bank branch code.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'Beneficiary corporate handle.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address must remain hidden.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone number must remain hidden.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public banking grievance portal.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face in public forum.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must remain confidential.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain hidden.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 7. IDENTITY VERIFICATION
    // -------------------------------------------------------------------------
    Purpose.identityVerification: {
      Audience.privateAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Full legal name verifies official identity.'),
        SensitiveType.email: const RuleDecision(RedactionAction.keep, 'Registered email address for verified credential delivery.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.keep, 'Registered contact phone for one-time verification challenge.'),
        SensitiveType.face: const RuleDecision(RedactionAction.keep, 'Biometric facial portrait matches official identity document.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.optional, 'Document date of issue or birth date confirms age requirement.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.optional, 'Date of birth confirms legal age verification.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential. Use masked Aadhaar (last 4 digits only) unless full 12 digits explicitly mandated.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.optional, 'Permanent Account Number; share only if tax KYC explicitly required.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.optional, 'Voter ID document; share only if electoral KYC requested.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.optional, 'Bank account reference; share only for financial KYC.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.optional, 'Bank IFSC branch code; share only for financial KYC.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Verification portal address.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.optional, 'Verification challan or application reference.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'Application fee amount.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded for identity verification.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded for identity verification.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded for identity verification.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs are never part of KYC document verification.'),
      },
      Audience.publicAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal name must not be broadcast to public.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs facial image to prevent identity misuse.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.hide, 'Birth date must remain private from public.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must never be publicly exposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID must never be publicly exposed.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must never be publicly exposed.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID must never be publicly exposed.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Email address must not be exposed to public.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone number must not be exposed to public.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account must remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must remain hidden.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'General verification link.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Reference ID must remain hidden.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Fee amount must remain hidden.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 8. MARKETPLACE LISTING
    // -------------------------------------------------------------------------
    Purpose.marketplaceListing: {
      Audience.privateAudience: {
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Listing asking price or product value.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Item purchase date or listing timestamp.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Official product page or review link.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.optional, 'Seller first name; keep if known to buyer.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Direct buyer communication; share only after deal agreement.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'Seller payment handle for buyer transfer.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email address should remain shielded on marketplace.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Private banking handle should remain unexposed.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Private banking handle should remain unexposed.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number should not be visible to marketplace buyers.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch details should remain hidden.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Prior purchase receipt IDs should remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth is irrelevant to marketplace sales.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face in product images to protect seller identity.'),
      },
      Audience.publicAudience: {
        SensitiveType.amount: const RuleDecision(RedactionAction.keep, 'Public asking price for item.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General listing timestamp.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public manufacturer specifications link.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal seller name should not be broadcast on public listing.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Personal phone numbers on public listings attract spam.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Personal email must not be broadcast publicly.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to prevent facial profiling on marketplace.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'Public payment handles attract unsolicited requests.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Personal payment handle must remain hidden.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account must remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must remain hidden.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Receipt reference must remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must remain hidden.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 9. PERSONAL DOCUMENT SHARING
    // -------------------------------------------------------------------------
    Purpose.personalDocSharing: {
      Audience.privateAudience: {
        SensitiveType.personName: const RuleDecision(RedactionAction.keep, 'Document subject name verifies record relevance.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'Document date or issuance period.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Official government or institutional portal address.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'Portrait photo on document; review if necessary to reveal.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.optional, 'Date of birth; share only if required by trusted recipient.'),
        SensitiveType.email: const RuleDecision(RedactionAction.optional, 'Personal contact email; keep if introducing, hide if private.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Personal contact phone; keep if introducing, hide if private.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.optional, 'Challan or certificate registration number.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'Document fee or declared value.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'Mask national ID unless recipient is statutory authority.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Mask PAN card number to prevent financial identity theft.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Mask Voter ID number to protect civil registry data.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number should remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch code should remain hidden.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded in personal documents.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded in personal documents.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'UPI handle is unneeded in personal documents.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
      },
      Audience.publicAudience: {
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General document chronological date.'),
        SensitiveType.url: const RuleDecision(RedactionAction.optional, 'Public institutional link.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal name should not be published in public domain.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to prevent facial recognition scraping.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must never be publicly exposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID must never be publicly exposed.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number must never be publicly exposed.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID must never be publicly exposed.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone number must remain private.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Email address must remain private.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account must remain hidden.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must remain hidden.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Document serial or transaction ID must remain hidden.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.hide, 'Fee amount must remain hidden.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'UPI handle must remain hidden.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },

    // -------------------------------------------------------------------------
    // 10. GENERAL
    // -------------------------------------------------------------------------
    Purpose.general: {
      Audience.privateAudience: {
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'General website or article link.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General date or time marker provides context.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.optional, 'Name mention; keep if relevant, hide if private.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'Numeric cost or price; keep if discussing quote.'),
        SensitiveType.face: const RuleDecision(RedactionAction.optional, 'Portrait detected; review before sharing.'),
        SensitiveType.email: const RuleDecision(RedactionAction.optional, 'Contact email; keep if introducing, hide if private.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.optional, 'Phone number; keep if intended contact, hide if private.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.optional, 'Reference number; keep if tracking mutual order.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.optional, 'Recipient payment address.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth is confidential personal data.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Sender payment handle is confidential personal data.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Payment handle is confidential personal data.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank branch code is confidential personal data.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number should not be shared in general media.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be shared.'),
      },
      Audience.publicAudience: {
        SensitiveType.url: const RuleDecision(RedactionAction.keep, 'Public website link.'),
        SensitiveType.dateTime: const RuleDecision(RedactionAction.keep, 'General date and time.'),
        SensitiveType.face: const RuleDecision(RedactionAction.blurFace, 'Blurs face to preserve privacy in public sphere.'),
        SensitiveType.personName: const RuleDecision(RedactionAction.hide, 'Personal name should remain private in public shares.'),
        SensitiveType.amount: const RuleDecision(RedactionAction.optional, 'General price or cost figure.'),
        SensitiveType.email: const RuleDecision(RedactionAction.hide, 'Email address must not be exposed to public.'),
        SensitiveType.phone: const RuleDecision(RedactionAction.hide, 'Phone number must not be exposed to public.'),
        SensitiveType.transactionId: const RuleDecision(RedactionAction.hide, 'Transaction reference must not be exposed to public.'),
        SensitiveType.recipientUpiId: const RuleDecision(RedactionAction.hide, 'Payment handle must not be exposed to public.'),
        SensitiveType.senderUpiId: const RuleDecision(RedactionAction.hide, 'Payment handle must not be exposed to public.'),
        SensitiveType.upiId: const RuleDecision(RedactionAction.hide, 'Payment handle must not be exposed to public.'),
        SensitiveType.ifsc: const RuleDecision(RedactionAction.hide, 'Bank details must not be exposed to public.'),
        SensitiveType.accountNumber: const RuleDecision(RedactionAction.hide, 'Bank account number must not be exposed to public.'),
        SensitiveType.card: const RuleDecision(RedactionAction.hide, 'Payment card details must remain private and unexposed.'),
        SensitiveType.aadhaar: const RuleDecision(RedactionAction.hide, 'National ID is confidential identity data.'),
        SensitiveType.pan: const RuleDecision(RedactionAction.hide, 'Tax number is confidential financial data.'),
        SensitiveType.voterId: const RuleDecision(RedactionAction.hide, 'Voter ID is confidential identity data.'),
        SensitiveType.dob: const RuleDecision(RedactionAction.hide, 'Date of birth must not be exposed to public.'),
        SensitiveType.credential: const RuleDecision(RedactionAction.hide, 'Passwords, PINs, and OTPs must never be broadcast publicly.'),
      },
    },
  };
}
