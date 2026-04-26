import 'package:flutter/material.dart';

class Policy extends StatefulWidget {
  const Policy({super.key});

  @override
  State<Policy> createState() => PolicyState();
}

class PolicyState extends State<Policy> {
  final Map<String, bool> expandedSections = {
    'privacy': false,
    'terms': false,
    'community': false,
    'safety': false,
    'data': false,
    'copyright': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Policies & Guidelines',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.policy,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Policies & Guidelines',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Learn about our policies and your rights',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Divider(thickness: 1),
              
              const SizedBox(height: 16),
              
              // Policy Sections
              Expanded(
                child: ListView(
                  children: [
                    // Privacy Policy
                    buildPolicySection(
                      id: 'privacy',
                      icon: Icons.privacy_tip,
                      iconColor: Colors.blue,
                      title: 'Privacy Policy',
                      subtitle: 'How we collect and use your data',
                      lastUpdated: 'Updated: Feb 10, 2026',
                      content: '''
Your privacy is important to us. This Privacy Policy explains how Guardianly collects, uses, and protects your personal information when you use our application.

Information We Collect:
• Location data to provide navigation and alerts
• Account information (email, name)
• Usage data to improve our services
• Device information for app functionality

How We Use Your Information:
• Provide and maintain our services
• Send you alerts and notifications
• Improve and personalize your experience
• Ensure safety and security

Data Sharing:
We do not sell your personal information. We may share anonymized data with partners to improve services.

Your Rights:
You can request access to your data, ask for corrections, or delete your account at any time.
''',
                    ),
                    
                    // Terms of Service
                    buildPolicySection(
                      id: 'terms',
                      icon: Icons.description,
                      iconColor: Colors.green,
                      title: 'Terms of Service',
                      subtitle: 'Rules and guidelines for using Guardianly',
                      lastUpdated: 'Updated: Jan 15, 2026',
                      content: '''
By using Guardianly, you agree to these Terms of Service.

Acceptable Use:
• Use the app for lawful purposes only
• Do not attempt to circumvent security measures
• Provide accurate location information

User Accounts:
You are responsible for maintaining the confidentiality of your account. Notify us immediately of any unauthorized use.

Service Availability:
We strive to provide reliable service but do not guarantee uninterrupted access. We may modify or discontinue features with notice.

Limitation of Liability:
Guardianly is not liable for indirect damages arising from use of our services. We are not responsible for third-party content or services.
''',
                    ),
                    
                    // Safety Policy
                    buildPolicySection(
                      id: 'safety',
                      icon: Icons.shield,
                      iconColor: Colors.orange,
                      title: 'Safety Policy',
                      subtitle: 'Your safety is our priority',
                      lastUpdated: 'Updated: Feb 1, 2026',
                      content: '''
Guardianly is committed to user safety.

Emergency Features:
• Emergency alerts are prioritized
• Location sharing is always opt-in

Safe Navigation:
Always pay attention to your surroundings. Do not use the app while driving. Navigation instructions are for reference only.

''',
                    ),
                    
                    // Data Policy
                    buildPolicySection(
                      id: 'data',
                      icon: Icons.storage,
                      iconColor: Colors.teal,
                      title: 'Data Policy',
                      subtitle: 'How we handle your information',
                      lastUpdated: 'Updated: Jan 20, 2026',
                      content: '''
Our Data Policy outlines our commitment to protecting your information.

Data Collection:
• Location history (opt-in)
• Search queries
• Route preferences
• App usage statistics

Data Retention:
Account information is retained until account deletion. Anonymized data may be kept longer for analytics.

''',
                    ),
                    
                    // Copyright Policy
                    buildPolicySection(
                      id: 'copyright',
                      icon: Icons.copyright,
                      iconColor: Colors.red,
                      title: 'Copyright Policy',
                      subtitle: 'Intellectual property rights',
                      lastUpdated: 'Updated: Nov 10, 2025',
                      content: '''
Respecting intellectual property is important to us.

Our Content:
Map data © Mapbox. Guardianly logo and branding are trademarks. App design and code are protected by copyright.

MIT License

Copyright (c) 2025 Guardianly Team

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

User Content:
Users retain ownership of content they create. By posting, you grant us license to display and share content within the app.
''',
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPolicySection({
    required String id,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String lastUpdated,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Column(
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lastUpdated,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                expandedSections[id]! 
                  ? Icons.keyboard_arrow_up 
                  : Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  expandedSections[id] = !expandedSections[id]!;
                });
              },
            ),
          ),
          
          // Expandable content
          AnimatedCrossFade(
            firstChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: expandedSections[id]! 
              ? CrossFadeState.showFirst 
              : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}