import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:didit_sdk/sdk_flutter.dart';
import '/backend/api_requests/kyc_api_service.dart';
// import 'package:provider/provider.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/widgets/common/back_chevron.dart';

import 'kycpage_model.dart';
export 'kycpage_model.dart';

/// Create a premium fintech KYC Verification page for the FARM app.
///
/// Theme:
///
/// * Black, white, and cream colors
/// * Modern fintech design
/// * Professional banking appearance
/// * Mobile-first design
///
/// Page Title:
/// Verify Your Identity
///
/// Subtitle:
/// Complete KYC verification to unlock deposits, withdrawals, escrow
/// services, and higher transaction limits.
///
/// Verification Progress:
///
/// * Step 1: Personal Information
/// * Step 2: Identity Verification
/// * Step 3: Selfie Verification
/// * Step 4: Address Verification
/// * Step 5: Review & Submit
///
/// SECTION 1: Personal Information
///
/// Fields:
///
/// * First Name
/// * Last Name
/// * Date of Birth
/// * Gender
/// * Nationality
/// * National ID Number
/// * Phone Number
/// * Email Address
///
/// SECTION 2: Identity Verification
///
/// Upload Fields:
///
/// * National ID Front
/// * National ID Back
/// * Passport (Optional)
///
/// Requirements:
///
/// * Clear image
/// * No glare
/// * All corners visible
///
/// SECTION 3: Selfie Verification
///
/// Features:
///
/// * Upload Selfie
/// * Face Verification Placeholder
/// * Selfie Guidelines
///
/// SECTION 4: Address Verification
///
/// Upload:
///
/// * Utility Bill
/// * Bank Statement
/// * Government Letter
///
/// Fields:
///
/// * Country
/// * County/State
/// * City
/// * Physical Address
/// * Postal Code
///
/// SECTION 5: Review & Submit
///
/// Display:
///
/// * Personal Information Summary
/// * Uploaded Documents
/// * Terms & Conditions Checkbox
///
/// Buttons:
///
/// * Save Draft
/// * Submit Verification
///
/// Verification Status Cards:
///
/// Pending Review
/// Under Review
/// Approved
/// Rejected
/// Additional Information Required
///
/// Rejected Status Screen:
///
/// * Reason for Rejection
/// * Re-upload Documents Button
///
/// Approved Status Screen:
///
/// * Verification Badge
/// * Verification Date
/// * Verification Level
///
/// Design Requirements:
///
/// * Premium digital banking feel
/// * Large upload cards
/// * Progress indicator
/// * Rounded corners
/// * Soft shadows
/// * FARM branding
/// * Professional compliance experience
///
/// The page should feel like a modern fintech KYC onboarding experience
/// similar to Revolut, Wise, Stripe, or Paystack.
class KycpageWidget extends StatefulWidget {
  const KycpageWidget({super.key, this.startDiditVerification = false});

  static String routeName = 'KYCPAGE';
  static String routePath = '/kycpage';

  final bool startDiditVerification;

  @override
  State<KycpageWidget> createState() => _KycpageWidgetState();
}

class _KycpageWidgetState extends State<KycpageWidget> {
  late KycpageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalController = TextEditingController();

  String _documentType = 'National ID';
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  bool _isStartingDiditVerification = false;
  bool _isLoadingSubmission = true;
  bool _isRefreshingSubmission = false;
  String? _submissionLoadError;
  Map<String, dynamic>? _existingSubmission;
  Timer? _submissionRefreshTimer;

  String? _frontImageName;
  String? _backImageName;
  String? _selfieImageName;
  String? _addressImageName;
  String? _frontImageBase64;
  String? _backImageBase64;
  String? _selfieImageBase64;
  String? _addressImageBase64;
  final Map<String, String> _imageMimeTypes = {};

  final ImagePicker _picker = ImagePicker();
  final CountryService _countryService = CountryService();

