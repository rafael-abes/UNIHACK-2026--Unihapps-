import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:country_picker/country_picker.dart';
import '../services/phone_auth.dart';
import 'otp.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final phoneController = TextEditingController();
  final PhoneAuthService _phoneAuthService = PhoneAuthService();
  bool isLoading = false;

  // Default to Australia +61
  Country _selectedCountry = Country(
    phoneCode: '61',
    countryCode: 'AU',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Australia',
    example: '412345678',
    displayName: 'Australia (AU) [+61]',
    displayNameNoCountryCode: 'Australia (AU)',
    e164Key: '61-AU-0',
  );

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true, // shows +61 etc alongside country name
      showSearch: true, // enables search bar at top
      favorite: ['AU', 'US', 'GB'], // pinned at top of list
      countryListTheme: CountryListThemeData(
        // bottom sheet height
        bottomSheetHeight: 600,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        // search field styling
        inputDecoration: InputDecoration(
          labelText: 'Search country',
          hintText: 'Start typing a country name',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        // list item text style
        textStyle: const TextStyle(fontSize: 16),
      ),
      onSelect: (Country country) {
        setState(() => _selectedCountry = country);
      },
    );
  }

  Future<void> sendOTP() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    // combine country code + number e.g. +61412345678
    final fullPhoneNumber = '+${_selectedCountry.phoneCode}$phone';
    setState(() => isLoading = true);

    await _phoneAuthService.sendOTP(
      phoneNumber: fullPhoneNumber,
      onVerificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      onVerificationFailed: (FirebaseAuthException e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Verification failed')),
        );
      },
      onCodeSent: (String verificationId, int? resendToken) {
        setState(() => isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OTPPage(verificationId: verificationId),
          ),
        );
      },
      onCodeAutoRetrievalTimeout: (String verificationId) {
        setState(() => isLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter your phone number',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'A verification code will be sent via SMS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // ── Country Code + Phone Number Row ──
            Row(
              children: [
                // Country code picker button
                GestureDetector(
                  onTap: _showCountryPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // flag emoji from country code
                        Text(
                          _selectedCountry.flagEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${_selectedCountry.phoneCode}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Phone number input
                Expanded(
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '412 345 678',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Shows full number preview
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Full number: +${_selectedCountry.phoneCode} ${phoneController.text}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : sendOTP,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }
}
