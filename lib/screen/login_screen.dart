import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:muse_mate/app/main_app.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(controller: _emailController, decoration: const InputDecoration(labelText: '이메일'))),
            SizedBox(
              width: 300,
              child: TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '비밀번호'), obscureText: true)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {signIn();},
              child: const Text('로그인'),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("아직 회원이 아니신가요?"),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUpScreen()),
                    );
                  },
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ]
        ),
      ),
    );
  }

   Future<void> signIn() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // 이메일 인증 여부 체크
      if (userCredential.user?.emailVerified ?? false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 성공!')),
        );
        Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MainApp()),
                    );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일 인증을 완료해주세요.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 에러: $e')),
      );
    }
  }
}


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(controller: _emailController, decoration: const InputDecoration(labelText: '이메일'))),
            SizedBox(
              width: 300,
              child: TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '비밀번호'), obscureText: true)),
              SizedBox(
              width: 300,
              child: TextField(controller: _passwordCheckController, decoration: const InputDecoration(labelText: '비밀번호 확인'), obscureText: true)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {signUp();},
              child: const Text('회원가입'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {Navigator.pop(context);},
              child: const Text('돌아가기'),
            ),
          ]
        ),
      ),
    );
  }

  Future<void> signUp() async {
    if (_passwordController.text != _passwordCheckController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await userCredential.user?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 성공! 이메일 인증을 완료해주세요.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 에러: $e')),
      );
    }
  }
}