  // Dropdown and date picker selections
  String? _selectedGender;
  String? _selectedNationality;
  String? _selectedCountry;
  String? _selectedAddressCountryIsoCode;
  DateTime? _selectedDob;
  String _selectedCountryCode = '+1'; // Default to US
  String _selectedPhoneCountryIsoCode = 'US';

  final List<String> _genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _countries = [
    'Afghanistan',
    'Albania',
    'Algeria',
    'Andorra',
    'Angola',
    'Argentina',
    'Armenia',
    'Australia',
    'Austria',
    'Azerbaijan',
    'Bahamas',
    'Bahrain',
    'Bangladesh',
    'Barbados',
    'Belarus',
    'Belgium',
    'Belize',
    'Benin',
    'Bhutan',
    'Bolivia',
    'Bosnia and Herzegovina',
    'Botswana',
    'Brazil',
    'Brunei',
    'Bulgaria',
    'Burkina Faso',
    'Burundi',
    'Cambodia',
    'Cameroon',
    'Canada',
    'Cape Verde',
    'Central African Republic',
    'Chad',
    'Chile',
    'China',
    'Colombia',
    'Comoros',
    'Congo',
    'Costa Rica',
    'Croatia',
    'Cuba',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Djibouti',
    'Dominica',
    'Dominican Republic',
    'Ecuador',
    'Egypt',
    'El Salvador',
    'Equatorial Guinea',
    'Eritrea',
    'Estonia',
    'Eswatini',
    'Ethiopia',
    'Fiji',
    'Finland',
    'France',
    'Gabon',
    'Gambia',
    'Georgia',
    'Germany',
    'Ghana',
    'Greece',
    'Grenada',
    'Guatemala',
    'Guinea',
    'Guinea-Bissau',
    'Guyana',
    'Haiti',
    'Honduras',
    'Hungary',
    'Iceland',
    'India',
    'Indonesia',
    'Iran',
    'Iraq',
    'Ireland',
    'Israel',
    'Italy',
    'Jamaica',
    'Japan',
    'Jordan',
    'Kazakhstan',
    'Kenya',
    'Kiribati',
    'Kosovo',
    'Kuwait',
    'Kyrgyzstan',
    'Laos',
    'Latvia',
    'Lebanon',
    'Lesotho',
    'Liberia',
    'Libya',
    'Liechtenstein',
    'Lithuania',
    'Luxembourg',
    'Madagascar',
    'Malawi',
    'Malaysia',
    'Maldives',
    'Mali',
    'Malta',
    'Marshall Islands',
    'Mauritania',
    'Mauritius',
    'Mexico',
    'Micronesia',
    'Moldova',
    'Monaco',
    'Mongolia',
    'Montenegro',
    'Morocco',
    'Mozambique',
    'Myanmar',
    'Namibia',
    'Nauru',
    'Nepal',
    'Netherlands',
    'New Zealand',
    'Nicaragua',
    'Niger',
    'Nigeria',
    'North Korea',
    'North Macedonia',
    'Norway',
    'Oman',
    'Pakistan',
    'Palau',
    'Palestine',
    'Panama',
    'Papua New Guinea',
    'Paraguay',
    'Peru',
    'Philippines',
    'Poland',
    'Portugal',
    'Qatar',
    'Romania',
    'Russia',
    'Rwanda',
    'Saint Kitts and Nevis',
    'Saint Lucia',
    'Saint Vincent and the Grenadines',
    'Samoa',
    'San Marino',
    'Sao Tome and Principe',
    'Saudi Arabia',
    'Senegal',
    'Serbia',
    'Seychelles',
    'Sierra Leone',
    'Singapore',
    'Slovakia',
    'Slovenia',
    'Solomon Islands',
    'Somalia',
    'South Africa',
    'South Korea',
    'South Sudan',
    'Spain',
    'Sri Lanka',
    'Sudan',
    'Suriname',
    'Sweden',
    'Switzerland',
    'Syria',
    'Taiwan',
    'Tajikistan',
    'Tanzania',
    'Thailand',
    'Timor-Leste',
    'Togo',
    'Tonga',
    'Trinidad and Tobago',
    'Tunisia',
    'Turkey',
    'Turkmenistan',
    'Tuvalu',
    'Uganda',
    'Ukraine',
    'United Arab Emirates',
    'United Kingdom',
    'United States',
    'Uruguay',
    'Uzbekistan',
    'Vanuatu',
    'Vatican City',
    'Venezuela',
    'Vietnam',
    'Yemen',
    'Zambia',
    'Zimbabwe',
  ];

