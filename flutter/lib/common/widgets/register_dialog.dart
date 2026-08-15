import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/user_model.dart';
import '../utils/http_service.dart' as http;
import 'dialog.dart';

Future<bool?> registerDialog() async {
  return Get.dialog<bool>(
    AlertDialog(
      title: Text("Kayıt Ol - AcilBir"),
      content: const SingleChildScrollView(
        child: RegisterWidget(),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text(translate('Cancel')),
        ),
      ],
    ),
    barrierDismissible: false,
  );
}

class RegisterWidget extends StatefulWidget {
  const RegisterWidget({Key? key}) : super(key: key);

  @override
  _RegisterWidgetState createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  String accountType = 'individual';
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final orgName = TextEditingController();
  final taxId = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  String? emailMsg;
  String? passMsg;
  String? confirmPassMsg;
  String? orgMsg;
  bool isInProgress = false;

  void submit() async {
    setState(() {
      emailMsg = null;
      passMsg = null;
      confirmPassMsg = null;
      orgMsg = null;
    });

    if (email.text.trim().isEmpty) {
      setState(() => emailMsg = "E-posta zorunlu");
      return;
    }
    if (password.text.length < 6) {
      setState(() => passMsg = "Şifre en az 6 karakter olmalı");
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(() => confirmPassMsg = "Şifreler eşleşmiyor");
      return;
    }
    if ((accountType == 'company' || accountType == 'reseller') && orgName.text.trim().isEmpty) {
      setState(() => orgMsg = "Firma adı zorunlu");
      return;
    }

    setState(() {
      isInProgress = true;
    });

    try {
      final url = await bind.mainGetApiServer();
      final body = {
        'accountType': accountType,
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim(),
        'orgName': orgName.text.trim(),
        'taxId': taxId.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'confirmPassword': confirmPassword.text,
        'locale': 'tr',
      };

      final response = await http.post(
        Uri.parse('$url/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode != 200) {
        throw data['error'] ?? 'Kayıt başarısız';
      }

      if (data['type'] == 'access_token') {
        // Otomatik giriş başarılı
        await bind.mainSetLocalOption(key: 'access_token', value: data['access_token']);
        await bind.mainSetLocalOption(key: 'user_info', value: json.encode(data['user']));
        gFFI.userModel.refreshCurrentUser();
        Get.back(result: true);
      } else if (data['type'] == 'email_check') {
        Get.back(result: true);
        showToast("Lütfen e-posta adresinizi doğrulayın.");
      } else {
        Get.back(result: true);
        showToast("Kayıt başarılı, admin onayı bekleniyor.");
      }
    } catch (e) {
      // ignore
      print("Register Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Bireysel'),
                  value: 'individual',
                  groupValue: accountType,
                  onChanged: (val) {
                    setState(() => accountType = val!);
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Kurumsal'),
                  value: 'company',
                  groupValue: accountType,
                  onChanged: (val) {
                    setState(() => accountType = val!);
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DialogTextField(
                  title: "Ad",
                  controller: firstName,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DialogTextField(
                  title: "Soyad",
                  controller: lastName,
                ),
              ),
            ],
          ),
          if (accountType != 'individual') ...[
            DialogTextField(
              title: "Firma Adı",
              controller: orgName,
              errorText: orgMsg,
            ),
            DialogTextField(
              title: "Vergi / T.C. No (Opsiyonel)",
              controller: taxId,
            ),
          ],
          DialogTextField(
            title: "E-posta",
            controller: email,
            errorText: emailMsg,
          ),
          PasswordWidget(
            controller: password,
            errorText: passMsg,
            autoFocus: false,
          ),
          PasswordWidget(
            controller: confirmPassword,
            errorText: confirmPassMsg,
            autoFocus: false,
          ),
          if (isInProgress) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isInProgress ? null : submit,
            child: const Text('Kayıt Ol'),
          ),
        ],
      ),
    );
  }
}
