import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '/backend/services/api_service.dart';
import '/core/theme_extensions.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

// Removed unused imports flagged by analyzer

class ChangePinPageWidget extends StatefulWidget {
  const ChangePinPageWidget({super.key});

  static String routeName = 'change_pin_page';
  static String routePath = '/changePinPage';

  @override
  State<ChangePinPageWidget> createState() =>
      _ChangePinPageWidgetState();
}

class _ChangePinPageWidgetState
    extends State<ChangePinPageWidget> {
  String oldPin = '';
  String newPin = '';
  String confirmPin = '';

  bool step2 = false;
  bool step3 = false;

  bool isLoading = false;

  // ================= ADD DIGITS =================
  void add(String v) {
    setState(() {
      if (!step2 && oldPin.length < 4) {
        oldPin += v;

        if (oldPin.length == 4) {
          step2 = true;
        }
      } else if (!step3 &&
          newPin.length < 4) {
        newPin += v;

        if (newPin.length == 4) {
          step3 = true;
        }
      } else if (confirmPin.length < 4) {
        confirmPin += v;
      }
    });
  }

  // ================= DELETE =================
  void delete() {
    setState(() {
      if (confirmPin.isNotEmpty) {
        confirmPin = confirmPin.substring(
          0,
          confirmPin.length - 1,
        );
      } else if (newPin.isNotEmpty) {
        newPin = newPin.substring(
          0,
          newPin.length - 1,
        );
      } else if (oldPin.isNotEmpty) {
        oldPin = oldPin.substring(
          0,
          oldPin.length - 1,
        );
      }
    });
  }

  // ================= RESET =================
  void resetPins() {
    setState(() {
      oldPin = '';
      newPin = '';
      confirmPin = '';

      step2 = false;
      step3 = false;
    });
  }

  // ================= SUBMIT =================
  Future<void> submit() async {
    if (oldPin.length < 4 ||
        newPin.length < 4 ||
        confirmPin.length < 4) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Complete all PIN fields",
          ),
        ),
      );
      return;
    }

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "New PINs do not match",
          ),
        ),
      );

      setState(() {
        newPin = '';
        confirmPin = '';
        step3 = false;
      });

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.changePin(
        currentPin: oldPin,
        newPin: newPin,
        confirmPin: confirmPin,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message'] ?? 'PIN changed successfully',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userErrorMessage(e),
          ),
        ),
      );
      // If error message indicates old pin wrong, reset old pin
      final err = e.toString().toLowerCase();
      if (err.contains('old pin')) {
        setState(() {
          oldPin = '';
          step2 = false;
        });
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  // ================= DOTS =================
  Widget dots(String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.all(8),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < value.length ? Colors.white : context.borderColor,
          ),
        ),
      ),
    );
  }

  // ================= KEY =================
  Widget key(String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyBg = isDark ? Colors.grey[800] : Colors.black;
    final keyTxt = Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    final keySize = isCompact ? 62.0 : 72.0;
    final keyMargin = isCompact ? 6.0 : 8.0;

    return GestureDetector(
      onTap: () => add(value),
      child: Container(
        width: keySize,
        height: keySize,
        margin: EdgeInsets.all(keyMargin),
        decoration: BoxDecoration(
          color: keyBg,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            color: keyTxt,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ================= KEYPAD =================
  Widget keypad() {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ])
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: row
                .map((e) => key(e))
                .toList(),
          ),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            SizedBox(width: MediaQuery.of(context).size.width < 360 ? 78 : 90),

            key('0'),

            Container(
              width: MediaQuery.of(context).size.width < 360 ? 62 : 72,
              height: MediaQuery.of(context).size.width < 360 ? 62 : 72,
              margin: EdgeInsets.all(MediaQuery.of(context).size.width < 360 ? 6 : 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.black,
                borderRadius: BorderRadius.circular(18),
              ),
              child: IconButton(
                onPressed: delete,
                icon: Icon(
                  Icons.backspace_outlined,
                  size: 30,
                  color: Colors.white,
                ),
                splashRadius: 24,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: context.background,
        foregroundColor: context.onSurface,
        leading: const BackChevron(),
        title: Text(
          "Change PIN",
        ),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactHeight = constraints.maxHeight < 700;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: isCompactHeight ? 12 : 20),

                      Container(
                        width: 86,
                        height: 86,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.lock_reset,
                  color: context.onSurface,
                  size: 45,
                ),
              ),

                      SizedBox(height: isCompactHeight ? 20 : 28),

                      Text(
                !step2
                    ? "Enter Old PIN"
                    : !step3
                        ? "Enter New PIN"
                        : "Confirm New PIN",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.onSurface,
                ),
              ),

                      SizedBox(height: isCompactHeight ? 8 : 12),

                      Text(
                !step2
                    ? "Input your current transaction PIN"
                    : !step3
                        ? "Create a new secure PIN"
                        : "Confirm your new PIN",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 15,
                ),
              ),

                      SizedBox(height: isCompactHeight ? 20 : 32),

                      if (!step2) dots(oldPin),

              if (step2 && !step3)
                dots(newPin),

              if (step3) dots(confirmPin),

                      SizedBox(height: isCompactHeight ? 20 : 28),

                      keypad(),

                      SizedBox(height: isCompactHeight ? 16 : 24),

                      SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : submit,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppTheme.onAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Save PIN",
                            style: TextStyle(
                              color: AppTheme.onAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),

                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
