import 'dart:math' as math;
import 'diagnostic_logger.dart';
import 'luhn_checker.dart';
import 'verhoeff_checker.dart';
import 'models/bounding_box.dart';
import 'models/finding.dart';
import 'models/ocr_line.dart';
import 'models/sensitive_type.dart';

class PatternDetector {
  const PatternDetector();

  // Known Indian UPI bank / provider handles
  static const Set<String> _upiHandles = {
    'oksbi', 'okhdfcbank', 'okicici', 'okaxis', 'paytm', 'ybl', 'ibl',
    'upi', 'axl', 'apl', 'barodampay', 'federal', 'idfcbank', 'kotak',
    'postbank', 'pnb', 'sbi', 'hdfcbank', 'icici', 'allbank', 'aubank',
    'axisbank', 'bandhan', 'citi', 'dbs', 'indus', 'jsb', 'karurvysya',
    'kvb', 'rbl', 'sc', 'scb', 'sib', 'syn', 'unionbank', 'vijb', 'yesbank',
    'freecharge', 'airtel', 'waaxis', 'wahdfc', 'waicici', 'wasbi', 'fbl',
    'jupiteraxis', 'timeaxis', 'naviaxis', 'sliceaxis', 'superyes',
    'idfc', 'idfcfirst', 'axis', 'hdfc', 'ptaxis', 'pthdfc',
    'ptsbi', 'kmbl', 'slice', 'jupiter', 'cred', 'fam',
  };

  // 1. Transaction / UTR / Reference ID
  static final RegExp _transactionIdRegex = RegExp(
    r'\b(?:(?:Google(?:\s*Pay)?\s*)?Transaction\s*(?:ID|No\.?)|(?:UPI\s*)?Transaction\s*(?:ID|No\.?)|(?:UPI\s*)?Txn\.?\s*(?:ID|No\.?|#)?|(?:UPI\s*)?Ref\.?\s*(?:No\.?|ID|#)?|UTR(?:\s*No\.?)?|(?:UPI\s*)?RRN\.?|Order\s*(?:ID|No\.?)|Payment\s*(?:ID|Ref\.?|No\.?)|Bank\s*Ref(?:\s*No\.?)?)[\s:#.-]*([A-Za-z0-9_-]{8,30})\b|\b(?:UTR|IMPS|NEFT|RTGS)[0-9A-Za-z]{8,22}\b',
    caseSensitive: false,
  );

  // Standalone standalone transaction label line
  static final RegExp _txnLabelOnlyRegex = RegExp(
    r'^[\s]*(?:(?:Google(?:\s*Pay)?\s*)?Transaction\s*(?:ID|No\.?)|(?:UPI\s*)?Transaction\s*(?:ID|No\.?)|(?:UPI\s*)?Txn\.?\s*(?:ID|No\.?|#)?|(?:UPI\s*)?Ref\.?\s*(?:No\.?|ID|#)?|UTR(?:\s*No\.?)?|(?:UPI\s*)?RRN\.?|Order\s*(?:ID|No\.?)|Payment\s*(?:ID|Ref\.?|No\.?)|Bank\s*Ref(?:\s*No\.?)?)[\s:#.-]*$',
    caseSensitive: false,
  );