  String _flagForCountry(String country) {
    return _countryService.findByName(country)?.flagEmoji ?? '';
  }

  String _flagForCountryCode(String countryCode) {
    return _countryService.findByCode(countryCode)?.flagEmoji ?? '';
  }

  void _showPhoneCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: true,
      onSelect: (country) {
        setState(() {
          _selectedPhoneCountryIsoCode = country.countryCode;
          _selectedCountryCode = '+${country.phoneCode}';
        });
      },
    );
  }

  void _showAddressCountryPicker() {
    showCountryPicker(
      context: context,
      searchAutofocus: true,
      onSelect: (country) {
        setState(() {
          _selectedCountry = country.name;
          _selectedAddressCountryIsoCode = country.countryCode;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => KycpageModel());
    _loadExistingSubmission();
    _refreshDiditKycStatus();
    if (widget.startDiditVerification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startDiditVerification();
      });
    }
    _submissionRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshExistingSubmission();
      _refreshDiditKycStatus();
    });
  }

  @override
  void dispose() {
    _submissionRefreshTimer?.cancel();
    _model.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _loadExistingSubmission() async {
    try {
      final response = await ApiService.getMyKyc();
      final rawData = response['data'];
      if (rawData is! List) {
        throw const FormatException('Invalid KYC submission response.');
      }

      final submissions = rawData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final submission = submissions.isEmpty ? null : submissions.first;
      if (!mounted) return;

      setState(() {
        _existingSubmission = submission;
        _submissionLoadError = null;
        if (submission != null) {
          final submittedStatus = submission['status']
              ?.toString()
              .trim()
              .toLowerCase();
          if (submittedStatus != null && submittedStatus.isNotEmpty) {
            FFAppState().kycStatus = submittedStatus;
          }
          _populateFormFromSubmission(submission);
        }
        _isLoadingSubmission = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submissionLoadError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingSubmission = false;
      });
    }
  }

  Future<void> _refreshExistingSubmission() async {
    if (_isRefreshingSubmission || !_hasSubmittedKyc) return;
    _isRefreshingSubmission = true;
    try {
      final response = await ApiService.getMyKyc();
      final rawData = response['data'];
      if (rawData is! List) {
        throw const FormatException('Invalid KYC submission response.');
      }
      final submissions = rawData
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (submissions.isEmpty || !mounted) return;

      final submission = submissions.first;
      final status = submission['status']?.toString().trim().toLowerCase();
      setState(() {
        _existingSubmission = submission;
        _submissionLoadError = null;
        if (status != null && status.isNotEmpty) {
          FFAppState().kycStatus = status;
        }
      });
    } catch (error) {
      debugPrint('KYC submission status refresh failed: $error');
    } finally {
      _isRefreshingSubmission = false;
    }
  }

  Future<void> _refreshDiditKycStatus() async {
    try {
      final response = await ApiService.getProfile(timeoutSeconds: 10);
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final status = data['kyc_status'] ?? data['kycStatus'];
      if (status is String && status.trim().isNotEmpty && mounted) {
        setState(() => FFAppState().kycStatus = status);
      }
    } catch (error) {
      debugPrint('Didit KYC status refresh failed: $error');
    }
  }

  Future<void> _startDiditVerification() async {
    if (_isStartingDiditVerification) return;

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Before you continue'),
        content: const Text(
          'FARM will open Didit, our identity-verification provider. Didit '
          'will process your identity document, selfie, biometric information, '
          'and related verification data for KYC. Continue only if you consent '
          'to this processing. Your verification decision will be confirmed '
          'by FARM after a signed update from Didit; the app result alone is '
          'not proof of approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I consent and continue'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    setState(() => _isStartingDiditVerification = true);
    try {
      final session = await ApiService.createDiditSession();
      final sessionToken = session['session_token'];
      if (sessionToken is! String || sessionToken.isEmpty) {
        throw const FormatException(
          'The server returned an invalid Didit session.',
        );
      }

      final result = await DiditSdk.startVerification(sessionToken);
      if (!mounted) return;
      if (result is VerificationCancelled) {
        _snack('Verification was cancelled.');
      } else if (result is VerificationFailed) {
        _snack('Verification could not be completed. Please try again.');
      } else if (result is VerificationCompleted) {
        _snack(
          'Verification finished. FARM will update your status after '
          'receiving Didit’s signed confirmation.',
        );
        await _refreshDiditKycStatus();
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        _snack(
          message.isNotEmpty
              ? message
              : 'Could not start identity verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingDiditVerification = false);
    }
  }

  Widget _buildDiditVerificationCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verify with Didit',
            style: theme.titleSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete identity verification securely using Didit’s native '
            'camera and document flow. FARM confirms the decision from Didit’s '
            'signed server notification.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isStartingDiditVerification
                  ? null
                  : _startDiditVerification,
              icon: _isStartingDiditVerification
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(
                _isStartingDiditVerification
                    ? 'Opening verification...'
                    : 'Start identity verification',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _populateFormFromSubmission(Map<String, dynamic> submission) {
    _firstNameController.text =
        submission['first_name']?.toString() ?? _firstNameController.text;
    _lastNameController.text =
        submission['last_name']?.toString() ?? _lastNameController.text;
    _idNumberController.text =
        submission['document_number']?.toString() ?? _idNumberController.text;
    _phoneController.text =
        submission['phone']?.toString() ?? _phoneController.text;
    _emailController.text =
        submission['email']?.toString() ?? _emailController.text;
    _stateController.text =
        submission['county']?.toString() ?? _stateController.text;
    _cityController.text =
        submission['city']?.toString() ?? _cityController.text;
    _addressController.text =
        submission['physical_address']?.toString() ?? _addressController.text;
    _postalController.text =
        submission['postal_code']?.toString() ?? _postalController.text;

    final dateOfBirth = submission['date_of_birth']?.toString();
    if (dateOfBirth != null) {
      _selectedDob = DateTime.tryParse(dateOfBirth);
      if (_selectedDob != null) {
        _dobController.text =
            '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}';
      }
    }

    final documentType = submission['document_type']?.toString();
    if (documentType != null && documentType.isNotEmpty) {
      _documentType = documentType;
    }
    _selectedGender = submission['gender']?.toString();
    _selectedNationality = submission['nationality']?.toString();
    _selectedCountry = submission['country']?.toString();
  }

  bool get _hasSubmittedKyc {
    final status = (_existingSubmission?['status'] ?? FFAppState().kycStatus)
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return {
      'pending',
      'under_review',
      'verified',
      'approved',
      'complete',
      'success',
    }.contains(status);
  }

  bool get _isKycApproved {
    final status = (_existingSubmission?['status'] ?? FFAppState().kycStatus)
        .toString()
        .trim()
        .toLowerCase();
    return {'verified', 'approved', 'complete', 'success'}.contains(status);
  }

  bool get _isKycPending {
    final status = (_existingSubmission?['status'] ?? FFAppState().kycStatus)
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return {'pending', 'under_review', 'review'}.contains(status);
  }

  String _displaySubmissionValue(String key) {
    final value = _existingSubmission?[key];
    if (value == null || value.toString().trim().isEmpty) return 'Not provided';
    final text = value.toString();
    return key == 'date_of_birth' && text.length >= 10
        ? text.substring(0, 10)
        : text;
  }

  Widget _buildSubmissionStatusPage(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final approved = _isKycApproved;
    final pending = _isKycPending;
    final status = approved
        ? 'Approved'
        : pending
        ? 'Pending review'
        : 'Status unavailable';
    final fields = <MapEntry<String, String>>[
      const MapEntry('First name', 'first_name'),
      const MapEntry('Last name', 'last_name'),
      const MapEntry('Date of birth', 'date_of_birth'),
      const MapEntry('Gender', 'gender'),
      const MapEntry('Nationality', 'nationality'),
      const MapEntry('Document type', 'document_type'),
      const MapEntry('Document number', 'document_number'),
      const MapEntry('Phone number', 'phone'),
      const MapEntry('Email', 'email'),
      const MapEntry('Country', 'country'),
      const MapEntry('County / State', 'county'),
      const MapEntry('City', 'city'),
      const MapEntry('Physical address', 'physical_address'),
      const MapEntry('Postal code', 'postal_code'),
    ];

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackChevron(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      approved
                          ? Icons.verified_rounded
                          : Icons.hourglass_top_rounded,
                      size: 36,
                      color: approved ? Colors.green : theme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      approved
                          ? 'KYC Approved'
                          : pending
                          ? 'KYC Pending Approval'
                          : 'Unable to load KYC status',
                      style: theme.headlineSmall.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      approved
                          ? 'Your identity has been verified. You can now access KYC-protected features.'
                          : pending
                          ? 'Your verification is pending or under review. FARM will update your status after receiving the signed verification result.'
                          : 'Your KYC status could not be confirmed. Retry loading before submitting any details.',
                      style: theme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: approved
                            ? Colors.green.withValues(alpha: 0.12)
                            : theme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: theme.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: approved ? Colors.green : theme.primary,
                        ),
                      ),
                    ),
                    if (_existingSubmission == null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _submissionLoadError != null
                            ? 'Could not load KYC details: $_submissionLoadError'
                            : 'No KYC submission details were returned.',
                        style: theme.bodySmall,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _isLoadingSubmission = true);
                          _loadExistingSubmission();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
              if (!approved) ...[
                const SizedBox(height: 20),
                _buildDiditVerificationCard(context),
              ],
              if (_existingSubmission != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Submitted details',
                  style: theme.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      for (final field in fields)
                        if (_existingSubmission![field.value] != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    field.key,
                                    style: theme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _displaySubmissionValue(field.value),
                                    textAlign: TextAlign.end,
                                    style: theme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOrCaptureDocument(String key) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                key == 'selfie'
                    ? 'Choose Selfie Source'
                    : 'Choose Photo Source',
                style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt_rounded,
                color: FlutterFlowTheme.of(context).primary,
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture using your camera'),
              onTap: () async {
                Navigator.pop(context);
                await _captureDocumentPhoto(key);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: FlutterFlowTheme.of(context).primary,
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select from your device'),
              onTap: () async {
                Navigator.pop(context);
                await _pickDocumentFromGallery(key);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureDocumentPhoto(String key) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: key == 'selfie'
            ? CameraDevice.front
            : CameraDevice.rear,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      await _storeKycImage(key, picked);
    } catch (e) {
      _snack('Unable to capture photo: $e');
    }
  }

  Future<void> _pickDocumentFromGallery(String key) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      await _storeKycImage(key, picked);
    } catch (e) {
      _snack('Unable to pick image: $e');
    }
  }

  Future<void> _storeKycImage(String key, XFile picked) async {
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      _snack('Each image must be no larger than 5 MB.');
      return;
    }
    final mimeType = _normalizedMimeType(picked);
    if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      _snack('Choose a JPG, PNG, or WebP image.');
      return;
    }
    final base64Image = base64Encode(bytes);
    setState(() {
      _imageMimeTypes[key] = mimeType;
      switch (key) {
        case 'front':
          _frontImageName = picked.name;
          _frontImageBase64 = base64Image;
          break;
        case 'back':
          _backImageName = picked.name;
          _backImageBase64 = base64Image;
          break;
        case 'selfie':
          _selfieImageName = picked.name;
          _selfieImageBase64 = base64Image;
          break;
        case 'address':
          _addressImageName = picked.name;
          _addressImageBase64 = base64Image;
          break;
      }
    });
  }

  String _normalizedMimeType(XFile picked) {
    final detectedMimeType = picked.mimeType?.trim().toLowerCase();
    if (detectedMimeType != null && detectedMimeType.isNotEmpty) {
      if (detectedMimeType == 'image/jpg') return 'image/jpeg';
      if (const {
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/heic',
        'image/heif',
      }.contains(detectedMimeType)) {
        return detectedMimeType;
      }
    }
    switch (picked.name.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please complete all required fields.');
      return;
    }

    if (_frontImageBase64 == null) {
      _snack('Please upload your ID front image.');
      return;
    }
    if (_selfieImageBase64 == null) {
      _snack('Please upload a selfie image.');
      return;
    }
    if (!_termsAccepted) {
      _snack('Please accept the terms before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final imageKeys = <String>[
        'front',
        if (_backImageBase64 != null) 'back',
        'selfie',
        if (_addressImageBase64 != null) 'address',
      ];
      final imageData = <String>[
        _frontImageBase64!,
        if (_backImageBase64 != null) _backImageBase64!,
        _selfieImageBase64!,
        if (_addressImageBase64 != null) _addressImageBase64!,
      ];
      final imageUrls = await KycApiService.uploadImages(
        base64Images: imageData,
        filenames: imageKeys.map(_imageNameFor).toList(),
        mimeTypes: imageKeys
            .map((key) => _imageMimeTypes[key] ?? 'image/jpeg')
            .toList(),
      );
      var imageIndex = 0;
      final frontUrl = imageUrls[imageIndex++];
      final backUrl = _backImageBase64 == null ? null : imageUrls[imageIndex++];
      final selfieUrl = imageUrls[imageIndex++];
      final addressDocumentUrl = _addressImageBase64 == null
          ? null
          : imageUrls[imageIndex];

      final response = await ApiService.submitKyc(
        documentType: _documentType,
        frontImageUrl: frontUrl,
        backImageUrl: backUrl,
        selfieImageUrl: selfieUrl,
        addressDocumentUrl: addressDocumentUrl,
        documentNumber: _idNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _selectedDob != null
            ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
            : null,
        phoneNumber: '${_selectedCountryCode}${_phoneController.text.trim()}',
        email: _emailController.text.trim(),
        country: _selectedCountry?.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        postalCode: _postalController.text.trim(),
        gender: _selectedGender?.trim(),
        nationality: _selectedNationality?.trim(),
      );

      FFAppState().kycStatus = 'pending';
      final submitted = response['data'];
      final submittedDetails = submitted is Map
          ? Map<String, dynamic>.from(submitted)
          : <String, dynamic>{
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'date_of_birth': _dobController.text.trim(),
              'gender': _selectedGender,
              'nationality': _selectedNationality,
              'document_type': _documentType,
              'document_number': _idNumberController.text.trim(),
              'phone': '${_selectedCountryCode}${_phoneController.text.trim()}',
              'email': _emailController.text.trim(),
              'country': _selectedCountry,
              'county': _stateController.text.trim(),
              'city': _cityController.text.trim(),
              'physical_address': _addressController.text.trim(),
              'postal_code': _postalController.text.trim(),
            };
      submittedDetails['status'] = 'pending';
      setState(() {
        _existingSubmission = submittedDetails;
      });
      _snack(
        'KYC submitted. Your documents will be reviewed by admin shortly.',
      );
    } catch (e) {
      print('KYC submit error: $e');
      final message = e.toString().replaceFirst('Exception: ', '');
      _snack(
        message.isNotEmpty
            ? message
            : 'Submission failed. Please try again later.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _imageNameFor(String key) {
    final extension = switch (_imageMimeTypes[key]) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/jpeg' => 'jpg',
      _ => throw StateError('Unsupported KYC image type for $key'),
    };
    return '$key.$extension';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: FlutterFlowTheme.of(context).titleMedium.override(
            font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: FlutterFlowTheme.of(context).bodySmall),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: FlutterFlowTheme.of(context).bodySmall,
        filled: true,
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _uploadCard(
    String title,
    String subtitle,
    String? fileName,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: FlutterFlowTheme.of(context).titleSmall.override(
                font: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: FlutterFlowTheme.of(context).bodySmall),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fileName ?? 'Upload file',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const Icon(Icons.upload_file_rounded, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, String routeName) {
    return GestureDetector(
      onTap: () => context.pushNamed(routeName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FlutterFlowTheme.of(context).primary, size: 28),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingSubmission) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasSubmittedKyc || _submissionLoadError != null) {
      return _buildSubmissionStatusPage(context);
    }

    final lastStatus =
        (_existingSubmission?['status'] ?? FFAppState().kycStatus)
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_');
    final needsResubmission =
        lastStatus == 'rejected' || lastStatus == 'additional_info_required';
    final reviewReason = _existingSubmission?['rejection_reason']?.toString();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChevron(),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 32,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Verify Your Identity',
                        style: FlutterFlowTheme.of(context).headlineSmall
                            .override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Complete KYC verification to unlock deposits, withdrawals, escrow services, and higher transaction limits.',
                        style: FlutterFlowTheme.of(context).bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildDiditVerificationCard(context),
                if (needsResubmission) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.error),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastStatus == 'rejected'
                              ? 'KYC was not approved'
                              : 'Additional information required',
                          style: theme.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          reviewReason != null && reviewReason.trim().isNotEmpty
                              ? 'Please update your details and submit again. Admin feedback: $reviewReason'
                              : 'Please update your details and submit again for admin review.',
                          style: theme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader(
                        'Personal Information',
                        'Enter your basic details accurately.',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _firstNameController,
                        'First Name',
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _lastNameController,
                        'Last Name',
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(
                              context,
                            ).secondaryBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDob != null
                                    ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                                    : 'Date of Birth',
                                style: _selectedDob != null
                                    ? FlutterFlowTheme.of(context).bodyMedium
                                    : FlutterFlowTheme.of(context).bodySmall,
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: FlutterFlowTheme.of(
                                  context,
                                ).secondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(
                            context,
                          ).secondaryBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedGender,
                          hint: Text(
                            'Gender',
                            style: FlutterFlowTheme.of(context).bodySmall,
                          ),
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                          isExpanded: false,
                          items: _genderOptions
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedGender = value);
                            }
                          },
                          validator: (value) =>
                              value == null ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FormField<String>(
                        initialValue: _selectedNationality,
                        validator: (value) =>
                            value == null ||
                                (!_countries.contains(value) &&
                                    _countryService.findByName(value) == null)
                            ? 'Required'
                            : null,
                        builder: (field) => InkWell(
                          onTap: () => showCountryPicker(
                            context: context,
                            searchAutofocus: true,
                            onSelect: (country) {
                              setState(
                                () => _selectedNationality = country.name,
                              );
                              field.didChange(country.name);
                            },
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Nationality',
                              labelStyle: FlutterFlowTheme.of(
                                context,
                              ).bodySmall,
                              filled: true,
                              fillColor: FlutterFlowTheme.of(
                                context,
                              ).secondaryBackground,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                              errorText: field.errorText,
                            ),
                            child: Row(
                              children: [
                                if (_selectedNationality != null) ...[
                                  Text(_flagForCountry(_selectedNationality!)),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    _selectedNationality ?? 'Select country',
                                    style: _selectedNationality == null
                                        ? FlutterFlowTheme.of(context).bodySmall
                                        : FlutterFlowTheme.of(
                                            context,
                                          ).bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _idNumberController,
                        'ID Number',
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 116,
                            child: InkWell(
                              onTap: _showPhoneCountryPicker,
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Code',
                                  labelStyle: FlutterFlowTheme.of(
                                    context,
                                  ).bodySmall,
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(
                                    context,
                                  ).secondaryBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(
                                        context,
                                      ).alternate,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(
                                        context,
                                      ).alternate,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.arrow_drop_down,
                                    size: 20,
                                  ),
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 24,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _flagForCountryCode(
                                        _selectedPhoneCountryIsoCode,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '$_selectedPhoneCountryIsoCode '
                                        '$_selectedCountryCode',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(
                                          context,
                                        ).bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Required'
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: FlutterFlowTheme.of(
                                  context,
                                ).bodySmall,
                                filled: true,
                                fillColor: FlutterFlowTheme.of(
                                  context,
                                ).secondaryBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _emailController,
                        'Email Address',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(
                        'Identity Verification',
                        'Upload your ID documents and selfie.',
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(
                            context,
                          ).secondaryBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _documentType,
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                          items: ['National ID', 'Passport', 'Driver License']
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _documentType = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _uploadCard(
                        'ID Front',
                        'Front side of your selected document',
                        _frontImageName,
                        () => _pickOrCaptureDocument('front'),
                      ),
                      const SizedBox(height: 12),
                      _uploadCard(
                        'ID Back',
                        'Back side of your selected document',
                        _backImageName,
                        () => _pickOrCaptureDocument('back'),
                      ),
                      const SizedBox(height: 12),
                      _uploadCard(
                        'Selfie',
                        'Take or choose a selfie photo',
                        _selfieImageName,
                        () => _pickOrCaptureDocument('selfie'),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(
                        'Address Verification',
                        'This makes you eligible for the merchant account dashboard. Provide a recent proof of address and your location details.',
                      ),
                      const SizedBox(height: 16),
                      _uploadCard(
                        'Proof of Address (optional)',
                        'Utility bill, bank statement, or government letter',
                        _addressImageName,
                        () => _pickOrCaptureDocument('address'),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showAddressCountryPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Country',
                            labelStyle: FlutterFlowTheme.of(context).bodySmall,
                            filled: true,
                            fillColor: FlutterFlowTheme.of(
                              context,
                            ).secondaryBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                            ),
                            suffixIcon: const Icon(Icons.arrow_drop_down),
                          ),
                          child: Row(
                            children: [
                              if (_selectedAddressCountryIsoCode != null) ...[
                                Text(
                                  _flagForCountryCode(
                                    _selectedAddressCountryIsoCode!,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  _selectedCountry ?? 'Select country',
                                  style: _selectedCountry == null
                                      ? FlutterFlowTheme.of(context).bodySmall
                                      : FlutterFlowTheme.of(context).bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _stateController,
                        'County / State',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _cityController,
                        'City',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _addressController,
                        'Physical Address',
                        maxLines: 2,
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _postalController,
                        'Postal Code',
                        validator: (value) => null,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(
                            context,
                          ).secondaryBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review & Submit',
                              style: FlutterFlowTheme.of(context).titleSmall
                                  .override(
                                    font: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Check your details before submitting. You can still edit these fields if something is incorrect.',
                              style: FlutterFlowTheme.of(context).bodySmall,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (value) {
                                    setState(() {
                                      _termsAccepted = value ?? false;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Text(
                                    'I confirm that the information provided is accurate.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FFButtonWidget(
                                onPressed: _isSubmitting ? null : _submitKyc,
                                text: _isSubmitting
                                    ? 'Submitting...'
                                    : 'Submit KYC',
                                options: FFButtonOptions(
                                  width: double.infinity,
                                  height: 52,
                                  color: isDark
                                      ? const Color(0xFF1F1F1F)
                                      : Colors.black,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        fontFamily: 'Plus Jakarta Sans',
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _sectionHeader(
                        'Quick Actions',
                        'Jump to dashboard functions once your KYC is ready.',
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        padding: EdgeInsets.zero,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _quickAction(
                            'Send',
                            Icons.send_rounded,
                            'SendReceive',
                          ),
                          _quickAction(
                            'QR Scan',
                            Icons.qr_code_rounded,
                            'QRScanner',
                          ),
                          _quickAction(
                            'Escrow',
                            Icons.security_rounded,
                            'EscrowHub',
                          ),
                          _quickAction(
                            'Invest',
                            Icons.show_chart_rounded,
                            'InvestmentMarketplace',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
