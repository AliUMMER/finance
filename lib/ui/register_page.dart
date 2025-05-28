import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'login_page.dart';

class SignUpScreen extends StatefulWidget {
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _companyName = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late FirebaseAuth _auth;
  late DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    _auth = GetIt.instance<FirebaseAuth>();
    _dbRef = GetIt.instance<FirebaseDatabase>().ref().child('users');
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential user = await _auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );

        await _dbRef.child(user.user!.uid).set({
          'companyName': _companyName.text.trim(),
          'email': _email.text.trim(),
          'address': _address.text.trim(),
          'phone': _phone.text.trim(),
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Registered Successfully")));
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => LoginPage()));
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "Registration Failed")));
      }
    }
  }

  Widget buildInputContainer(
      {required TextEditingController controller,
      required String label,
      bool obscure = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        validator: (value) => value!.isEmpty ? 'Enter $label' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade300])),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Sign Up",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  buildInputContainer(
                      controller: _companyName, label: 'Company Name'),
                  buildInputContainer(controller: _email, label: 'Email'),
                  buildInputContainer(controller: _address, label: 'Address'),
                  buildInputContainer(controller: _phone, label: 'Phone'),
                  buildInputContainer(
                      controller: _password, label: 'Password', obscure: true),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40)),
                    child: const Text("Register"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Already have an account? Login"),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