  // 2. Web URL: http/https or www.
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"{}|\\^`]+|\bwww\.[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^\s<>"{}|\\^`]*)',
    caseSensitive: false,
  );

  // 3. Email Address
  static final RegExp _emailRegex = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
  );

  // 4a. Sender UPI ID (preceded by sender cues)
  static final RegExp _senderUpiRegex = RegExp(
    r'\b(?:From|Sent\s*by|Debited\s*from|Sender)[\s:–-]+([a-zA-Z0-9.\-_]{2,64}@[a-zA-Z0-9]{2,24})\b(?!\.[a-zA-Z])',
    caseSensitive: false,
  );

  // 4b. Recipient UPI ID (preceded by recipient cues)
  static final RegExp _recipientUpiRegex = RegExp(
    r'\b(?:To|Paid\s*to|Sent\s*to|Credited\s*to|Receiver|Beneficiary)[\s:–-]+([a-zA-Z0-9.\-_]{2,64}@[a-zA-Z0-9]{2,24})\b(?!\.[a-zA-Z])',
    caseSensitive: false,
  );

  // 4c. Generic UPI ID
  static final RegExp _upiRegex = RegExp(
    r'\b([a-zA-Z0-9.\-_]{2,64})@([a-zA-Z0-9]{2,24})\b(?!\.[a-zA-Z])',
    caseSensitive: false,
  );

  // 4d. Numeric UPI ID / UPI Number (10 digits preceded by UPI label, not followed by @)
  static final RegExp _upiNumberRegex = RegExp(
    r'\b(?:UPI\s*ID|UPI\s*Number|UPI\s*No\.?|VPA)[\s:#.-]*([6-9]\d{9})\b(?![@a-zA-Z])',
    caseSensitive: false,
  );

  // 4e. Standalone UPI label line
  static final RegExp _upiLabelOnlyRegex = RegExp(
    r'^[\s]*(?:UPI\s*ID|VPA|Paid\s*to\s*UPI|UPI\s*Number)[\s:#.-]*$',
    caseSensitive: false,
  );

  // 5. PAN Card: 5 uppercase letters, 4 digits, 1 uppercase letter
  static final RegExp _panRegex = RegExp(
    r'\b[A-Z]{5}[0-9]{4}[A-Z]\b',
  );

  // 6. Voter ID (EPIC): 3 letters followed by 7 digits
  static final RegExp _voterIdRegex = RegExp(
    r'\b[A-Z]{3}[0-9]{7}\b',
  );

  static final RegExp _labeledVoterIdRegex = RegExp(
    r'\b(?:Voter\s*(?:ID|Card)|EPIC(?:\s*No\.?)?)[\s:#.-]*([A-Z0-9]{8,14})\b',
    caseSensitive: false,
  );

  // 7. Date of Birth (DOB) with contextual keywords
  static final RegExp _dobRegex = RegExp(
    r'\b(?:DOB|Date\s*of\s*Birth|Birth\s*Date|Year\s*of\s*Birth|YOB)[\s:–-]+([0-9]{1,2}[-\/.][0-9]{1,2}[-\/.][0-9]{2,4}|[0-9]{1,2}\s+[A-Za-z]{3,}\s+[0-9]{2,4}|[0-9]{4})\b',
    caseSensitive: false,
  );

  // 8. Credentials / Passwords / OTPs
  static final RegExp _credentialRegex = RegExp(
    r'\b(?:OTP|One\s*Time\s*Password|Password|Passcode|PIN|Secret\s*Key)[\s:–-]+([0-9]{4,8}|[A-Za-z0-9@#$!%*?&]{6,20})\b',
    caseSensitive: false,
  );

  // 9. IFSC Code: 4 uppercase letters, 0, 6 alphanumeric
  static final RegExp _ifscRegex = RegExp(
    r'\b[A-Z]{4}0[A-Z0-9]{6}\b',
  );

  // 10. Bank Account with Keyword
  static final RegExp _accountWithKeywordRegex = RegExp(
    r'\b(?:A\/C|Account|Acc|A\/c)(?:\s*No\.?|\s*Number|\s*ending)?[\s:#-]*([0-9Xx*•.\s-]{4,22})\b',
    caseSensitive: false,
  );

  // 11. Payment Card candidate: 13 to 19 digits (including Amex 4-6-5 format)
  static final RegExp _cardCandidateRegex = RegExp(
    r'\b(?:\d{4}[ -]\d{6}[ -]\d{5}|(?:\d{4}[ -]?){3,4}\d{1,4}|\d{13,19})\b',
  );

  // 12. Aadhaar Number candidate: 12 digits starting with 2-9
  static final RegExp _aadhaarRegex = RegExp(
    r'\b[2-9]\d{3}[\s-]?[0-9]{4}[\s-]?[0-9]{4}\b',
  );

  // 13. Phone Number: Indian (+91 98765 43210, 9876543210, 09876543210) & International
  static final RegExp _phoneRegex = RegExp(
    r'(?:\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b|(?:\+91[\s-]?)?[6-9]\d{9}\b|(?:\+91[\s-]?)?[6-9]\d{3}[\s-]?\d{3}[\s-]?\d{4}\b|\b0[6-9]\d{9}\b|\+1[\s.-]?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b|\+\d{1,3}[\s.-]?(?:\(?\d{2,4}\)?[\s.-]?){2,3}\d{2,4}\b',
  );

  // Labeled Phone
  static final RegExp _labeledPhoneRegex = RegExp(
    r'\b(?:Phone|Mobile|Mob|Tel|Contact)[\s:–.-]*(?:\+91[\s-]?)?([0]?[6-9]\d{9}|[6-9]\d{4}[\s-]?\d{5})\b',
    caseSensitive: false,
  );

  // 14. Payment Amount
  static final RegExp _amountRegex = RegExp(
    r'(?:[₹$€£]|Rs\.?|INR|USD|EUR)\s*(?:[0-9]{1,3}(?:,[0-9]{2,3})*|[0-9]+)(?:\.[0-9]{1,2})?\b|\b(?:Amount|Paid|Total\s*Paid|Total)[\s:–-]+(?:[₹$€£]|Rs\.?|INR)?\s*([0-9]{1,3}(?:,[0-9]{2,3})*|[0-9]+(?:\.[0-9]{2}))\b',
    caseSensitive: false,
  );

  // Standalone amount label line
  static final RegExp _amountLabelOnlyRegex = RegExp(
    r'^[\s]*(?:Amount|Paid|Total\s*Paid|Total)[\s:–-]*$',
    caseSensitive: false,
  );

  // 15. Date & Time
  static final RegExp _dateRegex = RegExp(
    r'\b(?:\d{1,2}[-\/.]\d{1,2}[-\/.]\d{2,4}|\d{4}[-\/.]\d{1,2}[-\/.]\d{1,2})\b|\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b',
    caseSensitive: false,
  );

  static final RegExp _timeRegex = RegExp(
    r'\b\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM|am|pm|IST|UTC|GMT)?\b',
  );

  // 16. Person Name via strict label proximity ONLY ("To", "From", "Paid to", "Name", "Customer Name", "S/O", "D/O", "W/O")
  static final RegExp _nameLabelProximityRegex = RegExp(
    r'\b(?:To|From|Paid\s*to|Name|Customer\s*Name|Sender|Recipient|Receiver|S\/O|D\/O|W\/O)[\s:–-]+([A-Z][a-zA-Z]{1,20}(?:\s+[A-Z][a-zA-Z]{1,20}){1,3})\b',
    caseSensitive: false,
  );

  // Standalone name label line
  static final RegExp _nameLabelOnlyRegex = RegExp(
    r'^[\s]*(?:Paid\s*to|To|From|Sender|Recipient|Receiver|Customer\s*Name)[\s:–-]*$',
    caseSensitive: false,
  );

  // Words that disqualify a candidate from being a person name
  static const Set<String> _nonNameKeywords = {
    'bank', 'account', 'google', 'phonepe', 'paytm', 'upi', 'limited',
    'ltd', 'inc', 'corp', 'branch', 'card', 'payment', 'transfer', 'service',
    'support', 'transaction', 'ref', 'utr', 'order', 'success', 'failed',
    'completed', 'pending', 'rupees', 'rs', 'inr', 'credited', 'debited'
  };

  /// Scans OCR lines and returns a list of detected sensitive findings with mapped bounding boxes,
  /// confidence scores, source, and detection status. Overlapping matches are deduplicated
  /// favoring higher-confidence and more specific types.
  List<Finding> detectFindings(List<OcrLine> lines) {
    final stopwatch = Stopwatch()..start();
    final List<Finding> findings = [];
    int totalCandidates = 0;

    for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      final line = lines[lineIdx];
      final lineText = line.text;
      if (lineText.trim().isEmpty) continue;

      final previousLineText = lineIdx > 0 ? lines[lineIdx - 1].text.trim() : '';

      final List<_CandidateMatch> candidates = [];

      // 1. Transaction / UTR / Reference IDs on current line
      for (final match in _transactionIdRegex.allMatches(lineText)) {
        final matchedStr = match.group(0)!;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.transactionId,
            matchedText: matchedStr,
            start: match.start,
            end: match.end,
            confidence: 0.95,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 1b. Multi-line transaction ID: previous line was transaction label
      if (_txnLabelOnlyRegex.hasMatch(previousLineText)) {
        final trimmed = lineText.trim();
        final idMatch = RegExp(r'^[A-Za-z0-9_-]{8,30}$').firstMatch(trimmed);
        if (idMatch != null) {
          final sIdx = lineText.indexOf(trimmed);
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.transactionId,
              matchedText: trimmed,
              start: sIdx >= 0 ? sIdx : 0,
              end: (sIdx >= 0 ? sIdx : 0) + trimmed.length,
              confidence: 0.96,
              source: FindingSource.ocr,
              status: DetectionStatus.inferred,
            ),
          );
        }
      }

      // 2. Web URLs
      for (final match in _urlRegex.allMatches(lineText)) {
        var urlStr = match.group(0)!;
        urlStr = urlStr.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
        final endPos = match.start + urlStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.url,
            matchedText: urlStr,
            start: match.start,
            end: endPos,
            confidence: 0.90,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 3. Email Addresses
      for (final match in _emailRegex.allMatches(lineText)) {
        final emailStr = match.group(0)!;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.email,
            matchedText: emailStr,
            start: match.start,
            end: match.end,
            confidence: 0.95,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 4a. Sender UPI IDs (with contextual cue)
      for (final match in _senderUpiRegex.allMatches(lineText)) {
        final upiStr = match.group(1)!;
        final startIdx = match.start + match.group(0)!.indexOf(upiStr);
        final endIdx = startIdx + upiStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.senderUpiId,
            matchedText: upiStr,
            start: startIdx,
            end: endIdx,
            confidence: 0.92,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 4b. Recipient UPI IDs (with contextual cue)
      for (final match in _recipientUpiRegex.allMatches(lineText)) {
        final upiStr = match.group(1)!;
        final startIdx = match.start + match.group(0)!.indexOf(upiStr);
        final endIdx = startIdx + upiStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.recipientUpiId,
            matchedText: upiStr,
            start: startIdx,
            end: endIdx,
            confidence: 0.92,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 4c. Generic UPI IDs
      for (final match in _upiRegex.allMatches(lineText)) {
        final domain = match.group(2)?.toLowerCase() ?? '';
        final fullMatch = match.group(0)!;
        final isKnownUpi = _upiHandles.contains(domain);
        final hasNoDot = !domain.contains('.');
        final hasTrailingDot = match.end < lineText.length && lineText[match.end] == '.';

        if ((isKnownUpi || hasNoDot) && !hasTrailingDot) {
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.upiId,
              matchedText: fullMatch,
              start: match.start,
              end: match.end,
              confidence: 0.90,
              source: FindingSource.ocr,
              status: DetectionStatus.detected,
            ),
          );
        }
      }

      // 4d. Numeric UPI IDs / UPI Numbers (10 digits with UPI/VPA label)
      for (final match in _upiNumberRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.upiId,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.92,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 4e. Multi-line UPI: previous line was UPI label
      if (_upiLabelOnlyRegex.hasMatch(previousLineText)) {
        final trimmed = lineText.trim();
        if (_upiRegex.hasMatch(trimmed) || RegExp(r'^[6-9]\d{9}$').hasMatch(trimmed)) {
          final sIdx = lineText.indexOf(trimmed);
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.upiId,
              matchedText: trimmed,
              start: sIdx >= 0 ? sIdx : 0,
              end: (sIdx >= 0 ? sIdx : 0) + trimmed.length,
              confidence: 0.92,
              source: FindingSource.ocr,
              status: DetectionStatus.inferred,
            ),
          );
        }
      }

      // 5. PAN Cards
      for (final match in _panRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.pan,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.98,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 6. Voter ID (EPIC)
      for (final match in _voterIdRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.voterId,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.96,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }
      for (final match in _labeledVoterIdRegex.allMatches(lineText)) {
        final idStr = match.group(1)!;
        final startIdx = match.start + match.group(0)!.indexOf(idStr);
        final endIdx = startIdx + idStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.voterId,
            matchedText: idStr,
            start: startIdx,
            end: endIdx,
            confidence: 0.96,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 7. Date of Birth (DOB) with contextual keywords
      for (final match in _dobRegex.allMatches(lineText)) {
        final dobStr = match.group(1)!;
        final startIdx = match.start + match.group(0)!.indexOf(dobStr);
        final endIdx = startIdx + dobStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.dob,
            matchedText: dobStr,
            start: startIdx,
            end: endIdx,
            confidence: 0.92,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 8. Credentials / Passwords / OTPs
      for (final match in _credentialRegex.allMatches(lineText)) {
        final credStr = match.group(1)!;
        final startIdx = match.start + match.group(0)!.indexOf(credStr);
        final endIdx = startIdx + credStr.length;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.credential,
            matchedText: credStr,
            start: startIdx,
            end: endIdx,
            confidence: 0.96,
            source: FindingSource.ocr,
            status: DetectionStatus.inferred,
          ),
        );
      }

      // 9. IFSC Codes
      for (final match in _ifscRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.ifsc,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.98,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 10. Bank Account with Keyword (unmasked or masked)
      for (final match in _accountWithKeywordRegex.allMatches(lineText)) {
        final fullMatch = match.group(0)!;
        final rawAccount = match.group(1)?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
        final digitCount = rawAccount.replaceAll(RegExp(r'\D'), '').length;
        final isMaskedOrEnding = rawAccount.contains(RegExp(r'[Xx*•.]')) ||
            fullMatch.toLowerCase().contains('ending');

        final isValid = isMaskedOrEnding
            ? (digitCount >= 3 && rawAccount.length >= 4 && rawAccount.length <= 22)
            : (rawAccount.length >= 9 && rawAccount.length <= 22);

        if (isValid) {
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.accountNumber,
              matchedText: fullMatch,
              start: match.start,
              end: match.end,
              confidence: 0.96,
              source: FindingSource.ocr,
              status: DetectionStatus.detected,
            ),
          );
        }
      }

      // 11. Payment Cards (Validated with Luhn check)
      for (final match in _cardCandidateRegex.allMatches(lineText)) {
        final candidate = match.group(0)!;
        if (LuhnChecker.validate(candidate)) {
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.card,
              matchedText: candidate,
              start: match.start,
              end: match.end,
              confidence: 0.99,
              source: FindingSource.ocr,
              status: DetectionStatus.detected,
            ),
          );
        }
      }

      // 12. Aadhaar Numbers (12 digits with Verhoeff validation)
      for (final match in _aadhaarRegex.allMatches(lineText)) {
        final candidate = match.group(0)!;
        final digitsOnly = candidate.replaceAll(RegExp(r'\D'), '');
        final precededByPlus = match.start > 0 && lineText[match.start - 1] == '+';
        final isPhoneCountryCode = match.start >= 2 && lineText.substring(match.start - 2, match.start) == '91';
        final isPrecededByTxnLabel = _txnLabelOnlyRegex.hasMatch(previousLineText);

        final prefixOnSameLine = lineText.substring(0, match.start).toLowerCase();
        final isPrecededByTxnPrefix = prefixOnSameLine.contains('ref') ||
            prefixOnSameLine.contains('utr') ||
            prefixOnSameLine.contains('txn') ||
            prefixOnSameLine.contains('order') ||
            prefixOnSameLine.contains('payment') ||
            prefixOnSameLine.contains('trans');

        if (digitsOnly.length == 12 &&
            !_isDate(candidate) &&
            !precededByPlus &&
            !isPhoneCountryCode &&
            !isPrecededByTxnLabel &&
            !isPrecededByTxnPrefix) {
          final passesVerhoeff = VerhoeffChecker.validate(digitsOnly);
          final hasAadhaarContext = lineText.toLowerCase().contains('aadhaar') ||
              lineText.toLowerCase().contains('uidai') ||
              lineText.toLowerCase().contains('uid') ||
              previousLineText.toLowerCase().contains('aadhaar') ||
              previousLineText.toLowerCase().contains('uidai');

          final double conf = passesVerhoeff ? 0.99 : (hasAadhaarContext ? 0.95 : 0.88);
          final status = (passesVerhoeff || !hasAadhaarContext)
              ? DetectionStatus.detected
              : DetectionStatus.inferred;

          candidates.add(
            _CandidateMatch(
              type: SensitiveType.aadhaar,
              matchedText: candidate,
              start: match.start,
              end: match.end,
              confidence: conf,
              source: FindingSource.ocr,
              status: status,
            ),
          );
        }
      }

      // 13. Phone Numbers (Indian & International, and labeled)
      for (final match in _phoneRegex.allMatches(lineText)) {
        final phoneCandidate = match.group(0)!;
        if (!_isDate(phoneCandidate)) {
          final digits = phoneCandidate.replaceAll(RegExp(r'\D'), '');
          if (digits.length >= 10 && digits.length <= 15) {
            final hasCountryCode = phoneCandidate.startsWith('+') || phoneCandidate.startsWith('0');
            candidates.add(
              _CandidateMatch(
                type: SensitiveType.phone,
                matchedText: phoneCandidate,
                start: match.start,
                end: match.end,
                confidence: hasCountryCode ? 0.96 : 0.90,
                source: FindingSource.ocr,
                status: DetectionStatus.detected,
              ),
            );
          }
        }
      }

      for (final match in _labeledPhoneRegex.allMatches(lineText)) {
        final fullMatch = match.group(0)!;
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.phone,
            matchedText: fullMatch,
            start: match.start,
            end: match.end,
            confidence: 0.96,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 14. Payment Amount
      for (final match in _amountRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.amount,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.90,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 14b. Multi-line amount: previous line was Amount label
      if (_amountLabelOnlyRegex.hasMatch(previousLineText)) {
        final trimmed = lineText.trim();
        final amountNumMatch = RegExp(r'^(?:[₹$€£]|Rs\.?|INR|USD|EUR)?\s*([0-9]{1,3}(?:,[0-9]{2,3})*|[0-9]+(?:\.[0-9]{1,2})?)$').firstMatch(trimmed);
        if (amountNumMatch != null && trimmed.isNotEmpty) {
          final sIdx = lineText.indexOf(trimmed);
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.amount,
              matchedText: trimmed,
              start: sIdx >= 0 ? sIdx : 0,
              end: (sIdx >= 0 ? sIdx : 0) + trimmed.length,
              confidence: 0.90,
              source: FindingSource.ocr,
              status: DetectionStatus.inferred,
            ),
          );
        }
      }

      // 15. Date & Time (only if not already matched as DOB)
      for (final match in _dateRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.dateTime,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.85,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }
      for (final match in _timeRegex.allMatches(lineText)) {
        candidates.add(
          _CandidateMatch(
            type: SensitiveType.dateTime,
            matchedText: match.group(0)!,
            start: match.start,
            end: match.end,
            confidence: 0.85,
            source: FindingSource.ocr,
            status: DetectionStatus.detected,
          ),
        );
      }

      // 16. Person Name via strict label proximity ONLY ("To", "From", "Paid to", "Name", "Customer Name", "S/O", "D/O", "W/O")
      for (final match in _nameLabelProximityRegex.allMatches(lineText)) {
        final nameCandidate = match.group(1)!.trim();
        final words = nameCandidate.toLowerCase().split(RegExp(r'\s+'));
        final containsDisqualifiedWord = words.any((w) => _nonNameKeywords.contains(w));

        if (!containsDisqualifiedWord && nameCandidate.length >= 3) {
          final startIdx = match.start + match.group(0)!.indexOf(nameCandidate);
          final endIdx = startIdx + nameCandidate.length;
          candidates.add(
            _CandidateMatch(
              type: SensitiveType.personName,
              matchedText: nameCandidate,
              start: startIdx,
              end: endIdx,
              confidence: 0.45, // Low confidence by design
              source: FindingSource.rule,
              status: DetectionStatus.inferred,
            ),
          );
        }
      }

      // 16b. Person Name: previous line was name label
      if (_nameLabelOnlyRegex.hasMatch(previousLineText)) {
        final trimmed = lineText.trim();
        final isCandidate = RegExp(r'^[A-Z][a-zA-Z]{1,20}(?:\s+[A-Z][a-zA-Z]{1,20}){1,3}$').hasMatch(trimmed);
        if (isCandidate) {
          final words = trimmed.toLowerCase().split(RegExp(r'\s+'));
          final containsDisqualifiedWord = words.any((w) => _nonNameKeywords.contains(w));
          if (!containsDisqualifiedWord && trimmed.length >= 3) {
            final sIdx = lineText.indexOf(trimmed);
            candidates.add(
              _CandidateMatch(
                type: SensitiveType.personName,
                matchedText: trimmed,
                start: sIdx >= 0 ? sIdx : 0,
                end: (sIdx >= 0 ? sIdx : 0) + trimmed.length,
                confidence: 0.45, // Low confidence
                source: FindingSource.rule,
                status: DetectionStatus.inferred,
              ),
            );
          }
        }
      }

      totalCandidates += candidates.length;

      // Deduplicate overlaps on the current line favoring higher confidence and longer match spans
      candidates.sort((a, b) {
        final confCmp = b.confidence.compareTo(a.confidence);
        if (confCmp != 0) return confCmp;
        return (b.end - b.start).compareTo(a.end - a.start);
      });

      final List<_Span> occupiedSpans = [];
      for (final candidate in candidates) {
        if (!_isOverlapping(occupiedSpans, candidate.start, candidate.end)) {
          occupiedSpans.add(_Span(candidate.start, candidate.end));
          final box = _computeBoundingBox(line, candidate.start, candidate.end);
          findings.add(
            Finding(
              type: candidate.type,
              matchedText: candidate.matchedText,
              boundingBox: box,
              confidence: candidate.confidence,
              source: candidate.source,
              status: candidate.status,
            ),
          );
        }
      }
    }

    // Image-level deduplication: deduplicate identical findings that share close bounding boxes
    final List<Finding> deduplicated = [];
    for (final f in findings) {
      bool isDupe = false;
      for (final existing in deduplicated) {
        if (existing.type == f.type && existing.matchedText == f.matchedText) {
          // Check box intersection over union
          final iou = _calculateIoU(existing.boundingBox, f.boundingBox);
          if (iou > 0.4 || (existing.boundingBox.left == f.boundingBox.left && existing.boundingBox.top == f.boundingBox.top)) {
            isDupe = true;
            break;
          }
        }
      }
      if (!isDupe) {
        deduplicated.add(f);
      }
    }

    stopwatch.stop();

    // Collect anonymous type counts for diagnostic logging
    final Map<String, int> typeCounts = {};
    for (final f in deduplicated) {
      typeCounts[f.type.name] = (typeCounts[f.type.name] ?? 0) + 1;
    }

    DiagnosticLogger.logPatternScan(
      linesScanned: lines.length,
      candidateCount: totalCandidates,
      finalFindingCount: deduplicated.length,
      typeCounts: typeCounts,
      durationMs: stopwatch.elapsedMilliseconds,
    );

    return deduplicated;
  }

  double _calculateIoU(BoundingBox a, BoundingBox b) {
    final xA = math.max(a.left, b.left);
    final yA = math.max(a.top, b.top);
    final xB = math.min(a.right, b.right);
    final yB = math.min(a.bottom, b.bottom);

    final interWidth = math.max(0.0, xB - xA);
    final interHeight = math.max(0.0, yB - yA);
    final interArea = interWidth * interHeight;

    final boxAArea = a.width * a.height;
    final boxBArea = b.width * b.height;
    final unionArea = boxAArea + boxBArea - interArea;

    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  bool _isDate(String text) {
    return _dateRegex.hasMatch(text);
  }

  bool _isOverlapping(List<_Span> spans, int start, int end) {
    for (final span in spans) {
      if (start < span.end && end > span.start) {
        return true;
      }
    }
    return false;
  }

  /// Maps character range [startIndex, endIndex) back to the bounding box
  /// of the OCR line and its constituent elements.
  BoundingBox _computeBoundingBox(OcrLine line, int startIndex, int endIndex) {
    if (line.elements.isEmpty || line.text.isEmpty) {
      return line.boundingBox;
    }

    int currentPos = 0;
    final List<BoundingBox> matchingBoxes = [];

    for (final element in line.elements) {
      final elemIndex = line.text.indexOf(element.text, currentPos);
      final elStart = elemIndex != -1 ? elemIndex : currentPos;
      final elEnd = elStart + element.text.length;
      currentPos = elEnd;

      if (startIndex < elEnd && endIndex > elStart) {
        if (startIndex <= elStart && endIndex >= elEnd) {
          matchingBoxes.add(element.boundingBox);
        } else {
          final overlapStart = math.max(startIndex, elStart);
          final overlapEnd = math.min(endIndex, elEnd);
          final elemLen = math.max(1, element.text.length);

          final ratioStart = (overlapStart - elStart) / elemLen;
          final ratioEnd = (overlapEnd - elStart) / elemLen;

          final subLeft = element.boundingBox.left + ratioStart * element.boundingBox.width;
          final subWidth = (ratioEnd - ratioStart) * element.boundingBox.width;

          matchingBoxes.add(
            BoundingBox(
              left: subLeft,
              top: element.boundingBox.top,
              width: subWidth,
              height: element.boundingBox.height,
            ),
          );
        }
      }
    }

    if (matchingBoxes.isEmpty) {
      final totalLen = math.max(1, line.text.length);
      final startRatio = startIndex / totalLen;
      final endRatio = endIndex / totalLen;

      return BoundingBox(
        left: line.boundingBox.left + startRatio * line.boundingBox.width,
        top: line.boundingBox.top,
        width: (endRatio - startRatio) * line.boundingBox.width,
        height: line.boundingBox.height,
      );
    }

    double minLeft = matchingBoxes.first.left;
    double minTop = matchingBoxes.first.top;
    double maxRight = matchingBoxes.first.right;
    double maxBottom = matchingBoxes.first.bottom;

    for (int i = 1; i < matchingBoxes.length; i++) {
      final b = matchingBoxes[i];
      if (b.left < minLeft) minLeft = b.left;
      if (b.top < minTop) minTop = b.top;
      if (b.right > maxRight) maxRight = b.right;
      if (b.bottom > maxBottom) maxBottom = b.bottom;
    }

    return BoundingBox(
      left: minLeft,
      top: minTop,
      width: maxRight - minLeft,
      height: maxBottom - minTop,
    );
  }
}

class _Span {
  final int start;
  final int end;

  const _Span(this.start, this.end);
}

class _CandidateMatch {
  final SensitiveType type;
  final String matchedText;
  final int start;
  final int end;
  final double confidence;
  final FindingSource source;
  final DetectionStatus status;

  const _CandidateMatch({
    required this.type,
    required this.matchedText,
    required this.start,
    required this.end,
    required this.confidence,
    required this.source,
    required this.status,
  });
}
